PROMPT applying r31-livesql-949 patch on metadata PDB...

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

-- !SECTION: LIVE_SQL

PROMPT r31-livesql-949 applied...
