-- This is the patch file structure

PROMPT applying r31-livesql-945 patch on metadata PDB...

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

-- !SECTION: DB Check

-- SECTION: ADMIN
-- NOTE: No upgrades needed
-- !SECTION: ADMIN

-- SECTION: LIVE_SQL
SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: Objects 

-- SECTION: LIVESQL-945
CREATE OR REPLACE PACKAGE BODY USER_SCHEMAS AS
    FUNCTION GET_DATABASE_VERSION RETURN DATABASES.VERSION%TYPE IS
        L_VERSION DATABASES.VERSION%TYPE;
    BEGIN
        SELECT
            VERSION
        INTO
            L_VERSION
        FROM
            DATABASES
        ORDER BY
            -- NOTE: Pick the newest one by default because is the less likely to
            --       have a lot of schemas created
            -- NOTE: This sorts the schema by version number considering the
            --       version is in one of the following formats: 0 | 0.0 | 0.0.0
            TO_NUMBER(REGEXP_SUBSTR( VERSION, '\\d+', 1, 1)) DESC NULLS LAST,
            TO_NUMBER(REGEXP_SUBSTR( VERSION, '\\d+', 1, 2)) DESC NULLS LAST,
            TO_NUMBER(REGEXP_SUBSTR( VERSION, '\\d+', 1, 3)) DESC NULLS LAST
        FETCH FIRST ROW ONLY;

        RETURN L_VERSION;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR( -20000, 'An error occurred while obtaining the database version. No databases available' );
    END GET_DATABASE_VERSION;

    FUNCTION GET_READ_ONLY_SCHEMA (
        P_VERSION DATABASES.VERSION%TYPE DEFAULT NULL
    ) RETURN USER_SCHEMA_T IS
        L_VERSION DATABASES.VERSION%TYPE := NVL( P_VERSION, GET_DATABASE_VERSION() );
        L_USER_SCHEMA USER_SCHEMA_T;
    BEGIN
        SELECT
            USER_SCHEMA_T(
                SCHEMAS.ID,
                SCHEMAS.NAME,
                SCHEMAS.ALIAS,
                DATABASES.VERSION,
                DATABASES.BASE_URL,
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_ID ),
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_SECRET )
            )
        INTO
            L_USER_SCHEMA
        FROM
            SCHEMAS JOIN DATABASES ON
                SCHEMAS.DATABASE_ID = DATABASES.ID
        WHERE
            DATABASES.VERSION = L_VERSION
            AND SCHEMAS.STATUS = 'AVAILABLE'
            AND SCHEMAS.IS_READ_ONLY = 'Y'
        ORDER BY
            DBMS_RANDOM.RANDOM
        FETCH FIRST ROW ONLY;

        RETURN L_USER_SCHEMA;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR( -20000, 'An error occurred while obtaining a read-only schema. No schemas available' );
    END GET_READ_ONLY_SCHEMA;

    FUNCTION ASSIGN_SCHEMA_TO_USER (
        P_USER    VARCHAR2,
        P_VERSION DATABASES.VERSION%TYPE DEFAULT NULL
    ) RETURN USER_SCHEMA_T IS
        L_VERSION DATABASES.VERSION%TYPE := NVL( P_VERSION, GET_DATABASE_VERSION() );
        L_USER_SCHEMA USER_SCHEMA_T;
        L_DATABASE_ID DATABASES.ID%TYPE;
    BEGIN
        L_USER_SCHEMA := GET_USER_SCHEMA( P_USER, P_VERSION );
        IF L_USER_SCHEMA IS NOT NULL THEN
            RETURN L_USER_SCHEMA;
        END IF;

        SELECT
            USER_SCHEMA_T(
                SCHEMAS.ID,
                SCHEMAS.NAME,
                SCHEMAS.ALIAS,
                DATABASES.VERSION,
                DATABASES.BASE_URL,
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_ID ),
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_SECRET )
            ),
            DATABASES.ID
        INTO
            L_USER_SCHEMA,
            L_DATABASE_ID
        FROM
            SCHEMAS JOIN DATABASES ON
                SCHEMAS.DATABASE_ID = DATABASES.ID
        WHERE
            DATABASES.VERSION = L_VERSION
            AND SCHEMAS.STATUS = 'AVAILABLE'
            AND SCHEMAS.IS_READ_ONLY = 'N'
            AND SCHEMAS.ASSIGNED_TO IS NULL
        ORDER BY
            DBMS_RANDOM.RANDOM
        FETCH FIRST ROW ONLY;

        UPDATE
            SCHEMAS
        SET
            ASSIGNED_TO = P_USER,
            STATUS = 'ASSIGNED'
        WHERE
            ID = L_USER_SCHEMA.ID;

        BEGIN
            SCHEMA_MANAGEMENT.REQUEST_SCHEMAS_CREATION(
                P_DATABASE_ID => L_DATABASE_ID,
                P_NUMBER_OF_SCHEMAS => 1,
                P_ARE_SCHEMAS_READ_ONLY_YN => 'N'
            );
        EXCEPTION
            -- NOTE: This call shouldn't prevent the user from getting a schema
            --       assigned
            -- TODO: Improve logging and error handling
            WHEN OTHERS THEN
                NULL;
        END;

        RETURN L_USER_SCHEMA;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR( -20000, 'An error occurred while assigning a schema. No schemas available' );
    END ASSIGN_SCHEMA_TO_USER;

    FUNCTION GET_USER_SCHEMA (
        P_USER VARCHAR2,
        P_VERSION DATABASES.VERSION%TYPE DEFAULT NULL
    ) RETURN USER_SCHEMA_T IS
        L_VERSION DATABASES.VERSION%TYPE := NVL( P_VERSION, GET_DATABASE_VERSION() );
        L_USER_SCHEMA USER_SCHEMA_T;
    BEGIN
        SELECT
            USER_SCHEMA_T(
                SCHEMAS.ID,
                SCHEMAS.NAME,
                SCHEMAS.ALIAS,
                DATABASES.VERSION,
                DATABASES.BASE_URL,
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_ID ),
                UTILITIES.HEX_DECRYPT( SCHEMAS.CLIENT_SECRET )
            )
        INTO
            L_USER_SCHEMA
        FROM
            SCHEMAS JOIN DATABASES ON
                SCHEMAS.DATABASE_ID = DATABASES.ID
        WHERE
            DATABASES.VERSION = L_VERSION
            AND SCHEMAS.ASSIGNED_TO = P_USER;

        RETURN L_USER_SCHEMA;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_USER_SCHEMA;
END USER_SCHEMAS;
/
-- !SECTION: LIVESQL-945
-- !SECTION: Objects

-- SECTION: ORDS Endpoints
BEGIN
    -- SECTION: LIVESQL-945

  ORDS.DEFINE_TEMPLATE(
      p_module_name    => 'com.oracle.livesql.api',
      p_pattern        => 'database_versions/',
      p_priority       => 0,
      p_etag_type      => 'HASH',
      p_etag_query     => NULL,
      p_comments       => NULL);

  ORDS.DEFINE_HANDLER(
      p_module_name    => 'com.oracle.livesql.api',
      p_pattern        => 'database_versions/',
      p_method         => 'GET',
      p_source_type    => 'json/collection',
      p_items_per_page => 25,
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'SELECT
    VERSION
FROM
    DATABASES
ORDER BY
        TO_NUMBER(REGEXP_SUBSTR( VERSION, ''\\d+'', 1, 1)) DESC NULLS LAST,
        TO_NUMBER(REGEXP_SUBSTR( VERSION, ''\\d+'', 1, 2)) DESC NULLS LAST,
        TO_NUMBER(REGEXP_SUBSTR( VERSION, ''\\d+'', 1, 3)) DESC NULLS LAST');

    -- !SECTION: LIVESQL-945
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- !SECTION: LIVE_SQL

-- IMPORTANT: Mention the end of the patch upgrade (something like 'r<number> patch applied...')
PROMPT r31-livesql-945 applied...
