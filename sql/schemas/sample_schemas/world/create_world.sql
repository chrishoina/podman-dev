set define '^' verify off
prompt ...create_world.sql

Rem  Copyright (c) Oracle Corporation 2014. All Rights Reserved.
Rem
Rem    NAME
Rem      create_world.sql
Rem
Rem    DESCRIPTION
Rem      This script creates WORLD sample schema and sample objects (without data).
Rem
Rem    NOTES
Rem      Assumes the SYS user is connected.
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem    vuvarov     09/25/2014 - Created


SET ECHO OFF
SET VERIFY OFF
SET HEADING OFF
SET FEEDBACK OFF

SET DEFINE '^'

DEFINE pass='^1'
DEFINE tbs='^2'
DEFINE overwrite_schema='^3'

-- Exit setup script on any error
WHENEVER SQLERROR EXIT SQL.SQLCODE

rem =======================================================
rem Accept and verify schema password
rem =======================================================

-- ACCEPT pass PROMPT 'Enter a password for the user WORLD: ' HIDE

BEGIN
   IF '^pass' IS NULL THEN
      RAISE_APPLICATION_ERROR(-20999, 'Error: the WORLD password is mandatory! Please specify a password!');
   END IF;
END;
/

rem =======================================================
rem Accept and verify tablespace name
rem =======================================================
COLUMN property_value NEW_VALUE var_default_tablespace NOPRINT
VARIABLE var_default_tablespace VARCHAR2(255)
SELECT NVL( '^tbs', property_value ) as property_value FROM database_properties WHERE property_name = 'DEFAULT_PERMANENT_TABLESPACE';
DEFINE tbs='^var_default_tablespace'

rem =======================================================
rem cleanup old WORLD schema, if found and requested
rem =======================================================

-- ACCEPT overwrite_schema PROMPT 'Do you want to overwrite the schema, if it already exists? [YES|no]: ' DEFAULT 'YES'

SET SERVEROUTPUT ON;
DECLARE
   v_user_exists   all_users.username%TYPE;
BEGIN
   SELECT MAX(username) INTO v_user_exists
      FROM all_users WHERE username = 'WORLD';
   -- Schema already exists
   IF v_user_exists IS NOT NULL THEN
      -- Overwrite schema if the user chose to do so
      IF UPPER('^overwrite_schema') = 'YES' THEN
         EXECUTE IMMEDIATE 'DROP USER WORLD CASCADE';
         DBMS_OUTPUT.PUT_LINE('Old WORLD schema has been dropped.');
      -- or raise error if the user doesn't want to overwrite it
      ELSE
         RAISE_APPLICATION_ERROR(-20997, 'Abort: the schema already exists and the user chose not to overwrite it.');
      END IF;
   END IF;
END;
/
SET SERVEROUTPUT OFF;

create user WORLD identified by "^pass"
       default tablespace ^tbs quota unlimited on ^tbs
       account lock password expire;

GRANT CREATE TABLE TO WORLD;

ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;

create table WORLD.world_population (
       country        varchar2(60),
       country_code   varchar2(3),
       indicator_name varchar2(60),
       indicator_code varchar2(60),
       "1960"         number,
       "1961"         number,
       "1962"         number,
       "1963"         number,
       "1964"         number,
       "1965"         number,
       "1966"         number,
       "1967"         number,
       "1968"         number,
       "1969"         number,
       "1970"         number,
       "1971"         number,
       "1972"         number,
       "1973"         number,
       "1974"         number,
       "1975"         number,
       "1976"         number,
       "1977"         number,
       "1978"         number,
       "1979"         number,
       "1980"         number,
       "1981"         number,
       "1982"         number,
       "1983"         number,
       "1984"         number,
       "1985"         number,
       "1986"         number,
       "1987"         number,
       "1988"         number,
       "1989"         number,
       "1990"         number,
       "1991"         number,
       "1992"         number,
       "1993"         number,
       "1994"         number,
       "1995"         number,
       "1996"         number,
       "1997"         number,
       "1998"         number,
       "1999"         number,
       "2000"         number,
       "2001"         number,
       "2002"         number,
       "2003"         number,
       "2004"         number,
       "2005"         number,
       "2006"         number,
       "2007"         number,
       "2008"         number,
       "2009"         number,
       "2010"         number,
       "2011"         number,
       "2012"         number,
       "2013"         number,
       "2014"         number,
       "2015"         number,
       "2016"         number,
       "2017"         number,
       "2018"         number,
       "2019"         number );

GRANT READ ON WORLD.WORLD_POPULATION TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT ON COMMIT REFRESH ON WORLD.WORLD_POPULATION TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT QUERY REWRITE ON WORLD.WORLD_POPULATION TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
