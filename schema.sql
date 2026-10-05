--------------------------------------------------------------------------------
-- 1. Country
-- Represents countries. Recorded even if no cities/companies exist yet.
--------------------------------------------------------------------------------
CREATE TABLE Country (
    country_name VARCHAR(100),
    PRIMARY KEY (country_name)
);

--------------------------------------------------------------------------------
-- 2. City
-- Weak entity dependent on Country (Compound Key: city_name + country_name).
--------------------------------------------------------------------------------
CREATE TABLE City (
    city_name VARCHAR(100) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (city_name, country_name),
    FOREIGN KEY (country_name) 
        REFERENCES Country(country_name)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
);
-- JUSTIFICATION FOR EVENT ACTIONS (City -> Country):
-- ON UPDATE CASCADE: If a country's name changes, propagate to city records.
-- ON DELETE RESTRICT: Prevent deletion of a country if cities are linked to it.

--------------------------------------------------------------------------------
-- 3. Company
-- Container owner. Identifiers/Prefix is 3 uppercase characters.
-- Total participation in City via NOT NULL foreign key.
--------------------------------------------------------------------------------
CREATE TABLE Company (
    company_code CHAR(3),
    company_name VARCHAR(200) NOT NULL,
    address VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (company_code),
    FOREIGN KEY (city_name, country_name) 
        REFERENCES City(city_name, country_name)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
);
-- JUSTIFICATION FOR EVENT ACTIONS (Company -> City):
-- ON UPDATE CASCADE: If city/country details change, update company references.
-- ON DELETE RESTRICT: Do not allow deletion of a city if companies are located in it.

--------------------------------------------------------------------------------
-- 4. Berth
-- Port berths with meter-level precision coordinates (5 decimal places).
-- Recorded even if empty.
--------------------------------------------------------------------------------
CREATE TABLE Berth (
    berth_code INT,
    latitude DECIMAL(7, 5) NOT NULL,
    longitude DECIMAL(8, 5) NOT NULL,
    PRIMARY KEY (berth_code),
    CHECK (latitude BETWEEN -90.00000 AND 90.00000),
    CHECK (longitude BETWEEN -180.00000 AND 180.00000)
);

--------------------------------------------------------------------------------
-- 5. Ship
-- Ships docked at the terminal. Must be docked at a berth (Total Participation).
-- MMSI, IMO, and Call Sign are distinct candidate keys.
--------------------------------------------------------------------------------
CREATE TABLE Ship (
    mmsi INT,
    imo INT NOT NULL UNIQUE,
    call_sign VARCHAR(10) NOT NULL UNIQUE,
    ship_name VARCHAR(100) NOT NULL,
    length DECIMAL(6, 2) NOT NULL CHECK (length > 0),
    width DECIMAL(5, 2) NOT NULL CHECK (width > 0),
    berth_code INT NOT NULL UNIQUE DEFERRABLE INITIALLY DEFERRED, -- Unique enforces 1:1 (one ship per berth)
    PRIMARY KEY (mmsi),
    FOREIGN KEY (berth_code) 
        REFERENCES Berth(berth_code)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT 
        DEFERRABLE INITIALLY DEFERRED
);
-- JUSTIFICATION FOR DEFERRABLE CONSTRAINT:
-- DEFERRABLE INITIALLY DEFERRED allows transaction-level checks when swapping
-- ships between berths or registering docked vessels during initialization.
-- JUSTIFICATION FOR EVENT ACTIONS (Ship -> Berth):
-- ON UPDATE CASCADE: Berth renumbering automatically updates ship records.
-- ON DELETE RESTRICT: Cannot delete a berth row if a ship is actively docked there.

--------------------------------------------------------------------------------
-- 6. YardType
-- Storage yard categories (e.g., Normal, Semi-Automated, Automated).
-- Recorded even if no yards of this type currently exist.
--------------------------------------------------------------------------------
CREATE TABLE YardType (
    type_name VARCHAR(50),
    max_tiers INT NOT NULL CHECK (max_tiers > 0),
    PRIMARY KEY (type_name)
);

--------------------------------------------------------------------------------
-- 7. Yard
-- Physical yards categorized by a YardType.
-- Total participation in YardType via NOT NULL foreign key.
--------------------------------------------------------------------------------
CREATE TABLE Yard (
    yard_code VARCHAR(20),
    type_name VARCHAR(50) NOT NULL,
    PRIMARY KEY (yard_code),
    FOREIGN KEY (type_name) 
        REFERENCES YardType(type_name)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
);

--------------------------------------------------------------------------------
-- 8. Position 
-- Weak entity representing discrete storage locations in a yard.
-- Partial key: (bay, row, tier). Compound Primary Key: (yard_code, bay, row, tier).
--------------------------------------------------------------------------------
CREATE TABLE Position (
    yard_code VARCHAR(20),
    bay INT CHECK (bay >= 0),
    row INT CHECK (row >= 0),
    tier INT CHECK (tier > 0),
    PRIMARY KEY (yard_code, bay, row, tier),
    FOREIGN KEY (yard_code) 
        REFERENCES Yard(yard_code)
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);
-- JUSTIFICATION FOR EVENT ACTIONS (Position -> Yard):
-- ON DELETE CASCADE: If a yard is decommissioned/removed, its physical slots are deleted.

--------------------------------------------------------------------------------
-- 9. Container
-- Containers at the terminal. Must be owned by a Company (Total Participation).
-- Must be in a yard slot OR on a ship (Exclusive XOR relationship enforced via CHECK).
--------------------------------------------------------------------------------
CREATE TABLE Container (
    iso_code CHAR(11),
    description TEXT,
    company_code CHAR(3) NOT NULL,
    -- Location option A: Stored in a Yard Slot
    yard_code VARCHAR(20),
    bay INT,
    row INT,
    tier INT,
    -- Location option B: Loaded on a Ship
    mmsi INT,
    
    PRIMARY KEY (iso_code),
    
    -- Constraint: First 3 characters of ISO 6346 code must match company prefix
    CHECK (SUBSTRING(iso_code FROM 1 FOR 3) = company_code),
    
    -- Foreign Key: Ownership
    FOREIGN KEY (company_code) 
        REFERENCES Company(company_code)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT,
        
    -- Foreign Key: Yard Location (Unique constraint ensures 1 container per slot)
    FOREIGN KEY (yard_code, bay, row, tier) 
        REFERENCES Position(yard_code, bay, row, tier)
        ON UPDATE CASCADE 
        ON DELETE SET NULL,
    UNIQUE (yard_code, bay, row, tier),
    
    -- Foreign Key: Ship Location
    FOREIGN KEY (mmsi) 
        REFERENCES Ship(mmsi)
        ON UPDATE CASCADE 
        ON DELETE CASCADE,
        
    -- Exclusive Location (XOR): Container MUST be in a yard slot OR on a ship, NOT both or neither
    CHECK (
        (yard_code IS NOT NULL AND bay IS NOT NULL AND row IS NOT NULL AND tier IS NOT NULL AND mmsi IS NULL)
        OR
        (yard_code IS NULL AND bay IS NULL AND row IS NULL AND tier IS NULL AND mmsi IS NOT NULL)
    )
);
-- JUSTIFICATION FOR DEVIATION FROM BASIC LECTURE TRANSLATION:
-- Standard translation of two relationships (Stored_On_Ship and Stored_At_Yard)
-- into a single entity table usually results in nullable foreign keys.
-- We combined location fields directly into Container and added a tuple CHECK constraint
-- to strictly enforce the domain XOR rule (container is either in yard or on ship).

--------------------------------------------------------------------------------
-- CONSTRAINTS NOT ENFORCED BY THIS DDL SCHEMA
--------------------------------------------------------------------------------
/*
1. Dynamic Maximum Tier Constraint:
   The `tier` of a container in `Position` cannot exceed `YardType.max_tiers` for that yard.
   - Reason: Standard SQL `CHECK` constraints cannot execute subqueries across tables.

2. Sequential Gravity Stacking Rule:
   A container cannot occupy tier N (where N > 1) in a (yard_code, bay, row) slot unless 
   a container already occupies tier N - 1 at the same bay and row.
   - Reason: Requires procedural validation / cross-row state checking.

3. Complete ISO 6346 Check Digit Validation:
   Verifying the full 11-character ISO 6346 checksum formula requires procedural algorithm logic.
*/
