PROMPT Upgrading METADATA to r35...

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

-- SECTION: LIVESQL-928 | Track Queries Executed by Read-Only Schemas in SQL History
INSERT INTO ROLES (
    ID,
    NAME,
    SEQUENCE
) VALUES (
    0,
    'INTERNAL',
    0
);

INSERT INTO USERS (
    EMAIL,
    DISPLAY_NAME,
    ROLE_ID
) VALUES (
    'ANONYMOUS',
    'ANONYMOUS',
    0
);
-- !SECTION: LIVESQL-928

-- !SECTION: Objects

-- SECTION: ORDS Endpoints
BEGIN
    -- SECTION: LIVESQL-840 | Add Support for MLE/JavaScript Code Execution in Live SQL
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

    -- SECTION: LIVESQL-928 | Track Queries Executed by Read-Only Schemas in SQL History
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

    L_IS_SIGNED BOOLEAN;

    L_READ_ONLY_SCHEMA_ID NUMBER;
BEGIN
    L_IS_SIGNED := L_CURRENT_USER IS NOT NULL;

   IF NOT L_IS_SIGNED THEN
        L_CURRENT_USER := ''ANONYMOUS'';
        L_READ_ONLY_SCHEMA_ID := USER_SCHEMAS.GET_READ_ONLY_SCHEMA( :db_version ).ID;
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
        CASE 
            WHEN L_IS_SIGNED THEN user_schemas.GET_USER_SCHEMA( L_CURRENT_USER, :db_version  ).id
            ELSE L_READ_ONLY_SCHEMA_ID
        END
    ) RETURNING ID INTO L_STATEMENT_ID;
    :status_code := 201;
    :forward_location := L_STATEMENT_ID;
EXCEPTION
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad request'' );
        :status_code := ' || '400;
END;');
    -- !SECTION: LIVESQL-928

    -- SECTION: LIVESQL-1005 | Add missing PUT endpoint for tutorials steps
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'com.oracle.livesql.api',
        p_pattern        => 'tutorials/:tutorial_slug/steps/',
        p_method         => 'PUT',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => NULL,
        p_source         => 
'DECLARE
    L_CURRENT_USER VARCHAR2(320 BYTE) := UPPER( :current_user );

    STEPS_TO_REORDER JSON_ARRAY_T;
    STEPS_OBJECT JSON_OBJECT_T;
    FIRST_BODY_CHARACTER CLOB;
    BODY_HOLDER CLOB := :body_text;
    STEPS_ID NUMBER;
    STEPS_SEQUENCE NUMBER;

    UNAUTHORIZED EXCEPTION;
    BAD_REQUEST EXCEPTION;
BEGIN
    IF NOT AUTHORIZATION.HAS_ROLE( L_CURRENT_USER, ''BASIC'' ) THEN
       RAISE UNAUTHORIZED;
    END IF;

    -- This takes the first character in the body: If it''s [, then it''s an array and it''s meant to be
    -- for reordering, otherwise it would be for saving the script results
    FIRST_BODY_CHARACTER := DBMS_LOB.SUBSTR(BODY_HOLDER, 1, 1);

    IF FIRST_BODY_CHARACTER = TO_CLOB(''['') THEN
        STEPS_TO_REORDER := JSON_ARRAY_T.PARSE(BODY_HOLDER);
        FOR i IN 0..STEPS_TO_REORDER.GET_SIZE - 1 LOOP
            STEPS_OBJECT := TREAT(STEPS_TO_REORDER.get(i) AS JSON_OBJECT_T);
            STEPS_SEQUENCE := STEPS_OBJECT.GET_NUMBER(''sequence'');
            STEPS_ID := ST' || 'EPS_OBJECT.GET_NUMBER(''id'');
            UPDATE 
                TUTORIALS_STEPS 
            SET
                TUTORIALS_STEPS.SEQUENCE = NVL(STEPS_SEQUENCE, TUTORIALS_STEPS.SEQUENCE)
            WHERE
                TUTORIALS_STEPS.ID = STEPS_ID;
        END LOOP;
    ELSE
        RAISE BAD_REQUEST;
    END IF;
    :status_code := 201;
EXCEPTION
    -- TODO: Log SQLERRM to a logging table
    -- NOTE: Do not surface SQLERRM as that may leak schema details
    WHEN UNAUTHORIZED THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Unauthorized'' );
        :status_code := 401;
    WHEN OTHERS THEN
        :errorReason := UTILITIES.STRING_TO_ERROR_REASON( ''Bad Request'' );
        :status_code := 400;
END;');
    -- !SECTION: LIVESQL-1005

    -- SECTION: LIVESQL-1020 | Identify and fix issues with sample_schemas/ endpoint
    DECLARE
        SAMPLE_SCHEMAS_TEMPLATE_ID NUMBER;
        SAMPLE_SCHEMAS_URI VARCHAR2(600) := 'sample_schemas/';
    BEGIN
        SELECT
            ID
        INTO
            SAMPLE_SCHEMAS_TEMPLATE_ID
        FROM
            USER_ORDS_TEMPLATES
        WHERE
            URI_TEMPLATE = SAMPLE_SCHEMAS_URI;
        
        ORDS_SERVICES.DELETE_TEMPLATE(p_id => SAMPLE_SCHEMAS_TEMPLATE_ID);
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE( 'The template uri ''' || SAMPLE_SCHEMAS_URI || ''' does not exists');
    END;
    -- !SECTION: LIVESQL-1020

    -- SECTION: LIVESQL-1072 | Create upgrade file to fix /worksheets/batch endpoint in stage and production
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

-- NOTE: Update the version after the upgrade
BEGIN
    SET_PARAMETER( 'VERSION', 'r35' );
    SET_PARAMETER( 'LAST_UPDATED_ON', TO_CHAR( CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-DD-MM"T"HH24:MI:SS.FF3"Z"' ) );
END;
/
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA to r35 complete
