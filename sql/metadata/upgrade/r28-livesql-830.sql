-- This is the patch file structure

PROMPT Applying LIVESQL-830 patch...

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
-- NOTE: No upgrades needed
-- !SECTION: ADMIN

-- SECTION: LIVE_SQL
SET FEEDBACK OFF
CONNECT "LIVE_SQL"/"^PDB_ADMIN_PASSWORD"
SET FEEDBACK ON

-- SECTION: ORDS Endpoints
BEGIN
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

-- !SECTION: LIVE_SQL

PROMPT LIVESQL-830 patch applied...
