--------------------------------------------------------------------------------
-- Local environment reset file. DO NOT INCLUDE IN SUBMISSION.
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS Container CASCADE;
DROP TABLE IF EXISTS Position CASCADE;
DROP TABLE IF EXISTS Yard CASCADE;
DROP TABLE IF EXISTS YardType CASCADE;
DROP TABLE IF EXISTS Ship CASCADE;
DROP TABLE IF EXISTS Berth CASCADE;
DROP TABLE IF EXISTS Company CASCADE;
DROP TABLE IF EXISTS City CASCADE;
DROP TABLE IF EXISTS Country CASCADE;

-- TRIGGERS AND UTILITY FUNCITONS
DROP FUNCTION IF EXISTS is_on_yard(c Container) CASCADE;
DROP FUNCTION IF EXISTS check_container_not_floating() CASCADE;
DROP FUNCTION IF EXISTS check_container_not_both_ship_and_yard() CASCADE;
