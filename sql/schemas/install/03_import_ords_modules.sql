-- NOTE: This script is not intended to be used directly but through
--       install_pdb.sql

PROMPT INFO: Importing Live SQL SCHEMAS ORDS Modules...

SET DEFINE OFF
@@ords_modules/schema_management.sql
SET DEFINE '^'

PROMPT INFO: Live SQL SCHEMAS ORDS Modules Imported