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
);
-- JUSTIFICATION FOR EVENT ACTIONS (City -> Country):
-- ON UPDATE CASCADE: If a country's name changes, propagate to city records.
-- ON DELETE NO ACTION (default): Blocks deleting a country that has cities.

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
);
-- JUSTIFICATION FOR EVENT ACTIONS (Company -> City):
-- ON UPDATE CASCADE: If city/country details change, update company references.
-- ON DELETE NO ACTION (default): Blocks deleting a city that has companies.

--------------------------------------------------------------------------------
-- 4. Berth
-- Port berths with meter-level precision coordinates (5 decimal places).
-- Recorded even if empty.
--------------------------------------------------------------------------------
CREATE TABLE Berth (
    berth_code INT CHECK (berth_code >= 0),
    latitude NUMERIC NOT NULL CHECK (latitude = ROUND(latitude, 5)),
    longitude NUMERIC NOT NULL CHECK (longitude = ROUND(longitude, 5)),
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
    length NUMERIC NOT NULL CHECK (length > 0 AND length = ROUND(length, 2)),
    width NUMERIC NOT NULL CHECK (width > 0 AND width = ROUND(width, 2)),
    berth_code INT NOT NULL UNIQUE DEFERRABLE INITIALLY DEFERRED, -- Unique enforces 1:1 (one ship per berth)
    PRIMARY KEY (mmsi),
    FOREIGN KEY (berth_code) 
        REFERENCES Berth(berth_code)
        ON UPDATE CASCADE 
        DEFERRABLE INITIALLY DEFERRED
);
-- JUSTIFICATION FOR DEFERRABLE CONSTRAINT:
-- DEFERRABLE INITIALLY DEFERRED allows transaction-level checks when swapping
-- ships between berths or registering docked vessels during initialization.
-- JUSTIFICATION FOR EVENT ACTIONS (Ship -> Berth):
-- ON UPDATE CASCADE: Berth renumbering automatically updates ship records.
-- ON DELETE NO ACTION (default): Blocks deleting a berth with a docked ship.

--------------------------------------------------------------------------------
-- 6. YardType
-- Storage yard categories (e.g., Normal, Semi-Automated, Automated).
-- Recorded even if no yards of this type currently exist.
--------------------------------------------------------------------------------
CREATE TABLE YardType (
    type VARCHAR(50),
    max_tier_number INT NOT NULL CHECK (max_tier_number > 0),
    PRIMARY KEY (type)
);

--------------------------------------------------------------------------------
-- 7. Yard
-- Physical yards categorized by a YardType.
-- Total participation in YardType via NOT NULL foreign key.
--------------------------------------------------------------------------------
CREATE TABLE Yard (
    yard_code VARCHAR(20),
    type VARCHAR(50) NOT NULL,
    PRIMARY KEY (yard_code),
    FOREIGN KEY (type) 
        REFERENCES YardType(type)
        ON UPDATE CASCADE 
);
-- JUSTIFICATION FOR EVENT ACTIONS (Yard -> YardType):
-- ON UPDATE CASCADE: Renaming a yard type updates its yards.
-- ON DELETE NO ACTION (default): Blocks deleting a yard type still in use.

--------------------------------------------------------------------------------
-- 8. Position 
-- Weak entity representing discrete storage locations in a yard.
-- Partial key: (bay_number, row_number, tier_number). Compound Primary Key: (yard_code, bay_number, row_number, tier_number).
--------------------------------------------------------------------------------
CREATE TABLE Position (
    yard_code VARCHAR(20),
    bay_number INT CHECK (bay_number >= 0),
    row_number INT CHECK (row_number >= 0),
    tier_number INT CHECK (tier_number > 0),
    PRIMARY KEY (yard_code, bay_number, row_number, tier_number),
    FOREIGN KEY (yard_code) 
        REFERENCES Yard(yard_code)
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);
-- JUSTIFICATION FOR EVENT ACTIONS (Position -> Yard):
-- ON UPDATE CASCADE: Changing a yard code updates its positions.
-- ON DELETE CASCADE: If a yard is decommissioned/removed, its physical slots are deleted.

--------------------------------------------------------------------------------
-- 9. Container
-- Containers at the terminal. Must be owned by a Company (Total Participation).
-- Must be in a yard slot OR on a ship (Exclusive XOR relationship enforced via CHECK).
--------------------------------------------------------------------------------
CREATE TABLE Container (
    ISO6346 CHAR(11),
    description TEXT,
    company_code CHAR(3) NOT NULL,
    -- Location option A: Stored in a Yard Slot
    yard_code VARCHAR(20),
    bay_number INT,
    row_number INT,
    tier_number INT,
    -- Location option B: Loaded on a Ship
    mmsi INT,
    
    PRIMARY KEY (ISO6346),
    
    -- Constraint: First 3 characters of ISO 6346 code must match company prefix
    CHECK (ISO6346 LIKE company_code || '%'),
    
    -- Foreign Key: Ownership
    FOREIGN KEY (company_code) 
        REFERENCES Company(company_code)
        ON UPDATE CASCADE,

    -- Foreign Key: Yard Location (Unique constraint ensures 1 container per slot)
    FOREIGN KEY (yard_code, bay_number, row_number, tier_number) 
        REFERENCES Position(yard_code, bay_number, row_number, tier_number)
        ON UPDATE CASCADE,
    UNIQUE (yard_code, bay_number, row_number, tier_number),
    
    -- Foreign Key: Ship Location
    FOREIGN KEY (mmsi) 
        REFERENCES Ship(mmsi)
        ON UPDATE CASCADE 
        ON DELETE CASCADE,
        
    -- Exclusive Location (XOR): Container MUST be in a yard slot OR on a ship, NOT both or neither
    CHECK (
        (yard_code IS NOT NULL AND bay_number IS NOT NULL AND row_number IS NOT NULL AND tier_number IS NOT NULL AND mmsi IS NULL)
        OR
        (yard_code IS NULL AND bay_number IS NULL AND row_number IS NULL AND tier_number IS NULL AND mmsi IS NOT NULL)
    )
);
-- JUSTIFICATION FOR EVENT ACTIONS (Container -> Company):
-- ON UPDATE CASCADE: Changing a company code updates its containers.
-- ON DELETE NO ACTION (default): Blocks deleting a company that owns containers.
-- JUSTIFICATION FOR EVENT ACTIONS (Container -> Position):
-- ON UPDATE CASCADE: A stored container follows changes to its position.
-- ON DELETE NO ACTION (default): Blocks deleting an occupied position (or its yard).
-- JUSTIFICATION FOR EVENT ACTIONS (Container -> Ship):
-- ON UPDATE CASCADE: Changing a ship's MMSI updates the containers on board.
-- ON DELETE CASCADE: Containers still on board leave the terminal with the ship.
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
   The `tier_number` of a container in `Position` cannot exceed `YardType.max_tier_number` for that yard.
   - Reason: Standard SQL `CHECK` constraints cannot execute subqueries across tables.

2. Sequential Gravity Stacking Rule:
   A container cannot occupy tier N (where N > 1) in a (yard_code, bay_number, row_number) slot unless 
   a container already occupies tier N - 1 at the same bay and row.
   - Reason: Requires procedural validation / cross-row state checking.

3. Complete ISO 6346 Check Digit Validation:
   Verifying the full 11-character ISO 6346 checksum formula requires procedural algorithm logic.
*/
