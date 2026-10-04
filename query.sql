--------------------------------------------------------------------------------
-- Operation 1: Create yard type "Simple" (max_tiers=3), yard "Y", 
-- and 12 slots across 2 bays (0, 1) and 2 rows (0, 1) with tiers 1..3.
--------------------------------------------------------------------------------
INSERT INTO YardType (type_name, max_tiers) 
VALUES ('Simple', 3);

INSERT INTO Yard (yard_code, type_name) 
VALUES ('Y', 'Simple');

INSERT INTO Position (yard_code, bay, row, tier) VALUES
('Y', 0, 0, 1), ('Y', 0, 0, 2), ('Y', 0, 0, 3),
('Y', 0, 1, 1), ('Y', 0, 1, 2), ('Y', 0, 1, 3),
('Y', 1, 0, 1), ('Y', 1, 0, 2), ('Y', 1, 0, 3),
('Y', 1, 1, 1), ('Y', 1, 1, 2), ('Y', 1, 1, 3);

--------------------------------------------------------------------------------
-- Operation 2: Create 2 berths with codes 1 ("B1") and 2 ("B2")
--------------------------------------------------------------------------------
INSERT INTO Berth (berth_code, latitude, longitude) VALUES 
(1, 1.29662, 103.77643),
(2, 1.29665, 103.77648);

--------------------------------------------------------------------------------
-- Operation 3: Add company "Apasaja Distribution International" (ADI)
--------------------------------------------------------------------------------
INSERT INTO Country (country_name) 
VALUES ('Singapore');

INSERT INTO City (city_name, country_name) 
VALUES ('Singapore', 'Singapore');

INSERT INTO Company (company_code, company_name, address, postal_code, city_name, country_name) 
VALUES ('ADI', 'Apasaja Distribution International', '1 HarbourFront Ave', '098632', 'Singapore', 'Singapore');

--------------------------------------------------------------------------------
-- Operation 4: Ship MMSI 211382280 arrives at berth 1 with container ADIU4974982
--------------------------------------------------------------------------------
INSERT INTO Ship (mmsi, imo, call_sign, ship_name, length, width, berth_code) 
VALUES (211382280, 9229843, '5LJY5', 'Vessel A', 150.00, 25.00, 1);

INSERT INTO Container (iso_code, description, company_code, mmsi) 
VALUES ('ADIU4974982', 'Cargo Container 1', 'ADI', 211382280);

--------------------------------------------------------------------------------
-- Operation 5: Ship MMSI 209912000 arrives at berth 2 with container ADIU7385836
--------------------------------------------------------------------------------
INSERT INTO Ship (mmsi, imo, call_sign, ship_name, length, width, berth_code) 
VALUES (209912000, 9261889, '5BLP5', 'Vessel B', 180.00, 28.00, 2);

INSERT INTO Container (iso_code, description, company_code, mmsi) 
VALUES ('ADIU7385836', 'Cargo Container 2', 'ADI', 209912000);

--------------------------------------------------------------------------------
-- Operation 6: Move container ADIU4974982 to yard Y at bay 0, row 0, tier 1
--------------------------------------------------------------------------------
DELETE FROM Container WHERE iso_code = 'ADIU4974982';
INSERT INTO Container (iso_code, description, company_code, yard_code, bay, row, tier) 
VALUES ('ADIU4974982', 'Cargo Container 1', 'ADI', 'Y', 0, 0, 1);

--------------------------------------------------------------------------------
-- Operation 7: Ship MMSI 211382280 leaves berth
--------------------------------------------------------------------------------
DELETE FROM Ship WHERE mmsi = 211382280;

--------------------------------------------------------------------------------
-- Operation 8: Ship MMSI 255806008 arrives at berth 1 with container ADIU7583471
--------------------------------------------------------------------------------
INSERT INTO Ship (mmsi, imo, call_sign, ship_name, length, width, berth_code) 
VALUES (255806008, 9277400, '3FIV6', 'Vessel C', 200.00, 30.00, 1);

INSERT INTO Container (iso_code, description, company_code, mmsi) 
VALUES ('ADIU7583471', 'Cargo Container 3', 'ADI', 255806008);

--------------------------------------------------------------------------------
-- Operation 9: Ship MMSI 209912000 leaves berth
-- (Container ADIU7385836 leaves with the ship)
--------------------------------------------------------------------------------
DELETE FROM Container WHERE iso_code = 'ADIU7385836';
DELETE FROM Ship WHERE mmsi = 209912000;

--------------------------------------------------------------------------------
-- Operation 10: Move container ADIU7583471 to yard Y at bay 0, row 0, tier 2
--------------------------------------------------------------------------------
DELETE FROM Container WHERE iso_code = 'ADIU7583471';
INSERT INTO Container (iso_code, description, company_code, yard_code, bay, row, tier) 
VALUES ('ADIU7583471', 'Cargo Container 3', 'ADI', 'Y', 0, 0, 2);

--------------------------------------------------------------------------------
-- Query: Find all unused positions in the yard
--------------------------------------------------------------------------------
SELECT 
    ys.yard_code,
    y.type_name AS yard_type,
    ys.bay AS bay_number,
    ys.row AS row_number,
    ys.tier AS tier_number
FROM Position ys
JOIN Yard y 
    ON ys.yard_code = y.yard_code
LEFT JOIN Container c 
    ON ys.yard_code = c.yard_code 
   AND ys.bay = c.bay 
   AND ys.row = c.row 
   AND ys.tier = c.tier
WHERE c.iso_code IS NULL
ORDER BY 
    ys.yard_code ASC,
    ys.bay ASC,
    ys.row ASC,
    ys.tier ASC;
