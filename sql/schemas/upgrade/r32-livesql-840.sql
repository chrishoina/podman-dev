PROMPT applying r32-livesql-840 patch on schemas PDB...

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

-- SECTION: SYSDBA
SET FEEDBACK OFF
CONNECT SYS/"^PDB_ADMIN_PASSWORD" AS SYSDBA
SET FEEDBACK ON


-- This specific role can not be assigned to schemas through LIVE_SQL_READ_WRITE_USER
-- And needs the SYS privilege in order to be assigned to schemas, that's why we give the LIVE_SQL user
-- the privilege to execute this PROCEDURE inside SCHEMA_MANAGEMENT package for new created schemas.
CREATE OR REPLACE PROCEDURE GRANT_EXECUTE_ON_JAVASCRIPT_TO_SCHEMA( P_SCHEMA_NAME VARCHAR2 )
AUTHID DEFINER
AS
BEGIN
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON JAVASCRIPT TO ' || DBMS_ASSERT.ENQUOTE_NAME( P_SCHEMA_NAME );
END;
/

GRANT EXECUTE ON GRANT_EXECUTE_ON_JAVASCRIPT_TO_SCHEMA TO LIVE_SQL;

-- Grant execute on javascript directly  to the existing schemas since we can
-- not assign it directly through the LIVE_SQL_READ_WRITE_USER
BEGIN
    FOR L_SCHEMA IN ( SELECT NAME, IS_READ_ONLY FROM LIVE_SQL.SCHEMAS ) LOOP
        IF L_SCHEMA.IS_READ_ONLY !='Y' THEN
                GRANT_EXECUTE_ON_JAVASCRIPT_TO_SCHEMA( L_SCHEMA.NAME );
        END IF;
    END LOOP;
END;
/

-- !SECTION: SYSDBA

-- SECTION: ADMIN

SET FEEDBACK OFF
CONNECT "^PDB_ADMIN_USERNAME"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: Objects 

-- SECTION: LIVESQL-840
-- Note: add the mle grants to the LIVE_SQL_READ_WRITE_USER role
BEGIN
    IF DBMS_DB_VERSION.VER_LE_23 THEN
        EXECUTE IMMEDIATE 'GRANT EXECUTE DYNAMIC MLE TO LIVE_SQL_READ_WRITE_USER';
        EXECUTE IMMEDIATE 'GRANT CREATE MLE TO LIVE_SQL_READ_WRITE_USER';
    END IF;
END;
/
-- !SECTION: LIVESQL-840
-- !SECTION: Objects

-- !SECTION: ADMIN


-- SECTION: LIVE_SQL
SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: Objects 
-- SECTION: LIVESQL-840

-- Update the schema management package to add the `execute on javascript` privilege directly to new created schemas
-- since we can not add it through LIVE_SQL_READ_WRITE_USER
CREATE OR REPLACE PACKAGE BODY SCHEMA_MANAGEMENT AS
    PROCEDURE VALIDATE_SCHEMA_CREATION_PARAMETERS IS
        L_REQURED_PARAMETERS VC2_TABLE_T := VC2_TABLE_T(
            'DATABASE_ID',
            'METADATA_DATABASE_BASE_URL',
            'METADATA_DATABASE_SCHEMA_ALIAS',
            'METADATA_DATABASE_SCHEMA_CLIENT_ID',
            'METADATA_DATABASE_SCHEMA_CLIENT_SECRET'
        );
        L_PARAMETER_NAME PARAMETERS.NAME%TYPE;
    BEGIN
        FOR I IN 1..L_REQURED_PARAMETERS.COUNT LOOP
            L_PARAMETER_NAME := L_REQURED_PARAMETERS( I );
            IF NOT DOES_PARAMETER_EXIST( L_PARAMETER_NAME ) THEN
                RAISE_APPLICATION_ERROR( -20000, 'Schema creation job cannot be processed because the "' || L_PARAMETER_NAME || '" parameter has not been set' );
            END IF;
            IF GET_PARAMETER( 'DATABASE_ID' ) IS NULL THEN
                RAISE_APPLICATION_ERROR( -20000, 'Schema creation job cannot be processed because the "' || L_PARAMETER_NAME || '" parameter value is NULL' );
            END IF;
        END LOOP;
    END VALIDATE_SCHEMA_CREATION_PARAMETERS;

    PROCEDURE AUTHENTICATE_TO_METADATA_DATABASE IS
    BEGIN
        APEX_WEB_SERVICE.OAUTH_AUTHENTICATE(
            P_TOKEN_URL => GET_PARAMETER( 'METADATA_DATABASE_BASE_URL' ) || GET_PARAMETER( 'METADATA_DATABASE_SCHEMA_ALIAS' ) || '/oauth/token',
            P_CLIENT_ID => UTILITIES.HEX_DECRYPT( GET_PARAMETER( 'METADATA_DATABASE_SCHEMA_CLIENT_ID' ) ),
            P_CLIENT_SECRET => UTILITIES.HEX_DECRYPT( GET_PARAMETER( 'METADATA_DATABASE_SCHEMA_CLIENT_SECRET' ) ),
            P_FLOW_TYPE => APEX_WEB_SERVICE.OAUTH_CLIENT_CRED
        );
        IF APEX_WEB_SERVICE.G_STATUS_CODE != 200 THEN
            RAISE_APPLICATION_ERROR( -20000, 'An error occurred while registering the schema. OAuth authentication request to the metadata database returned with status ' || APEX_WEB_SERVICE.G_STATUS_CODE );
        END IF;
    END AUTHENTICATE_TO_METADATA_DATABASE;

    FUNCTION GENERATE_SCHEMA_NAME RETURN VARCHAR2 IS
        C_SCHEMA_NAME_PREFIX CONSTANT VARCHAR2(4) := 'SQL_';
        C_MAX_TRIES CONSTANT NUMBER := 100;

        L_SCHEMA_NAME VARCHAR2(30);

        L_ITERATIONS NUMBER := 0;
        L_DOES_SCHEMA_EXISTS VARCHAR2(1);
    BEGIN
        LOOP
            IF L_ITERATIONS >= C_MAX_TRIES THEN
                RAISE_APPLICATION_ERROR( -20000, 'Could not generate a new schema name. Maximum tries exceeded.' );
            END IF;

            L_ITERATIONS := L_ITERATIONS + 1;

            -- NOTE: Adding the SQL_ prefix to differentiate user schemas from other
            --       schemas in the DB
            -- 'X' - Returns string is in uppercase alpha-numeric characters
            L_SCHEMA_NAME := C_SCHEMA_NAME_PREFIX || DBMS_RANDOM.STRING( 'X', 26 );

            SELECT
                CASE WHEN COUNT(1) > 0 THEN 'Y' ELSE 'N' END AS DOES_SCHEMA_EXISTS
            INTO
                L_DOES_SCHEMA_EXISTS
            FROM
                ALL_USERS
            WHERE
                USERNAME = L_SCHEMA_NAME;
        EXIT WHEN L_DOES_SCHEMA_EXISTS != 'Y';
        END LOOP;

        RETURN L_SCHEMA_NAME;
    END GENERATE_SCHEMA_NAME;

    -- NOTE: Function to generate new passwords. Passwords can contain lower
    --       case letters, upper case letters, digits, and special characters.
    --       A minimum required number of characters can be specified for each
    --       type
    FUNCTION GENERATE_SCHEMA_PASSWORD RETURN VARCHAR2 IS
        C_MAX_PASSWORD_LENGTH CONSTANT NUMBER := 30;

        C_MIN_LOWERCASE CONSTANT NUMBER := 1;
        C_MIN_UPPERCASE CONSTANT NUMBER := 1;
        C_MIN_NUMBERS CONSTANT NUMBER := 1;
        C_MIN_SPECIAL CONSTANT NUMBER := 1;

        C_SPECIAL_CHARACTERS CONSTANT VARCHAR2( 4 ) := '!#$@';

        L_PASSWORD VARCHAR2( C_MAX_PASSWORD_LENGTH );
        L_COUNT NUMBER := 0;

        FUNCTION SHUFFLE_PASSWORD( P_PASSWORD VARCHAR2 ) RETURN VARCHAR2 IS
            L_I INTEGER;
            L_R INTEGER;
            L_C CHAR(1);
            L_PASSWORD VARCHAR2( C_MAX_PASSWORD_LENGTH ) := P_PASSWORD;
        BEGIN
            FOR L_I IN REVERSE 2 .. LENGTH( L_PASSWORD ) - 1 LOOP
                L_R := TRUNC( DBMS_RANDOM.VALUE( 1, L_I + 1 ) );
                L_C := SUBSTR( L_PASSWORD, L_I, 1 );
                L_PASSWORD := SUBSTR( L_PASSWORD, 1, L_I - 1 ) || SUBSTR( L_PASSWORD, L_R, 1 ) || SUBSTR( L_PASSWORD, L_I + 1 );
                L_PASSWORD := SUBSTR( L_PASSWORD, 1, L_R - 1 ) || L_C || SUBSTR( L_PASSWORD, L_R + 1 );
            END LOOP;

            RETURN L_PASSWORD;
        END SHUFFLE_PASSWORD;
    BEGIN
        -- Add enough upper case to satisfy the minimum
        -- 'U' - Returns string is in uppercase alpha characters
        L_PASSWORD := DBMS_RANDOM.STRING( 'U', C_MIN_UPPERCASE );
        L_COUNT := L_COUNT + C_MIN_UPPERCASE;

        -- Add enough lower case to satisfy the minimum
        -- 'L' - Returns string is in lowercase alpha characters
        L_PASSWORD := L_PASSWORD || DBMS_RANDOM.STRING( 'L', C_MIN_LOWERCASE );
        L_COUNT := L_COUNT + C_MIN_LOWERCASE;

        -- Add enough digits to satisfy the minimum
        FOR i IN 1 .. C_MIN_NUMBERS LOOP
            L_PASSWORD := L_PASSWORD || TRUNC( DBMS_RANDOM.VALUE( 1, 9 ) );
        END LOOP;
        L_COUNT := L_COUNT + C_MIN_NUMBERS;

        -- And finally enough special characters
        L_PASSWORD:= L_PASSWORD || SUBSTR( C_SPECIAL_CHARACTERS, TRUNC( DBMS_RANDOM.VALUE( 1, LENGTH( C_SPECIAL_CHARACTERS ) ) ), C_MIN_SPECIAL );
        L_COUNT := L_COUNT + C_MIN_SPECIAL;

        -- Randomly fill the rest
        -- 'X' - Returns string is in uppercase alpha-numeric characters
        L_PASSWORD := L_PASSWORD || DBMS_RANDOM.STRING( 'X', C_MAX_PASSWORD_LENGTH - L_COUNT );
        L_PASSWORD := SHUFFLE_PASSWORD( L_PASSWORD );

        RETURN L_PASSWORD;
    END GENERATE_SCHEMA_PASSWORD;

    PROCEDURE CREATE_SCHEMA( P_SCHEMA_NAME VARCHAR2 DEFAULT GENERATE_SCHEMA_NAME() ) IS
    BEGIN
        IF P_SCHEMA_NAME IS NULL THEN
            RAISE_APPLICATION_ERROR( -20000, 'Cannot create a user with an empty name' );
        END IF;

        -- NOTE: There's no need to store the password since we'll use the
        --       client ID and client secret.
        EXECUTE IMMEDIATE 'CREATE USER ' || DBMS_ASSERT.ENQUOTE_NAME( P_SCHEMA_NAME ) || ' IDENTIFIED BY ' || DBMS_ASSERT.ENQUOTE_NAME( GENERATE_SCHEMA_PASSWORD() ) || ' DEFAULT TABLESPACE USERS QUOTA 10M ON USERS';
    END CREATE_SCHEMA;

    FUNCTION REST_ENABLE_SCHEMA( P_SCHEMA_NAME VARCHAR2 ) RETURN JSON_OBJECT_T IS
        L_SCHEMA_ALIAS ORDS_METADATA.DBA_ORDS_URL_MAPPINGS.PATTERN%TYPE := LOWER( P_SCHEMA_NAME );
        L_CLIENT_ID ORDS_METADATA.USER_ORDS_CLIENTS.CLIENT_ID%TYPE;
        L_CLIENT_SECRET ORDS_METADATA.USER_ORDS_CLIENTS.CLIENT_SECRET%TYPE;

        L_RESULT JSON_OBJECT_T := JSON_OBJECT_T();
    BEGIN
        ORDS_METADATA.ORDS.ENABLE_SCHEMA(
            P_ENABLED => TRUE,
            P_SCHEMA => P_SCHEMA_NAME,
            P_URL_MAPPING_TYPE => 'BASE_PATH',
            -- NOTE: Force lower-case for URLs to avoid confusion 
            P_URL_MAPPING_PATTERN => L_SCHEMA_ALIAS,
            P_AUTO_REST_AUTH => TRUE
        );
        -- Create OAuth client to act in name of the new schema
        ORDS_METADATA.OAUTH_ADMIN.CREATE_CLIENT(
            P_SCHEMA => P_SCHEMA_NAME,
            P_NAME => P_SCHEMA_NAME,
            P_GRANT_TYPE => 'client_credentials',
            P_OWNER => P_SCHEMA_NAME,
            P_DESCRIPTION => 'LIVE SQL Schema client',
            P_ORIGINS_ALLOWED => 'https://localhost,https://livesql-stg.oracle.com,https://livesql.oracle.com',
            P_REDIRECT_URI => NULL,
            P_SUPPORT_EMAIL => 'support@oracle.com',
            P_SUPPORT_URI => 'https://support.oracle.com',
            P_PRIVILEGE_NAMES => NULL
        );
        ORDS_METADATA.OAUTH_ADMIN.GRANT_CLIENT_ROLE(
            P_SCHEMA => P_SCHEMA_NAME,
            P_CLIENT_NAME => P_SCHEMA_NAME,
            P_ROLE_NAME => 'SQL Developer'
        );
        COMMIT;

        SELECT
            ORDS_METADATA.OAUTH_CLIENTS.CLIENT_ID,
            ORDS_METADATA.OAUTH_CLIENTS.CLIENT_SECRET
        INTO
            L_CLIENT_ID,
            L_CLIENT_SECRET
        FROM
            ORDS_METADATA.OAUTH_CLIENTS JOIN ORDS_METADATA.ORDS_SCHEMAS ON
                ORDS_METADATA.ORDS_SCHEMAS.PARSING_SCHEMA = P_SCHEMA_NAME
                AND ORDS_METADATA.OAUTH_CLIENTS.NAME = P_SCHEMA_NAME
                AND ORDS_METADATA.OAUTH_CLIENTS.SCHEMA_ID = ORDS_METADATA.ORDS_SCHEMAS.ID;

        L_RESULT.PUT( 'alias', L_SCHEMA_ALIAS );
        L_RESULT.PUT( 'client_id', L_CLIENT_ID );
        L_RESULT.PUT( 'client_secret', L_CLIENT_SECRET );

        RETURN L_RESULT;
    END REST_ENABLE_SCHEMA;

    -- TODO: Is this still needed? Since when you create a schema, it doesn't have any role, permissions, grants, and so on
    -- Lockdown the Schema ( Remove Grants/Privileges, add limits and quotas )
    /*PROCEDURE LOCKDOWN_SCHEMA( P_SCHEMA_ID SCHEMAS.ID%TYPE )
    IS
    BEGIN
        -- Revoke all object privileges
        FOR obj_priv IN ( SELECT * FROM USER_TAB_PRIVS WHERE GRANTEE = P_SCHEMA_NAME ) LOOP
            EXECUTE IMMEDIATE 'REVOKE ALL PRIVILEGES ON ' || obj_priv.TABLE_NAME || ' FROM ' || P_SCHEMA_NAME;
        END LOOP;

        -- Revoke all system privileges
        -- TODO: review how to revoke all privileges
        FOR sys_priv IN ( SELECT * FROM USER_SYS_PRIVS WHERE GRANTEE = P_SCHEMA_NAME ) LOOP
            EXECUTE IMMEDIATE 'REVOKE ' || sys_priv.PRIVILEGE || ' FROM ' || P_SCHEMA_NAME;
        END LOOP;

        -- Set resource limits
        EXECUTE IMMEDIATE 'ALTER USER ' || DBMS_ASSERT.QUALIFIED_SQL_NAME( P_SCHEMA_NAME ) || ' SESSIONS_PER_USER 1';

        -- Set storage quota
        EXECUTE IMMEDIATE 'ALTER USER ' || DBMS_ASSERT.QUALIFIED_SQL_NAME( P_SCHEMA_NAME ) || ' QUOTA 10M ON USERS';

        -- Commit the changes
        COMMIT;
    END;*/

    PROCEDURE REQUEST_SCHEMA_REGISTRATION( P_SCHEMA_ID SCHEMAS.ID%TYPE ) IS
        L_BODY CLOB;
        L_RESPONSE CLOB;
    BEGIN
        SELECT
            JSON_OBJECT(
                KEY 'database_id' VALUE GET_PARAMETER( 'DATABASE_ID' ),
                KEY 'database_schema_id' VALUE ID,
                KEY 'database_schema_creatn_job_id' VALUE CREATION_JOB_ID,
                KEY 'name' VALUE NAME,
                KEY 'is_read_only' VALUE IS_READ_ONLY,
                KEY 'alias' VALUE ALIAS,
                KEY 'client_id' VALUE CLIENT_ID,
                KEY 'client_secret' VALUE CLIENT_SECRET
                RETURNING CLOB
            )
        INTO
            L_BODY
        FROM
            SCHEMAS
        WHERE
            ID = P_SCHEMA_ID
            -- TODO: Change to LOCKED when lock down is implemented
            AND STATUS = 'REST_ENABLED';

        AUTHENTICATE_TO_METADATA_DATABASE();

        APEX_WEB_SERVICE.CLEAR_REQUEST_HEADERS;
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := 'Authorization';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'Bearer ' || APEX_WEB_SERVICE.OAUTH_GET_LAST_TOKEN();
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME := 'Content-Type';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := 'application/json';

        L_RESPONSE := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
            P_URL => GET_PARAMETER( 'METADATA_DATABASE_BASE_URL' ) || GET_PARAMETER( 'METADATA_DATABASE_SCHEMA_ALIAS' ) || '/api/schemas/',
            P_HTTP_METHOD => 'POST',
            P_BODY => L_BODY
        );
        IF APEX_WEB_SERVICE.G_STATUS_CODE != 201 THEN
            RAISE_APPLICATION_ERROR( -20000, 'An error occurred while registering the schema. Registration request returned with HTTP status code ' || APEX_WEB_SERVICE.G_STATUS_CODE );
        END IF;

        UPDATE
            SCHEMAS
        SET
            STATUS = 'REGISTERED'
        WHERE
            ID = P_SCHEMA_ID;
        COMMIT;
    END REQUEST_SCHEMA_REGISTRATION;

    PROCEDURE PROCESS_SCHEMA_CREATION_JOB( P_SCHEMA_CREATION_JOB_ID SCHEMA_CREATION_JOBS.ID%TYPE ) IS
        L_NUMBER_OF_SCHEMAS SCHEMA_CREATION_JOBS.NUMBER_OF_SCHEMAS%TYPE;
        L_ARE_SCHEMAS_READ_ONLY SCHEMA_CREATION_JOBS.ARE_SCHEMAS_READ_ONLY%TYPE;
        L_STATUS SCHEMA_CREATION_JOBS.STATUS%TYPE;
        L_DATABASE_ID PARAMETERS.VALUE%TYPE;
        L_ERROR SCHEMA_CREATION_JOBS.ERROR%TYPE;
        L_SCHEMAS_ERRORS_COUNT INTEGER := 0;
        L_SCHEMAS_ERRORS CLOB;
    BEGIN
        VALIDATE_SCHEMA_CREATION_PARAMETERS();

        SELECT
            NUMBER_OF_SCHEMAS,
            ARE_SCHEMAS_READ_ONLY,
            STATUS,
            ERROR
        INTO
            L_NUMBER_OF_SCHEMAS,
            L_ARE_SCHEMAS_READ_ONLY,
            L_STATUS,
            L_ERROR
        FROM
            SCHEMA_CREATION_JOBS
        WHERE
            ID = P_SCHEMA_CREATION_JOB_ID;

        IF L_STATUS != 'NEW' OR L_ERROR IS NOT NULL THEN
            RAISE_APPLICATION_ERROR( -20000, 'Schema creation job cannot be processed because either its status is not NEW or it has errors' );
        END IF;

        DBMS_LOB.CREATETEMPORARY(
            LOB_LOC => L_SCHEMAS_ERRORS,
            CACHE => FALSE,
            DUR => DBMS_LOB.CALL
        );

        DECLARE
            L_CURRENT_SCHEMA_NAME SCHEMAS.NAME%TYPE;
            L_CURRENT_SCHEMA_ID SCHEMAS.ID%TYPE;
            L_REST_DETAILS JSON_OBJECT_T;
            L_REST_ALIAS SCHEMAS.ALIAS%TYPE;
            L_REST_CLIENT_ID SCHEMAS.CLIENT_ID%TYPE;
            L_REST_CLIENT_SECRET SCHEMAS.CLIENT_SECRET%TYPE;
            L_CURRENT_CREATION_ERROR SCHEMAS.CREATION_ERROR%TYPE;
        BEGIN
            FOR I IN 1 .. L_NUMBER_OF_SCHEMAS LOOP
                INSERT INTO
                    SCHEMAS (
                        NAME,
                        IS_READ_ONLY,
                        STATUS,
                        CREATION_JOB_ID
                    )
                    VALUES (
                        GENERATE_SCHEMA_NAME(),
                        L_ARE_SCHEMAS_READ_ONLY,
                        'NEW',
                        P_SCHEMA_CREATION_JOB_ID
                    )
                    RETURNING
                        ID,
                        NAME
                    INTO
                        L_CURRENT_SCHEMA_ID,
                        L_CURRENT_SCHEMA_NAME;
                COMMIT;

                BEGIN
                    CREATE_SCHEMA( P_SCHEMA_NAME => L_CURRENT_SCHEMA_NAME );

                    UPDATE
                        SCHEMAS
                    SET
                        STATUS = 'CREATED'
                    WHERE
                        ID = L_CURRENT_SCHEMA_ID;
                    COMMIT;

                    EXECUTE IMMEDIATE 'GRANT CONNECT TO ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) );
                    -- LIVE_SQL_SAMPLE_SCHEMAS_USER is a read-only role for sample schemas
                    EXECUTE IMMEDIATE 'GRANT LIVE_SQL_SAMPLE_SCHEMAS_USER TO ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) );
                    -- LIVE_SQL_READ_ONLY_USER is a role that holds all the privileges for read-only users so that they're easy to modify
                    EXECUTE IMMEDIATE 'GRANT LIVE_SQL_READ_ONLY_USER TO ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) );

                    IF L_ARE_SCHEMAS_READ_ONLY != 'Y' THEN
                        EXECUTE IMMEDIATE 'GRANT RESOURCE TO ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) );
                        -- LIVE_SQL_READ_WRITE_USER is a role that holds all the privileges for read-write users so that they're easy to modify
                        EXECUTE IMMEDIATE 'GRANT LIVE_SQL_READ_WRITE_USER TO ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) );
                        EXECUTE IMMEDIATE 'ALTER USER ' || DBMS_ASSERT.ENQUOTE_NAME( DBMS_ASSERT.SCHEMA_NAME( L_CURRENT_SCHEMA_NAME ) ) || ' QUOTA 10M ON SYSAUX';
                        -- grant the privilege to schema with SYS privilege, this could not be done using the LIVE_SQL_READ_WRITE_USER role.
                        SYS.GRANT_EXECUTE_ON_JAVASCRIPT_TO_SCHEMA( L_CURRENT_SCHEMA_NAME );
                    END IF;

                    UPDATE
                        SCHEMAS
                    SET
                        STATUS = 'GRANTED'
                    WHERE
                        ID = L_CURRENT_SCHEMA_ID;
                    COMMIT;

                    L_REST_DETAILS := REST_ENABLE_SCHEMA( L_CURRENT_SCHEMA_NAME );
                    L_REST_ALIAS := L_REST_DETAILS.GET_STRING( 'alias' );
                    L_REST_CLIENT_ID := L_REST_DETAILS.GET_STRING( 'client_id' );
                    L_REST_CLIENT_SECRET := L_REST_DETAILS.GET_STRING( 'client_secret' );

                    UPDATE
                        SCHEMAS
                    SET
                        STATUS = 'REST_ENABLED',
                        ALIAS = L_REST_ALIAS,
                        CLIENT_ID = L_REST_CLIENT_ID,
                        CLIENT_SECRET = L_REST_CLIENT_SECRET
                    WHERE
                        ID = L_CURRENT_SCHEMA_ID;
                    COMMIT;

                    -- TODO: Add schema lockdown

                    REQUEST_SCHEMA_REGISTRATION( P_SCHEMA_ID => L_CURRENT_SCHEMA_ID );
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_LOB.CREATETEMPORARY(
                            LOB_LOC => L_CURRENT_CREATION_ERROR,
                            CACHE => FALSE,
                            DUR => DBMS_LOB.CALL
                        );

                        DBMS_LOB.APPEND( L_CURRENT_CREATION_ERROR, DBMS_UTILITY.FORMAT_ERROR_STACK() );
                        DBMS_LOB.APPEND( L_CURRENT_CREATION_ERROR, CHR(10) );
                        DBMS_LOB.APPEND( L_CURRENT_CREATION_ERROR, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE() );

                        UPDATE
                            SCHEMAS
                        SET
                            CREATION_ERROR = L_CURRENT_CREATION_ERROR
                        WHERE
                            ID = L_CURRENT_SCHEMA_ID;
                        COMMIT;

                        DBMS_LOB.FREETEMPORARY( LOB_LOC => L_CURRENT_CREATION_ERROR );

                        L_SCHEMAS_ERRORS_COUNT := L_SCHEMAS_ERRORS_COUNT + 1;
                        DBMS_LOB.APPEND( L_SCHEMAS_ERRORS, CASE WHEN L_SCHEMAS_ERRORS_COUNT > 0 THEN CHR(10) END || 'An error occurred while creating schema "' || L_CURRENT_SCHEMA_NAME || '" with ID "' || L_CURRENT_SCHEMA_ID || '"' );
                END;
            END LOOP;

            IF L_SCHEMAS_ERRORS_COUNT > 0 THEN
                RAISE_APPLICATION_ERROR( -20000, L_SCHEMAS_ERRORS_COUNT || ' errors occurred while creating the schemas' );
            END IF;
        END;

        UPDATE
            SCHEMA_CREATION_JOBS
        SET
            STATUS = 'DONE'
        WHERE
            ID = P_SCHEMA_CREATION_JOB_ID;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR( -20000, 'Schema creation job does not exist' );
        WHEN OTHERS THEN
            IF L_ERROR IS NULL OR DBMS_LOB.GETLENGTH( L_ERROR ) = 0 THEN
                DBMS_LOB.CREATETEMPORARY(
                    LOB_LOC => L_ERROR,
                    CACHE => FALSE,
                    DUR => DBMS_LOB.CALL
                );
            ELSE
                DBMS_LOB.APPEND( L_ERROR, CHR(10) || CHR(10) || '---' || CHR(10) || CHR(10) );
            END IF;

            DBMS_LOB.APPEND( L_ERROR, DBMS_UTILITY.FORMAT_ERROR_STACK() );
            DBMS_LOB.APPEND( L_ERROR, CHR(10) );
            DBMS_LOB.APPEND( L_ERROR, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE() );

            IF L_SCHEMAS_ERRORS_COUNT > 0 THEN
                DBMS_LOB.APPEND( L_ERROR, CHR(10) );
                DBMS_LOB.APPEND( L_ERROR, L_SCHEMAS_ERRORS );
            END IF;
            DBMS_LOB.FREETEMPORARY( LOB_LOC => L_SCHEMAS_ERRORS );

            UPDATE
                SCHEMA_CREATION_JOBS
            SET
                ERROR = L_ERROR
            WHERE
                ID = P_SCHEMA_CREATION_JOB_ID;
            COMMIT;

            DBMS_LOB.FREETEMPORARY( LOB_LOC => L_ERROR );
    END PROCESS_SCHEMA_CREATION_JOB;
END SCHEMA_MANAGEMENT;
/

-- !SECTION: LIVESQL-840
-- !SECTION: Objects
-- !SECTION: LIVE_SQL

PROMPT r32-livesql-840 patch
