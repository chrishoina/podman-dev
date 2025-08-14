PROMPT Upgrading METADATA to r28...

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

-- SECTION: Objects

-- SECTION: LIVESQL-774
ALTER TABLE SCHEMAS MODIFY (
    NAME VARCHAR2(128 CHAR)
);
-- !SECTION: LIVESQL-774

-- SECTION: LIVESQL-906
ALTER TABLE STATEMENTS DROP CONSTRAINT STATEMENTS_CHK1;
ALTER TABLE STATEMENTS ADD CONSTRAINT STATEMENTS_CHK1 CHECK (CODE_LANGUAGE IN ('PL_SQL', 'QUICK_SQL', 'JAVASCRIPT','SQL_PLUS'));

ALTER TABLE STATEMENTS DROP CONSTRAINT STATEMENTS_CHK3;
ALTER TABLE STATEMENTS ADD CONSTRAINT STATEMENTS_CHK3 CHECK (
    (
        CODE_LANGUAGE IN ( 'PL_SQL', 'JAVASCRIPT', 'SQL_PLUS' )
        AND JSON_EXISTS ( RESULT, '$.statementPos' )
        AND JSON_EXISTS ( RESULT, '$.response' )
        AND JSON_VALUE(RESULT, '$.statementId') IS NOT NULL
        AND JSON_VALUE(RESULT, '$.statementText') IS NOT NULL
        AND JSON_VALUE(RESULT, '$.statementType') IS NOT NULL
        AND JSON_VALUE(RESULT, '$.result') IS NOT NULL
        AND JSON_VALUE(RESULT, '$.statementTimestamp') IS NOT NULL
    )
    OR
    (
        CODE_LANGUAGE = 'QUICK_SQL'
        AND JSON_EXISTS ( RESULT, '$.env' )
        AND JSON_EXISTS ( RESULT, '$.items' )
    )
);
-- !SECTION: LIVESQL-906

-- !SECTION: Objects

-- SECTION: ORDS Endpoints

BEGIN
    -- SECTION: LIVESQL-553
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
    END IF;

    -- Parse the response to JSON
    L_TOKENS := JSON_OBJECT_T.PARSE( L_RESPONSE );

    IF APEX_WEB_SERVICE.G_STATUS_CODE != 200 THEN
        RAISE BAD_REQUEST' || ';
    END IF;

    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := ''Authorization'';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''Bearer '' || L_TOKENS.GET_STRING( ''access_token'' );
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME := ''Accept'';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := ''application/json;charset=utf-8'';

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
  ' || '      SELECT
            ID
        INTO
            L_USER_ID
        FROM
            USERS
        WHERE
            EMAIL = L_USER_EMAIL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO
                USERS (
                    EMAIL,
                    DISPLAY_NAME,
                    ROLE_ID
                )
                VALUES (
                    L_USER_EMAIL,
                    L_USER_DISPLAY_NAME,
                    1
                )
            RETURNING ID INTO L_USER_ID;
            COMMIT;
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
    WHEN IDCS_E' || 'RROR THEN
        OWA_UTIL.REDIRECT_URL( L_CANONICAL_URL || ''#error='' || :error );
        :status_code := 302;
    WHEN BAD_REQUEST THEN
        OWA_UTIL.REDIRECT_URL(
            L_CANONICAL_URL || ''#''
            || ''error='' || L_TOKENS.GET_STRING( ''error'' )
            || ''&error_description='' || UTL_URL.ESCAPE( URL => L_TOKENS.GET_STRING( ''error_description'' ), ESCAPE_RESERVED_CHARS => TRUE )
        );
        :status_code := 302;
    WHEN SCOPES_DENIED THEN
        OWA_UTIL.REDIRECT_URL( L_CANONICAL_URL || ''#error=scopes_denied'' );
        :status_code := 302;
END;');
    -- !SECTION: LIVESQL-553

    -- SECTION: LIVESQL-807
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'statements/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         =>
'
SELECT
    CREATED_ON,
    CODE_LANGUAGE,
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
        user_schemas.GET_USER_SCHEMA( L_CURRENT_USER ).id
    ) RETURNING ID INTO L_STATEMENT_ID;
    :status_code := 201;
    :forward_location := L_STATEMENT_ID;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad request'' );
        :status_code := 400;
END;');
    -- !SECTION: LIVESQL-807

    -- SECTION: LIVESQL-830
    -- Unable to Delete Tutorial Prerequisite When Field is Left Empty During Edit
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'tutorials/:tutorial_slug/',
        p_method         => 'PUT',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         =>
'DECLARE
    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    L_ID NUMBER;
    L_IS_MY_CREATED_YN VARCHAR2(1);

    L_ROLES VC2_TABLE_T := AUTHORIZATION.GET_ROLES( L_CURRENT_USER );

    BAD_REQUEST EXCEPTION;
    NOT_FOUND EXCEPTION;
    UNAUTHORIZED EXCEPTION;
    FORBIDDEN EXCEPTION;
BEGIN
    IF ''BASIC'' NOT MEMBER OF L_ROLES THEN
        RAISE UNAUTHORIZED;
    END IF;

    -- NOTE: Check whether it''s current user''s tutorial or not
    BEGIN
        SELECT
            ID,
            CASE WHEN CREATED_BY = L_CURRENT_USER THEN ''Y'' ELSE ''N'' END AS IS_MY_CREATED
        INTO
            L_ID,
            L_IS_MY_CREATED_YN
        FROM
            TUTORIALS
        WHERE
            SLUG = :tutorial_slug;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE NO_DATA_FOUND;
    END;

    IF ''ADMINISTRATOR'' NOT MEMBER OF L_ROLES THEN
        -- NOTE: We know user is not an administrator at this point (He''s either BASIC or PUBLISHER)
        IF
            -- NO' || 'TE: Only administrators and above are allowed to change the featured column
            :is_featured IS NOT NULL
            OR (
                -- NOTE: Only publishers and above are allowed to change the published column
                :is_published IS NOT NULL
                AND ''PUBLISHER'' NOT MEMBER OF L_ROLES
            )
            OR L_IS_MY_CREATED_YN != ''Y''
        THEN
            RAISE FORBIDDEN;
        END IF;
    END IF;

    IF
        (
            :minimum_database_version IS NOT NULL
            AND NOT UTILITIES.IS_VALID_DATABASE_VERSION( :minimum_database_version )
        ) OR (
            :is_published IS NOT NULL
            AND NOT UTILITIES.IS_VALID_YN_BOOLEAN( :is_published )
        ) OR (
            :is_featured IS NOT NULL
            AND NOT UTILITIES.IS_VALID_YN_BOOLEAN( :is_featured )
        )
    THEN
        RAISE BAD_REQUEST;
    END IF;

    UPDATE
        TUTORIALS
    SET
        TITLE = NVL( :title, TITLE ),
        DESCRIPTION = NVL( :de' || 'scription, DESCRIPTION ),
        MINIMUM_DATABASE_VERSION = NVL( :minimum_database_version, MINIMUM_DATABASE_VERSION ),
        TAGS = NVL( :tags, TAGS ),
        -- NOTE: Not updating share key as that''s the job for another endpoint
        SHARE_KEY = SHARE_KEY,
        CONTENT_CATEGORY_ID = NVL( :content_category_id, CONTENT_CATEGORY_ID ),
        SETUP_CODE = :setup_code,
        SETUP_CODE_LANGUAGE = NVL( :setup_code_language, SETUP_CODE_LANGUAGE ),
        IS_PUBLISHED = NVL( :is_published, IS_PUBLISHED ),
        IS_FEATURED = NVL( :is_featured, IS_FEATURED ),
        UPDATED_BY = L_CURRENT_USER,
        UPDATED_ON = CURRENT_TIMESTAMP
    WHERE
        ID = L_ID;
    :status_code := 200;
    :forward_location := :tutorial_slug || ''/'';
EXCEPTION
    -- TODO: Log SQLERRM to a logging table
    -- NOTE: Do not output SQLERRM as that can reveal schema information
    WHEN UNAUTHORIZED THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' )' || ';
        :status_code := 401;
    WHEN FORBIDDEN THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Forbidden'' );
        :status_code := 403;
    WHEN NOT_FOUND THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Not Found'' );
        :status_code := 404;
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad Request'' );
        :status_code := 400;
END;');
    -- !SECTION: LIVESQL-830

    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- NOTE: Update the version after the upgrade
BEGIN
    SET_PARAMETER( 'VERSION', 'r28' );
    SET_PARAMETER( 'LAST_UPDATED_ON', TO_CHAR( CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-DD-MM"T"HH24:MI:SS.FF3"Z"' ) );
END;
/
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA to r28 complete
