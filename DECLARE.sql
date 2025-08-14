DECLARE
    TYPE t_table_list IS TABLE OF VARCHAR2(128);

    v_tables       t_table_list := t_table_list();
    v_truncated    t_table_list := t_table_list();
    v_skipped      t_table_list := t_table_list();
    v_stmt         VARCHAR2(4000);
    v_table        VARCHAR2(128);
    v_done         BOOLEAN;
BEGIN
    -- 1. Gather matching tables in dependency-aware order
    -- First: children (those with FKs) before parents
    SELECT table_name
    BULK COLLECT INTO v_tables
    FROM (
        SELECT DISTINCT t.table_name
        FROM user_tables t
        LEFT JOIN user_constraints c
            ON t.table_name = c.table_name
            AND c.constraint_type = 'P'
        LEFT JOIN user_constraints r
            ON c.constraint_name = r.r_constraint_name
            AND r.constraint_type = 'R'
        WHERE t.table_name LIKE 'OLYM_%' -- <-- CHANGE CRITERIA HERE
        ORDER BY CASE WHEN r.table_name IS NOT NULL THEN 1 ELSE 2 END
    );

    -- 2. Try truncating in order
    FOR i IN 1 .. v_tables.COUNT LOOP
        v_table := v_tables(i);
        BEGIN
            v_stmt := 'TRUNCATE TABLE ' || v_table;
            EXECUTE IMMEDIATE v_stmt;
            v_truncated.EXTEND;
            v_truncated(v_truncated.COUNT) := v_table;
        EXCEPTION
            WHEN OTHERS THEN
                -- If truncate fails (likely FK ref), log it
                v_skipped.EXTEND;
                v_skipped(v_skipped.COUNT) := v_table;
        END;
    END LOOP;

    -- 3. Output results
    DBMS_OUTPUT.PUT_LINE('--- Truncated Tables ---');
    FOR i IN 1 .. v_truncated.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_truncated(i));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Skipped Tables ---');
    FOR i IN 1 .. v_skipped.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_skipped(i));
    END LOOP;
END;
/
