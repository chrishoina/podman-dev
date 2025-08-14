PROMPT applying r32-livesql-928 patch on metadata PDB...

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
-- SECTION: LIVESQL-928
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
-- SECTION: LIVESQL-928
    
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
/
-- !SECTION: ORDS Endpoints

PROMPT r32-livesql-928 patch applied...
