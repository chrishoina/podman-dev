-- IMPORTANT: Service should be down for the application of this patch

-- IMPORTANT: Fill the prompt with what the file is doing (usually it would be something like 'upgrading metadata with r<number> patch...')
PROMPT <beginning prompt message>

SET DEFINE '^'
SET ESCAPE OFF
SET ESCAPE '\'
SET VERIFY OFF
SET ECHO OFF

DEFINE PDB_NAME = '^1'
DEFINE PDB_ADMIN_USERNAME = '^2'
DEFINE PDB_ADMIN_PASSWORD = '^3'
DEFINE DEFAULT_TABLESPACE = '^4'
DEFINE TEMPORARY_TABLESPACE = '^5'

WHENEVER SQLERROR EXIT 1

SET FEEDBACK OFF
BEGIN
    IF NVL( LENGTH( '^PDB_ADMIN_PASSWORD' ), 0 ) = 0 THEN
        RAISE_APPLICATION_ERROR( -20000, 'PDB ADMIN password not provided' );
    END IF;
END;
/
SET FEEDBACK ON

SET FEEDBACK OFF
DECLARE
    L_RESULT NUMBER;
BEGIN
    SELECT
        1
    INTO
        L_RESULT
    FROM
        DUAL
    WHERE
        -- NOTE: Check if we're on the PDB
        SYS_CONTEXT( 'USERENV', 'CON_NAME' ) = '^PDB_NAME'
        AND EXISTS ( SELECT 1 FROM ALL_USERS WHERE USERNAME = 'ORDS_METADATA' )
        AND EXISTS ( SELECT 1 FROM ALL_OBJECTS WHERE OWNER = 'PUBLIC' AND OBJECT_TYPE = 'SYNONYM' AND OBJECT_NAME = 'APEX_APPLICATION' );
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR( -20000, 'This script must be executed in the "^PDB_NAME." PDB and ORDS and APEX must be installed' );
END;
/
SET FEEDBACK ON

-- This is the SYSDBA section, this should be reserved only for things that SYSDBA has to do.
-- SECTION: SYSDBA
-- NOTE: No upgrade needed
-- !SECTION: SYSDBA

-- This is the admin section where the changes that an admin needs to do will be inserted. If there are changes, then uncomment the 3 following lines (feedback off, connect, feedback on)
-- SECTION: ADMIN

--SET FEEDBACK OFF
--CONNECT "^PDB_ADMIN_USERNAME"/"^PDB_ADMIN_PASSWORD"
--SET FEEDBACK ON

-- SECTION: Objects 

-- In this section, you put the changes that an admin needs to do on an Object level (meaning creating new tables, grants, indexes, etc). You specify the SECTION: LIVESQL-XXXX where it wraps your changes:
-- SECTION: LIVESQL-XXXX


-- !SECTION: LIVESQL-XXXX
-- !SECTION: Objects

-- SECTION: ORDS Endpoints
BEGIN
    -- In this section, you put the changes that an admin needs to do on an ORDS Endpoint level (meaning the REST APIs). You specify the SECTION: LIVESQL-XXXX where it wraps your changes:
    -- SECTION: LIVESQL-XXXX
    
    -- You'll need to export the REST Module where your changes are. From that point, you'll need to copy the REST API part:
    -- If you added a new template, then you'll need to copy the ORDS.DEFINE_TEMPLATE where you're defining the new template and also its handlers.
    -- If you added a new handler, then you'll need to copy the ORDS.DEFINE_HANDLER. 

    -- !SECTION: LIVESQL-XXXX
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- If no upgrades in admin are needed, you add this comment
-- NOTE: No upgrades needed
-- !SECTION: ADMIN





-- This is the LIVE_SQL user section where the changes that it needs to do will be inserted. If there are changes, then uncomment the 3 following lines (feedback off, connect, feedback on)
-- SECTION: LIVE_SQL
--SET FEEDBACK OFF
--CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
--SET FEEDBACK ON

-- SECTION: Objects 

-- In this section, you put the changes that LIVE_SQL user needs to do on an Object level (meaning creating new tables, grants, indexes, etc). You specify the SECTION: LIVESQL-XXXX where it wraps your changes:
-- SECTION: LIVESQL-XXXX


-- !SECTION: LIVESQL-XXXX
-- !SECTION: Objects


-- SECTION: ORDS Endpoints
BEGIN
    -- In this section, you put the changes that LIVE_SQL user needs to do on an ORDS Endpoint level (meaning the REST APIs). You specify the SECTION: LIVESQL-XXXX where it wraps your changes:
    -- SECTION: LIVESQL-XXXX
    
    -- You'll need to export the REST Module where your changes are. From that point, you'll need to copy the REST API part:
    -- If you added a new template, then you'll need to copy the ORDS.DEFINE_TEMPLATE where you're defining the new template and also its handlers.
    -- If you added a new handler, then you'll need to copy the ORDS.DEFINE_HANDLER. 

    -- !SECTION: LIVESQL-XXXX
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- SECTION: LIVESQL-XXXX

-- This section is for extra changes that are not object or ORDS related (for example updating the version in the parameter table).

-- !SECTION: LIVESQL-XXXX
-- !SECTION: LIVE_SQL

-- IMPORTANT: Mention the end of the patch upgrade (something like 'r<number> patch applied...')
PROMPT <end of prompt message>
