PROMPT Applying LIVESQL-612 patch...

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
-- NOTE: No upgrades needed
--SET FEEDBACK ON
-- !SECTION: ADMIN

-- SECTION: LIVE_SQL
SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: LIVESQL-612

-- SECTION: Objects 

-- Alter the table statements to add a new virtual column created_on_part
ALTER TABLE USERS
    ADD LAST_SESSION_EXPIRED_ON TIMESTAMP WITH TIME ZONE;

-- SECTION: Handler 

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

-- !SECTION: Handler
-- !SECTION: Objects
-- !SECTION: LIVESQL-612
-- !SECTION: LIVE_SQL


PROMPT LIVESQL-612 patch applied...
