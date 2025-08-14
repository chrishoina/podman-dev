PROMPT applying r32-livesql-840 patch on metadata PDB...
-- SECTION: Checking database, PDB, and other details (This is needed in every patch file, so copy and paste it)
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

-- SECTION: LIVE_SQL
SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: ORDS Endpoints
BEGIN
    -- SECTION: LIVESQL-840
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'worksheets/:worksheet_id',
        p_method         => 'GET',
        p_source_type    => 'json/item',
        p_items_per_page => 25,
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'WITH
    USER_ROLES AS (
        SELECT
            COLUMN_VALUE AS NAME
        FROM
            AUTHORIZATION.GET_ROLES( UPPER( :current_user ) )
)
SELECT
    ID,
    NAME,
    CONTENT,
    UPDATED_ON,
    CREATED_ON,
    CREATED_BY,
    CODE_LANGUAGE,
    LAST_OPENED_ON
FROM
    WORKSHEETS
WHERE 
    (
        ''ADMINISTRATOR'' IN ( SELECT NAME FROM USER_ROLES )
        OR CREATED_BY = UPPER( :current_user ) 
    )
    AND ID = :worksheet_id');
    -- !SECTION: LIVESQL-840
    COMMIT;
END;
/

PROMPT r32-livesql-840 patch
