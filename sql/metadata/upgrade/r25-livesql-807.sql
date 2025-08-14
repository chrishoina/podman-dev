
PROMPT Upgrading METADATA for LIVESQL-807

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

-- SECTION: LIVESQL-807
-- Add missing Quick SQL backend changes
-- Update the constraint to save the Quick SQL result
ALTER TABLE STATEMENTS DROP CONSTRAINT STATEMENTS_CHK3;

ALTER TABLE STATEMENTS ADD CONSTRAINT STATEMENTS_CHK3 CHECK (
    (
        CODE_LANGUAGE = 'PL_SQL'
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


-- !SECTION: Objects

-- SECTION: ORDS Endpoints
BEGIN
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
    COMMIT;
END;
/
   
-- !SECTION: ORDS Endpoints
-- !SECTION: LIVESQL-807
-- !SECTION: LIVE_SQL

PROMPT Upgrade on METADATA for LIVESQL-807