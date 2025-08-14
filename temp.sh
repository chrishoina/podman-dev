function _test_database(){
    printf "%s%s\n" "INFO : " "Testing your connection variables."
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3) > /dev/null
    case "${CONN_TYPE}" in 
        "simple")
            sql /nolog << _SQL_SCRIPT &>> /dev/null
            whenever sqlerror exit failure
            whenever oserror exit failure
            conn sys/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
            select 'success' from dual;
            exit
_SQL_SCRIPT
            RESULT=$?
            if [ ${RESULT} -eq 0 ] ; then
            printf "%s%s\n" "INFO : " "Database connection established."
            else
                _connection_error
            fi
        ;;
        "string")
            sql /nolog << _SQL_SCRIPT &>> /dev/null
            whenever sqlerror exit failure
            whenever oserror exit failure
            conn sys/${ORACLE_PWD}@${CONN_STRING} as sysdba
            select 'success' from dual;
            exit
_SQL_SCRIPT
            RESULT=$?
            if [ ${RESULT} -eq 0 ] ; then
                printf "%s%s\n" "INFO : " "Database connection established."
            else
                _connection_error
            fi
        ;;
        "declare")
            _connection_error
        ;;
        *)
            _unknown_error
        ;;
    esac
}

