# Some notes

## When SYS

```sh
create user [target user] identified by "[Password]";

grant unlimited tablespace to [target user];
```

### Needed for ORDS 

```sh
grant connect, resource to [target user];
```

When logged in as [target user]:

```sh
execute ords.enable_schema;
```

The above is needed for the [target user] to be able to log into the Web UI (SQL Developer Web/Database Actions).

### Other 

I discovered the following in the sample db schemas, and just included them in my new users: 

```sh
GRANT CREATE MATERIALIZED VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE SESSION, CREATE SYNONYM, CREATE TABLE, CREATE TRIGGER, CREATE TYPE, CREATE VIEW to [target user];
```

### For MLE

Some confusion on what actually is needed. Lools like the DB_DEVELOPER_ROLE is enough:

```sh
grant DB_DEVELOPER_ROLE to [target user];
```