PROMPT Upgrading METADATA to r23...

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

-- SECTION: ADMIN
--SET FEEDBACK OFF
CONNECT "^PDB_ADMIN_USERNAME"/"^PDB_ADMIN_PASSWORD"
--SET FEEDBACK ON

-- NOTE: No upgrades needed
-- !SECTION: ADMIN

-- SECTION: LIVE_SQL
--SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
--SET FEEDBACK ON

-- SECTION: ORDS Endpoints

BEGIN
    -- SECTION: LIVESQL-810 Fix User History Leak for Admin Users
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'statements/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'SELECT
    CREATED_ON,
    ID,
    CREATED_BY,
    CONTENT,
    JSON_QUERY ( RESULT, ''$'' RETURNING CLOB ) RESULT
FROM
    LIVE_SQL.STATEMENTS
WHERE
    UPPER( :current_user ) IS NOT NULL
    AND (
        CREATED_BY = UPPER( :current_user )
    )
    AND (
        :search_term IS NULL OR ( UPPER( CONTENT ) LIKE ''%'' || UPPER( :search_term ) || ''%'' )
    )
ORDER BY CREATED_ON DESC');
    --!SECTION: LIVESQL-810

    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- NOTE: Update the version after the upgrade
BEGIN
    SET_PARAMETER( 'VERSION', 'r23' );
    SET_PARAMETER( 'LAST_UPDATED_ON', TO_CHAR( CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-DD-MM"T"HH24:MI:SS.FF3"Z"' ) );
END;
/
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA to r23 complete
