set define '^' verify off
prompt ...create_scott.sql

Rem  Copyright (c) Oracle Corporation 2016. All Rights Reserved.
Rem
Rem    NAME
Rem      create_scott.sql
Rem
Rem    DESCRIPTION
Rem      This script creates SCOTT sample schema, sample objects, and data.
Rem
Rem    NOTES
Rem      Assumes the SYS user is connected.
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem    sbkenned    01/24/2016 - Created 
Rem    sbkenned    02/15/2016 - fixed issue with creation of emp table


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

-- ACCEPT pass PROMPT 'Enter a password for the user SCOTT: ' HIDE

BEGIN
   IF '^pass' IS NULL THEN
      RAISE_APPLICATION_ERROR(-20999, 'Error: the SCOTT password is mandatory! Please specify a password!');
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
rem cleanup old SCOTT schema, if found and requested
rem =======================================================

-- ACCEPT overwrite_schema PROMPT 'Do you want to overwrite the schema, if it already exists? [YES|no]: ' DEFAULT 'YES'

SET SERVEROUTPUT ON;
DECLARE
   v_user_exists   all_users.username%TYPE;
BEGIN
   SELECT MAX(username) INTO v_user_exists
      FROM all_users WHERE username = 'SCOTT';
   -- Schema already exists
   IF v_user_exists IS NOT NULL THEN
      -- Overwrite schema if the user chose to do so
      IF UPPER('^overwrite_schema') = 'YES' THEN
         EXECUTE IMMEDIATE 'DROP USER SCOTT CASCADE';
         DBMS_OUTPUT.PUT_LINE('Old SCOTT schema has been dropped.');
      -- or raise error if the user doesn't want to overwrite it
      ELSE
         RAISE_APPLICATION_ERROR(-20997, 'Abort: the schema already exists and the user chose not to overwrite it.');
      END IF;
   END IF;
END;
/
SET SERVEROUTPUT OFF;

create user SCOTT identified by "^pass"
       default tablespace ^tbs quota unlimited on ^tbs
       account lock password expire;

GRANT CREATE TABLE TO SCOTT;

ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;

create table SCOTT.dept(  
  deptno     number(2,0),  
  dname      varchar2(14),  
  loc        varchar2(13),  
  constraint pk_dept primary key (deptno)  
);

create table SCOTT.emp(  
  empno    number(4,0),  
  ename    varchar2(10),  
  job      varchar2(9),  
  mgr      number(4,0),  
  hiredate date,  
  sal      number(7,2),  
  comm     number(7,2),  
  deptno   number(2,0),  
  constraint pk_emp primary key (empno),  
  constraint fk_deptno foreign key (deptno) references scott.dept (deptno)  
);

insert into SCOTT.DEPT (DEPTNO, DNAME, LOC)
values(10, 'ACCOUNTING', 'NEW YORK');

insert into SCOTT.dept  
values(20, 'RESEARCH', 'DALLAS');

insert into SCOTT.dept  
values(30, 'SALES', 'CHICAGO');

insert into SCOTT.dept  
values(40, 'OPERATIONS', 'BOSTON');

insert into SCOTT.emp  
values(  
 7839, 'KING', 'PRESIDENT', null,  
 to_date('17-11-1981','dd-mm-yyyy'),  
 5000, null, 10  
);

insert into SCOTT.emp  
values(  
 7698, 'BLAKE', 'MANAGER', 7839,  
 to_date('1-5-1981','dd-mm-yyyy'),  
 2850, null, 30  
);

insert into SCOTT.emp  
values(  
 7782, 'CLARK', 'MANAGER', 7839,  
 to_date('9-6-1981','dd-mm-yyyy'),  
 2450, null, 10  
);

insert into SCOTT.emp  
values(  
 7566, 'JONES', 'MANAGER', 7839,  
 to_date('2-4-1981','dd-mm-yyyy'),  
 2975, null, 20  
);

insert into SCOTT.emp  
values(  
 7788, 'SCOTT', 'ANALYST', 7566,  
 to_date('13-JUL-87','dd-mm-rr') - 85,  
 3000, null, 20  
);

insert into SCOTT.emp  
values(  
 7902, 'FORD', 'ANALYST', 7566,  
 to_date('3-12-1981','dd-mm-yyyy'),  
 3000, null, 20  
);

insert into SCOTT.emp  
values(  
 7369, 'SMITH', 'CLERK', 7902,  
 to_date('17-12-1980','dd-mm-yyyy'),  
 800, null, 20  
);

insert into SCOTT.emp  
values(  
 7499, 'ALLEN', 'SALESMAN', 7698,  
 to_date('20-2-1981','dd-mm-yyyy'),  
 1600, 300, 30  
);

insert into SCOTT.emp  
values(  
 7521, 'WARD', 'SALESMAN', 7698,  
 to_date('22-2-1981','dd-mm-yyyy'),  
 1250, 500, 30  
);

insert into SCOTT.emp  
values(  
 7654, 'MARTIN', 'SALESMAN', 7698,  
 to_date('28-9-1981','dd-mm-yyyy'),  
 1250, 1400, 30  
);

insert into SCOTT.emp  
values(  
 7844, 'TURNER', 'SALESMAN', 7698,  
 to_date('8-9-1981','dd-mm-yyyy'),  
 1500, 0, 30  
);

insert into SCOTT.emp  
values(  
 7876, 'ADAMS', 'CLERK', 7788,  
 to_date('13-JUL-87', 'dd-mm-rr') - 51,  
 1100, null, 20  
);

insert into SCOTT.emp  
values(  
 7900, 'JAMES', 'CLERK', 7698,  
 to_date('3-12-1981','dd-mm-yyyy'),  
 950, null, 30  
);

insert into SCOTT.emp  
values(  
 7934, 'MILLER', 'CLERK', 7782,  
 to_date('23-1-1982','dd-mm-yyyy'),  
 1300, null, 10  
);

commit;

GRANT READ ON SCOTT.EMP TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON SCOTT.DEPT TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
