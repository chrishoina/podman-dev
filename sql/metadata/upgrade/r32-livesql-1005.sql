PROMPT applying r32-livesql-1005 patch on metadata PDB...

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
    -- SECTION: LIVESQL-1005
    
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
    COMMIT;
END;
/
-- !SECTION: ORDS Endpoints

-- !SECTION: LIVE_SQL

PROMPT r32-livesql-1005 applied...
