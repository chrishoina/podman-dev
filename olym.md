# Creating OLYM Tables

## Task 1

1. Create a "olym_tables.sql" file in my current working directory
2. Connect as the SQL_FREESQL_01 user
3. Copy the DDL from the OLYM schema's OLYM tables to the "olym_tables.sql" file. 

> NOTE: The table names should not include the OLYM schema in them. 
> NOTE: The SQL_FREESQL_01 user is not a DBA, or Pluggable DBA. So, DBA and PLSQL pacakges that require the DBA role are not usable. You may have to manually inspect the tables individually and recreate the DDL by introspecting the table characteristics.

4. Open this "olym_tables.sql" file when you have completed all tasks. 

## Task 2

5. Connect as the SQL_FREESQL_01 user and execute the olym_tables.sql script in the SQL_FREESQL_01 schema.
6. Execute "INSERT INTO OLYM_${Table} SELECT * FROM OLYM.OLYM_${Table};" statements where ${Table} is equal to the like table names in each of the related schemas. 

> NOTE: You are selecting data from the OLYM schema tables and copying them into the like SQL_FREESQL_01 tables.

## Task 3

7. Connect as the SQL_FREESQL_01 user.
8. Produce a visual model of the OLYM tables found in the SQL_FREESQL_01 schema.

## Task 4

9. Connect as the SQL_FREESQL_01 user
10. What are the unique disciplines, events, and nations that exist in the OLYM tables?