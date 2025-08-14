-- NOTE: This script is not intended to be used directly but through
--       install_pdb.sql

PROMPT INFO: Importing Live SQL METADATA ORDS Modules...

SET DEFINE OFF
SET ESCAPE OFF
@@ords_modules/admin.sql
@@ords_modules/auth.sql
@@ords_modules/api.sql
@@ords_modules/app.sql
@@ords_modules/schema_management.sql
SET DEFINE '^'
SET ESCAPE '\'

PROMPT INFO: Live SQL METADATA ORDS Modules Imported
