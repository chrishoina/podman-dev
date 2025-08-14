-- NOTE: This script is not intended to be used directly but through install.sql

-- SET DEFINE '^'
-- SET ESCAPE OFF
-- SET ESCAPE '\'
-- SET VERIFY OFF
-- SET ECHO OFF
SET DEFINE '^'

DEFINE pass='^1'
DEFINE tbs='^2'

SET FEEDBACK ON

PROMPT INFO: Installing sample schemas on Live SQL SCHEMAS...

WHENEVER SQLERROR CONTINUE
BEGIN
    EXECUTE IMMEDIATE 'DROP ROLE LIVE_SQL_SAMPLE_SCHEMAS_USER';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/
WHENEVER SQLERROR EXIT 1

CREATE ROLE LIVE_SQL_SAMPLE_SCHEMAS_USER;

store set system_variables_temporary_store.sql replace

-- TODO: Review each sample schema installation script to find the one that is
-- hiding the prompts

-- ACADEMIC
PROMPT INFO: Installing "ACADEMIC" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/academic/create_ad.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- ANALYTIC VIEWS
PROMPT INFO: Installing "ANALYTIC VIEWS" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/analytic_views/create_av.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- CUSTOMER ORDERS
PROMPT INFO: Installing "CUSTOMER ORDERS" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/customer_orders/co_install.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- HUMAN RESOURCES
PROMPT INFO: Installing "HUMAN RESOURCES" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/human_resources/hr_install.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- OLYMPIC DATA
PROMPT INFO: Installing "OLYMPIC DATA" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/olympic_data/create_olym.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- ORDER ENTRY
PROMPT INFO: Installing "ORDER ENTRY" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/order_entry/create_oe.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- PROJECTS
PROMPT INFO: Installing "PROJECTS" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/projects/create_projects.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- SALES HISTORY
-- This is being installed manually since SQL plus can not change directories.
-- So, we added a new step in the MANUAL_INSTALL.md file for this sample schema

-- SCOTT
PROMPT INFO: Installing "SCOTT" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/scott/create_scott.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

-- WORLD
PROMPT INFO: Installing "WORLD" sample schema on Live SQL SCHEMAS...
@@../sample_schemas/world/create_world.sql '^PDB_ADMIN_PASSWORD' '^DEFAULT_TABLESPACE' 'YES'
START system_variables_temporary_store.sql

HOST rm -f system_variables_temporary_store.sql


PROMPT INFO: Sample schemas on Live SQL SCHEMAS installed

-- NOTE: We know ORDS is installed at this point so making the appropriate grants


-- BEGIN
--     ORDS.ENABLE_SCHEMA(
--         P_ENABLED => TRUE,
--         P_SCHEMA => NULL,
--         P_URL_MAPPING_TYPE => 'BASE_PATH',
--         P_URL_MAPPING_PATTERN => NULL,
--         P_AUTO_REST_AUTH => TRUE
--     );
--     COMMIT;
-- END;
-- /

PROMPT INFO: Live SQL SCHEMAS installed

-- NOTE: Apply available upgrades
-- @@../upgrade/upgrade.sql ^PDB_NAME ^PDB_ADMIN_USERNAME ^PDB_ADMIN_PASSWORD ^DEFAULT_TABLESPACE ^TEMPORARY_TABLESPACE

EXIT
