PROMPT Upgrading METADATA to r31...

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

-- SECTION: Objects 

-- SECTION: LIVESQL-612
-- Alter the table statements to add a new virtual column created_on_part
ALTER TABLE USERS
    ADD LAST_SESSION_EXPIRED_ON TIMESTAMP WITH TIME ZONE;

-- !SECTION: LIVESQL-612

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
    -- SECTION: LIVESQL-612
  ORDS.DEFINE_HANDLER(
      p_module_name    => 'com.oracle.livesql.auth',
      p_pattern        => 'token',
      p_method         => 'GET',
      p_source_type    => 'plsql/block',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'DECLARE
    L_URL VARCHAR2(4000) := GET_PARAMETER( ''IDCS_URL'' );
    L_CLIENT_ID VARCHAR2(512) := UTILITIES.HEX_DECRYPT( GET_PARAMETER( ''IDCS_CLIENT_ID'' ) );
    L_CLIENT_SECRET VARCHAR2(512) := UTILITIES.HEX_DECRYPT( GET_PARAMETER( ''IDCS_CLIENT_SECRET'' ) );
    L_CANONICAL_URL VARCHAR2(4000) := GET_PARAMETER( ''CANONICAL_URL'' );
    L_WALLET_PATH VARCHAR2(4000) := NULL;

    L_BODY CLOB;
    L_RESPONSE CLOB;

    L_TOKENS JSON_OBJECT_T;
    L_USER_INFO JSON_OBJECT_T;

    L_USER_EMAIL USERS.EMAIL%TYPE;
    L_USER_DISPLAY_NAME USERS.DISPLAY_NAME%TYPE;
    L_USER_ID USERS.ID%TYPE;

    IDCS_ERROR EXCEPTION;
    BAD_REQUEST EXCEPTION;
    SCOPES_DENIED EXCEPTION;
BEGIN
    -- If login or authorization failed raise exception
    IF :error IS NOT NULL THEN
        RAISE IDCS_ERROR;
    END IF;

    IF DOES_PARAMETER_EXIST( ''WALLET_PATH'' ) THEN
        L_WALLET_PATH := GET_PARAMETER( ''WALLET_PATH'' );
    END IF;

    APEX_WEB_SERVICE.SET_REQUEST_HEADERS(
        P_NAME_01 => ''Content-Type'',
' || '        P_VALUE_01 => ''application/x-www-form-urlencoded'',
        P_RESET => TRUE
    );

    -- Begin the request to get access_token
    L_RESPONSE := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        P_URL => L_URL || ''/oauth2/v1/token'',
        P_HTTP_METHOD => ''POST'',
        P_USERNAME => L_CLIENT_ID,
        P_PASSWORD => L_CLIENT_SECRET,
        P_BODY => CASE WHEN :refresh_token IS NOT NULL THEN ''grant_type=refresh_token&refresh_token='' || :refresh_token ELSE ''grant_type=authorization_code&code='' || :code END,
        P_WALLET_PATH => L_WALLET_PATH
    );

    -- If refresh_token is used, return the response as JSON
    IF :refresh_token IS NOT NULL THEN
        OWA_UTIL.MIME_HEADER( ''application/json'', TRUE );
        HTP.P( L_RESPONSE );
        :status_code := APEX_WEB_SERVICE.G_STATUS_CODE;
        RETURN;

        -- The refresh token does not contain an expiration date
        -- As a result, to ensure the information remains valid, we are updating with timestamp
        -- in the database to keep track of the last time the user was active
        L_USER_EMAIL := UPPER( L_USER_INFO.GET_STRING( ''sub'' ) );
        
        UPDATE
            USERS
        SET
            LAST_SESSION_EXPIRED_ON = CURRENT_TIMESTAMP
        WHERE 
            1 = 1
        AND 
            EMAIL = L_USER_EMAIL;
        COMMIT;

    END IF;

    -- Parse the response to JSON
    L_TOKENS := JSON_OBJECT_T.PARSE( L_RESPONSE );

    IF APEX_WEB_SERVICE.G_STATUS_CODE != 200 THEN
        RAISE BAD_REQUEST' || ';
    END IF;

    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := ''Authorization'';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''Bearer '' || L_TOKENS.GET_STRING( ''access_token'' );

    -- Begin request to get users data
    L_RESPONSE := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        P_URL => L_URL || ''/oauth2/v1/userinfo'',
        P_HTTP_METHOD => ''GET'',
        P_WALLET_PATH => L_WALLET_PATH
    );

    -- At this point the request should only fail in case the user did not
    -- authorized any openid connect related scope
    IF APEX_WEB_SERVICE.G_STATUS_CODE != 200 THEN
        RAISE SCOPES_DENIED;
    END IF;

    L_USER_INFO := JSON_OBJECT_T.PARSE( L_RESPONSE );

    -- Register user into the database
    L_USER_EMAIL := UPPER( L_USER_INFO.GET_STRING( ''sub'' ) );
    L_USER_DISPLAY_NAME := L_USER_INFO.GET_STRING( ''name'' );

    BEGIN
        SELECT
            ID
        INTO
            L_USER_ID
        FROM
            USERS
        WHERE
            EMAIL = L_USER_EMAIL;
   ' || ' EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO
                USERS (
                    EMAIL,
                    DISPLAY_NAME,
                    ROLE_ID, 
                    LAST_SESSION_EXPIRED_ON
                )
                VALUES (
                    L_USER_EMAIL,
                    L_USER_DISPLAY_NAME,
                    1, 
                    CURRENT_TIMESTAMP
                )
            RETURNING ID INTO L_USER_ID;
            COMMIT;
        IF L_USER_ID IS NOT NULL THEN 
            UPDATE
                USERS
               SET
                LAST_SESSION_EXPIRED_ON = CURRENT_TIMESTAMP
             WHERE 
                1 = 1
               AND 
                EMAIL = L_USER_EMAIL;
            COMMIT;
        END IF; 
    END;

    OWA_UTIL.REDIRECT_URL( 
        L_CANONICAL_URL || ''#''
        || ''access_token='' || L_TOKENS.GET_STRING( ''access_token'' )
        || ''&token_type='' || L_TOKENS.GET_STRING( ''token_type'' )
        || ''&id_token='' || L_TOKENS.GET_STRING( ''id_token'' )
        || ''&refresh_token='' || L_TOKENS.GET_STRING( ''refresh_token'' )
        || ''&expires_in='' || L_TOKENS.GET_STRING( ''expires_in'' )
    );
    :status_code := 302;
EXCEPTION
    WHEN IDCS_ERROR THEN
        OWA_UTIL.REDIRECT_URL( L_CANONICAL_URL || ''#error='' || :error );
        :status_code := 302;
    WHEN BAD_REQUEST THEN
       ' || ' OWA_UTIL.REDIRECT_URL(
            L_CANONICAL_URL || ''#''
            || ''error='' || L_TOKENS.GET_STRING( ''error'' )
            || ''&error_description='' || UTL_URL.ESCAPE( URL => L_TOKENS.GET_STRING( ''error_description'' ), ESCAPE_RESERVED_CHARS => TRUE )
        );
        :status_code := 302;
    WHEN SCOPES_DENIED THEN
        OWA_UTIL.REDIRECT_URL( L_CANONICAL_URL || ''#error=scopes_denied'' );
        :status_code := 302;
END;');
-- !SECTION: LIVESQL-612
    COMMIT;
END;
/

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

BEGIN
    -- SECTION: LIVESQL-949
    
  ORDS.DEFINE_HANDLER(
      p_module_name    => 'com.oracle.livesql.api',
      p_pattern        => 'statements/',
      p_method         => 'GET',
      p_source_type    => 'json/collection',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'SELECT
    STATEMENTS.CREATED_ON,
    STATEMENTS.CODE_LANGUAGE,
    STATEMENTS.ID,
    STATEMENTS.CREATED_BY,
    STATEMENTS.CONTENT,
    DATABASES.VERSION AS DB_VERSION,
    JSON_QUERY ( STATEMENTS.RESULT, ''$'' RETURNING CLOB ) RESULT
FROM
    STATEMENTS
    JOIN SCHEMAS ON STATEMENTS.SCHEMA_ID = SCHEMAS.ID
    JOIN DATABASES ON SCHEMAS.DATABASE_ID = DATABASES.ID
WHERE
    UPPER( :current_user ) IS NOT NULL
    AND (
        :version IS NULL
        OR :version = DATABASES.VERSION
    )
    AND (
        STATEMENTS.CREATED_BY = UPPER( :current_user )
    )
    AND (
        :search_term IS NULL OR ( UPPER( STATEMENTS.CONTENT ) LIKE ''%'' || UPPER( :search_term ) || ''%'' )
    )
ORDER BY STATEMENTS.CREATED_ON DESC');

  ORDS.DEFINE_HANDLER(
      p_module_name    => 'com.oracle.livesql.api',
      p_pattern        => 'statements/',
      p_method         => 'POST',
      p_source_type    => 'plsql/block',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'DECLARE
    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    L_STATEMENT_ID NUMBER;
BEGIN
    IF NOT AUTHORIZATION.HAS_ROLE( L_CURRENT_USER, ''BASIC'' ) THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' );
        :status_code := 401;
        RETURN;
    END IF;

    INSERT INTO STATEMENTS(
        CONTENT,
        CODE_LANGUAGE,
        CREATED_BY,
        RESULT,
        SCHEMA_ID
    ) VALUES (
        :content,
        :code_language,
        L_CURRENT_USER,
        :result,
        user_schemas.GET_USER_SCHEMA( L_CURRENT_USER, :db_version ).id
    ) RETURNING ID INTO L_STATEMENT_ID;
    :status_code := 201;
    :forward_location := L_STATEMENT_ID;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad request'' );
        :status_code := 400;
END;');

  ORDS.DEFINE_HANDLER(
      p_module_name    => 'com.oracle.livesql.api',
      p_pattern        => 'statements/batch/',
      p_method         => 'POST',
      p_source_type    => 'plsql/block',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'DECLARE
    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    sql_history_list_object JSON_OBJECT_T;
    sql_history_list JSON_ARRAY_T;
    statement JSON_OBJECT_T;
    statement_timestamp TIMESTAMP;
    statement_text CLOB;
    statement_db_version VARCHAR2(320 BYTE);
    result CLOB;
    L_STATEMENT_ID NUMBER;
BEGIN

    IF NOT AUTHORIZATION.HAS_ROLE( L_CURRENT_USER, ''BASIC'' ) THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' );
        :status_code := 401;
        RETURN;
    END IF;

    sql_history_list_object := JSON_OBJECT_T.parse(:body);
    sql_history_list := sql_history_list_object.get_array(''sql_history_list'');

    FOR ind IN 0..sql_history_list.get_size - 1
    LOOP
        statement := TREAT(sql_history_list.get(ind) as JSON_OBJECT_T);
        result := statement.TO_CLOB;
        statement_text := statement.get_clob(''statementText'');
        statement_timestamp := statement.get_timestamp(''statementTimestamp'');
        statement' || '_db_version := statement.get_string(''db_version'');
        INSERT INTO STATEMENTS(
            CONTENT,
            CREATED_BY,
            SCHEMA_ID,
            RESULT
        ) VALUES (
            statement_text,
            L_CURRENT_USER,
            USER_SCHEMAS.ASSIGN_SCHEMA_TO_USER( L_CURRENT_USER, statement_db_version ).id,
            UTL_RAW.CAST_TO_RAW(result)
        ) RETURNING ID INTO L_STATEMENT_ID;
    END LOOP;
    :status_code := 201;
    :forward_location := L_STATEMENT_ID;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad request'' );
        :status_code := 400;
END;');
    -- !SECTION: LIVESQL-949
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- NOTE: Update the version after the upgrade
BEGIN
    SET_PARAMETER( 'VERSION', 'r31' );
    SET_PARAMETER( 'LAST_UPDATED_ON', TO_CHAR( CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-DD-MM"T"HH24:MI:SS.FF3"Z"' ) );
END;
/
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA to r31 complete
