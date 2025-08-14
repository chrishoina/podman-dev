PROMPT Upgrading METADATA to beta2...

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

-- SECTION: LIVESQL-795
-- NOTE: Trigger enablement for 23 since triggers were not created by the install script due to an error

@@../../utilities/create_before_update_trigger.sql ROLES
@@../../utilities/create_before_update_trigger.sql USERS
@@../../utilities/create_before_update_trigger.sql DATABASES
@@../../utilities/create_before_update_trigger.sql SCHEMAS
@@../../utilities/create_before_update_trigger.sql CONTENT_CATEGORIES
@@../../utilities/create_before_update_trigger.sql TUTORIALS
@@../../utilities/create_before_update_trigger.sql TUTORIALS_STEPS
@@../../utilities/create_before_update_trigger.sql SCRIPTS
@@../../utilities/create_before_update_trigger.sql SCRIPTS_STATEMENTS
@@../../utilities/create_before_update_trigger.sql WORKSHEETS
-- !SECTION: LIVESQL-795

-- SECTION: ORDS Endpoints

BEGIN
    -- SECTION: LIVESQL-458
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'sample_schemas/',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => NULL
    );
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'sample_schemas/',
        p_method         => 'GET',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'DECLARE
    L_BASE_URL DATABASES.BASE_URL%TYPE;
    L_ADMIN_SCHEMA_ALIAS DATABASES.ADMIN_SCHEMA_ALIAS%TYPE;
    L_ADMIN_CLIENT_ID DATABASES.ADMIN_CLIENT_ID%TYPE;
    L_ADMIN_CLIENT_SECRET DATABASES.ADMIN_CLIENT_SECRET%TYPE;
    L_DATABASE_VERSION DATABASES.ID%TYPE := :db_version;
    L_RESPONSE CLOB;

    REQUEST_FAILED EXCEPTION;
BEGIN
    SELECT
        BASE_URL,
        ADMIN_SCHEMA_ALIAS,
        UTILITIES.HEX_DECRYPT( ADMIN_CLIENT_ID ),
        UTILITIES.HEX_DECRYPT( ADMIN_CLIENT_SECRET )
    INTO
        L_BASE_URL,
        L_ADMIN_SCHEMA_ALIAS,
        L_ADMIN_CLIENT_ID,
        L_ADMIN_CLIENT_SECRET
    FROM
        DATABASES
    WHERE
        VERSION = L_DATABASE_VERSION;
    
    APEX_WEB_SERVICE.OAUTH_AUTHENTICATE(
        P_TOKEN_URL => L_BASE_URL || L_ADMIN_SCHEMA_ALIAS || ''/oauth/token'',
        P_CLIENT_ID => L_ADMIN_CLIENT_ID,
        P_CLIENT_SECRET => L_ADMIN_CLIENT_SECRET,
        P_FLOW_TYPE => APEX_WEB_SERVICE.OAUTH_CLIENT_CRED
    );

    IF APEX_WEB_SERVICE.G_STA' || 'TUS_CODE != 200 THEN
        RAISE REQUEST_FAILED;
    END IF;

    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := ''Authorization'';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''Bearer '' || APEX_WEB_SERVICE.OAUTH_GET_LAST_TOKEN();

    L_RESPONSE := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        P_URL => L_BASE_URL || L_ADMIN_SCHEMA_ALIAS || ''/api/sample_schemas/'',
        P_HTTP_METHOD => ''GET''
    );

    IF APEX_WEB_SERVICE.G_STATUS_CODE != 200 AND APEX_WEB_SERVICE.G_STATUS_CODE != 201 THEN
        RAISE REQUEST_FAILED;
    END IF;

    OWA_UTIL.MIME_HEADER( ''application/json'', TRUE );
    HTP.P( L_RESPONSE );
    :status_code := 200;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad Request'' );
        :status_code := 400;
END;'
    );
    -- !SECTION: LIVESQL-458
    -- SECTION: LIVESQL-801
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'worksheets/',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'DECLARE
    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    L_WORKSHEET_ID VARCHAR2(36);
BEGIN
    IF NOT AUTHORIZATION.HAS_ROLE( L_CURRENT_USER, ''BASIC'' ) THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' );
        :status_code := 401;
        RETURN;
    END IF;
    INSERT INTO WORKSHEETS(
        NAME,
        CONTENT,
        CODE_LANGUAGE,
        CREATED_BY,
        LAST_OPENED_ON
    ) VALUES (
        :name,
        :content,
        :code_language,
        L_CURRENT_USER,
        CURRENT_TIMESTAMP
    ) RETURNING ID INTO L_WORKSHEET_ID;
    :status_code := 201;
    :forward_location := L_WORKSHEET_ID;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad request'' );
        :status_code := 400;
END;');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'worksheets/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
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
    CODE_LANGUAGE,
    UPDATED_ON,
    CREATED_ON,
    CREATED_BY,
    LAST_OPENED_ON
FROM
    WORKSHEETS
WHERE
    (
        CREATED_BY = UPPER( :current_user )
        OR ''ADMINISTRATOR'' IN ( SELECT NAME FROM USER_ROLES )
    )
    AND (
        :search_term IS NULL OR (UPPER(NAME) LIKE ''%'' || UPPER(:search_term) || ''%'')
    )
ORDER BY UPDATED_ON DESC'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'worksheets/batch/',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'DECLARE
    L_WORKSHEETS_LIST_OBJECT JSON_OBJECT_T;
    L_WORKSHEETS_LIST JSON_ARRAY_T;
    L_WORKSHEET JSON_OBJECT_T;
    L_WORKSHEET_NAME VARCHAR2(128);
    L_WORKSHEET_CONTENT CLOB;
    L_WORKSHEET_CODE_LANGUAGE VARCHAR2(128);
    L_WORKSHEETS_COUNT NUMBER;

    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    UNAUTHORIZED EXCEPTION;
BEGIN
    IF NOT AUTHORIZATION.HAS_ROLE( L_CURRENT_USER, ''BASIC'' ) THEN
        RAISE UNAUTHORIZED;
    END IF;

    INSERT INTO WORKSHEETS (NAME, CONTENT, CREATED_BY)
    INSERT INTO WORKSHEETS (NAME, CONTENT, CODE_LANGUAGE, CREATED_BY)
    WITH
        USER_WORKSHEETS AS (
            SELECT
                DISTINCT NAME
            FROM
                WORKSHEETS
            WHERE
                CREATED_BY = L_CURRENT_USER
        ),
        PAYLOAD_WORKSHEETS AS (
            SELECT
                ARRAY_INDEX - 1 AS ARRAY_INDEX,
                NAME,
                CONTENT
                CONTENT,
                CODE_LANGUAGE
            FROM
                JSON_TABLE(
                    :body,
                    ''$.worksheet_list[*]'' COLUMNS (
                        ARRAY_INDEX FOR ORDINAL' || 'ITY,
                        NAME VARCHAR PATH ''$.name'',
                        CONTENT PATH ''$.content'' --CLOB doesn''t exist in JSON_TABLE
                        CONTENT PATH ''$.content'', --CLOB doesn''t exist in JSON_TABLE
                        CODE_LANGUAGE PATH ''$.code_language''  
                    )
                )
        ),
        PAYLOAD_INDEXES AS (
            SELECT
                PAYLOAD_WORKSHEETS.ARRAY_INDEX AS PAYLOAD_ARRAY_INDEX,
                PAYLOAD_WORKSHEETS.NAME AS PAYLOAD_NAME,
                PAYLOAD_WORKSHEETS.CONTENT AS PAYLOAD_CONTENT,
                PAYLOAD_WORKSHEETS.CODE_LANGUAGE AS PAYLOAD_CODE_LANGUAGE,
                TO_NUMBER( NVL( REGEXP_REPLACE( REGEXP_SUBSTR( NVL( MAX( USER_WORKSHEETS.NAME ), ''(-1)'' ), ''\([-0-9]+\)$'' ), ''[()]'', '''' ), 0 ) ) + 1 AS NAME_INDEX
            FROM
                PAYLOAD_WORKSHEETS LEFT JOIN USER_WORKSHEETS ON
                    INSTR(USER_WORKSHEETS.NAME, PAYLOAD_WORKSHEETS.NAME) = 1
            GROUP BY
                PAYLOAD_WORKSHEETS.ARRAY_INDEX,
                PAYLOAD_WORKSHEETS.NAME,
                PAYLOAD_WORKSHEETS.CONTENT
        )
    SELECT
        PAYLOAD_NAME || CASE WHEN NAME_INDEX > 0 THEN ''('' || NAME_INDEX ||' || ' '')'' END AS NEW_NAME,
        PAYLOAD_CONTENT,
        PAYLOAD_CODE_LANGUAGE,
        L_CURRENT_USER
    FROM
        PAYLOAD_INDEXES;

    :status_code := 201;
EXCEPTION
    WHEN UNAUTHORIZED THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' );
        :status_code := 401;
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad Request'' );
        :status_code := 400;
END;'
    );
    -- !SECTION: LIVESQL-801
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints
-- SECTION: LIVESQL-796
-- NOTE: Update the version after the upgrade
BEGIN
    SET_PARAMETER( 'VERSION', 'beta2' );
    SET_PARAMETER( 'LAUNCHED_ON', '2024-11-18T20:00:00.000Z' );
    SET_PARAMETER( 'LAST_UPDATED_ON', TO_CHAR( CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-DD-MM"T"HH24:MI:SS.FF3"Z"' ) );
END;
/
-- !SECTION: LIVESQL-796
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA to beta2 complete
