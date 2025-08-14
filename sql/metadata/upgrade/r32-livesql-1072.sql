PROMPT applying LIVESQL-1072 patch on metadata PDB...

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

-- SECTION: ORDS Endpoints
BEGIN
    -- SECTION: LIVESQL-1072
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

    INSERT INTO WORKSHEETS (
        NAME,
        CONTENT,
        CODE_LANGUAGE,
        CREATED_BY
    )
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
                CONTENT,
                CODE_LANGUAGE
            FROM
                JSON_TABLE(
                    :body,
                    ''$.worksheet_list[*]'' COLUMNS (
                        ARRAY_INDEX FOR ORDINALITY,
                        NAME VARCHAR PATH ''$.name'',
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
                PAYLOAD_WORKSHEETS.CONTENT,
                PAYLOAD_WORKSHEETS.CODE_LANGUAGE
        )
    SELECT
        PAYLOAD_NAME || CASE WHEN NAME_INDEX > 0 THEN ''('' || NAME_INDEX || '')'' END AS NEW_NAME,
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
    -- !SECTION: LIVESQL-1072
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- !SECTION: LIVE_SQL

PROMPT LIVESQL-1072 applied...
