#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#        entrypoint.sh
#
#    DESCRIPTION
#        Script to configured and israt APEX and ORDS on a container
#    NOTES

#
#    CHANGE LOG
#        MODIFIED    VERSION    (MM/DD/YY)
#        admuro      1.0.0       01/25/20 - Script Creation

# Variables

ORDS_HOME=/opt/oracle/ords
APEX_HOME=/opt/oracle/apex
APEXI=/opt/oracle/apex/images
INSTALL_LOGS=/tmp/install_logs
ORDS_ENTRYPOINT_DIR=/ords-entrypoint.d
ORDS_CONF_DIR="/etc/ords/config"

# Function definitions
function _dbconnect_var(){
    if [ -n "${ORACLE_PWD}" ]; then 
        if [ -n "${DBHOST}" ] && [ -n "${DBPORT}" ] && [ -n "${DBSERVICENAME}" ]; then
            echo "conn_type_simple"
        elif [ -n "${CONN_STRING}" ]; then
            echo "conn_type_string"
        else
            echo "conn_type_declare"
        fi
    else
        echo "conn_type_declare"
    fi
}

# Test DB connection
function _test_database() {
    local MAX_RETRIES=30
    local RETRY_DELAY=10
    local ATTEMPT=1
    local RESULT=1

    echo "Testing database connection..."

    while [ $ATTEMPT -le $MAX_RETRIES ]; do
        echo "Attempt $ATTEMPT: Connecting to ${DBHOST}:${DBPORT}/${DBSERVICENAME}..."

        RESULT=$(echo "
            SET HEADING OFF FEEDBACK OFF VERIFY OFF ECHO OFF
            SELECT open_mode FROM v\$pdbs WHERE name = UPPER('${DBSERVICENAME}');
            EXIT;" \
        | sql -s system/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} 2>/dev/null \
        | grep -c "READ WRITE")

        if [ "$RESULT" -eq 1 ]; then
            echo "Database connection successful."
            return 0
        else
            echo "Database not ready (attempt $ATTEMPT of $MAX_RETRIES). Retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
            ((ATTEMPT++))
        fi
    done

    echo "Failed to connect to database after $MAX_RETRIES attempts."
    return 1
}

function _apex_ver(){
    # Validate if apex is installed and the version
    # Get APEX version from APEX files
    if [ -f ${APEX_HOME}/core/scripts/set_appun.sql ]; then 
        APEX_VER=$(grep  APEX_[0-9][0-9]0[1-5][0-9][0-9] ${APEX_HOME}/core/scripts/set_appun.sql | awk '{print $4}' | cut -d"_" -f2|cut -d"'" -f1| awk -F '' '{print $1$2"."$4"."$6}')
        export APEX_YEAR=$(echo ${APEX_VER} | cut -d"." -f1)
        APEX_QTR=$(echo ${APEX_VER} | cut -d"." -f2)
        APEX_PATCH=$(echo ${APEX_VER}| cut -d"." -f3)
        printf "%s%s\n" "INFO : " "The container found Oracle APEX version ${APEX_VER} in the mounted volume."
    else
        printf "\a%s%s\n" "ERROR: " "The Oracle APEX installation files are missing."
        exit 1
    fi
    # Get APEX version from DB
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3) > /dev/null
    case "${CONN_TYPE}" in
        "simple")
            sql -s /nolog << _SQL_SCRIPT > /tmp/apex_version 2> /dev/null
            conn sys/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            SELECT VERSION FROM DBA_REGISTRY WHERE COMP_ID='APEX';
_SQL_SCRIPT
        ;;
        "string") 
            sql -s /nolog << _SQL_SCRIPT > /tmp/apex_version 2> /dev/null
            conn sys/${ORACLE_PWD}@${CONN_STRING} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            SELECT VERSION FROM DBA_REGISTRY WHERE COMP_ID='APEX';
_SQL_SCRIPT
        ;;
        "declare")
            _connection_error
        ;;
        *)
            _unknown_error
        ;;
    esac
    # Get DB installed version
    export APEX_DBVER=$(cat /tmp/apex_version|grep -v DEBUG|grep [0-9][0-9].[1-5].[0-9] |sed '/^$/d'|sed 's/ //g')
    APEXDB_YEAR=$(echo ${APEX_DBVER} | cut -d"." -f1)
    APEXDB_QTR=$(echo ${APEX_DBVER} | cut -d"." -f2)
    APEXDB_PATCH=$(echo ${APEX_DBVER}| cut -d"." -f3)
    grep "SQL Error" /tmp/apex_version > /dev/null
    SQL_ERROR=$?
    if [ ${SQL_ERROR} -eq 0 ] ; then
        printf "\a%s%s\n" "ERROR: " "Please validate the database status."
        grep "SQL Error" /tmp/apex_version 
        exit 1
    fi
    if [ -n "${APEX_DBVER}" ]; then
        # Validate if an upgrade needed
        if [ "${APEX_DBVER}" = "${APEX_VER}" ]; then
            printf "%s%s\n" "INFO : " "The Oracle APEX ${APEX_VER} is already installed in your database."
        elif [ ${APEXDB_YEAR} -gt ${APEX_YEAR} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle APEX version (${APEX_DBVER}) is already installed in your database. The APEX version mounted on the container is ${APEX_VER}. Stopping the container."
            exit 1
        elif [ ${APEXDB_YEAR} -eq ${APEX_YEAR} ] && [ ${APEXDB_QTR} -gt ${APEX_QTR} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle APEX version (${APEX_DBVER}) is already installed in your database. The APEX version mounted on the container is ${APEX_VER}. Stopping the container." 
            exit 1
        elif [ ${APEXDB_YEAR} -eq ${APEX_YEAR} ] && [ ${APEXDB_QTR} -eq ${APEX_QTR} ] && [ ${APEXDB_PATCH} -gt ${APEX_PATCH} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle APEX version (${APEX_DBVER}) is already installed in your database. The APEX version mounted on the container is ${APEX_VER}. Stopping the container."
            exit 1
        else
            printf "%s%s\n" "INFO : " "The Oracle APEX (${APEX_DBVER}) is installed on your database, and will be upgraded to ${APEX_VER}."
            _install_apex
        fi
    else
        _install_apex
    fi
}

function _install_apex(){
    # Validate if DB is a PDB or CDB
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3 ) > /dev/null
    case "${CONN_TYPE}" in
        "simple")
            sql -s /nolog << _SQL_SCRIPT > /tmp/db_type 2> /dev/null
            conn sys/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            SELECT CASE sys_context('USERENV', 'CON_ID') WHEN '1' THEN 'CDB' ELSE 'PDB' END as TYPE FROM DUAL;
_SQL_SCRIPT
        ;;
        "string") 
            sql -s /nolog << _SQL_SCRIPT > /tmp/db_type 2> /dev/null
            conn sys/${ORACLE_PWD}@${CONN_STRING} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            SELECT CASE sys_context('USERENV', 'CON_ID') WHEN '1' THEN 'CDB' ELSE 'PDB' END as TYPE FROM DUAL;
_SQL_SCRIPT
        ;;
        "declare")
            _connection_error
        ;;
        *)
            _unknown_error
        ;;
    esac
    grep "SQL Error" /tmp/db_type > /dev/null
    SQL_ERROR=$?
    if [ ${SQL_ERROR} -eq 0 ] ; then
        printf "\a%s%s\n" "ERROR: " "Please validate the database status."
        grep "SQL Error" /tmp/apex_version 
        exit 1
    fi 
    grep "CDB" /tmp/db_type > /dev/null
    CDB_INS=$?
    if [ ${CDB_INS} -eq 0 ] ; then
        printf "\a%s%s\n" "ERROR: " "Oracle APEX cannot be installed on the CDB remotely, please install Oracle APEX directly on your database."
        exit 1
    fi 
    if [ -f $APEX_HOME/apxsilentins.sql ]; then
        printf "%s%s\n" "INFO : " "Installing Oracle APEX on your DB, please be patient."
        cd $APEX_HOME
        touch ${INSTALL_LOGS}/apex_install.log
        case "${CONN_TYPE}" in
            "simple")
                sql -s /nolog << _SQL_SCRIPT > ${INSTALL_LOGS}/apex_install.log 2> /dev/null
                conn sys/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
                @apxsilentins.sql SYSAUX SYSAUX TEMP /i/ oracle oracle oracle oracle
                ALTER PROFILE default limit password_life_time UNLIMITED;
                ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
                ALTER USER APEX_PUBLIC_USER IDENTIFIED BY oracle;
_SQL_SCRIPT
                RESULT=$?
                if [ ${RESULT} -eq 0 ] ; then
                    printf "%s%s\n" "INFO : " "The Oracle APEX has been installed. You can create an APEX Workspace in Database Actions APEX Workspaces section."
                else
                    printf "\a%s%s\n" "ERROR: " "The Oracle APEX installation has failed"
                    tail -20 ${INSTALL_LOGS}/apex_install.log
                    exit 1
                fi
            ;;
            "string") 
                sql -s /nolog << _SQL_SCRIPT > ${INSTALL_LOGS}/apex_install.log 2> /dev/null
                conn sys/${ORACLE_PWD}@${CONN_STRING} as sysdba
                @apxsilentins.sql SYSAUX SYSAUX TEMP /i/ oracle oracle oracle oracle
                ALTER PROFILE default limit password_life_time UNLIMITED;
                ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
                ALTER USER APEX_PUBLIC_USER IDENTIFIED BY oracle;
_SQL_SCRIPT
                RESULT=$?
                if [ ${RESULT} -eq 0 ] ; then
                    printf "%s%s\n" "INFO : " "The Oracle APEX has been installed. You can create an APEX Workspace in Database Actions APEX Workspaces section."
                else
                    printf "\a%s%s\n" "ERROR: " "The Oracle APEX installation has failed"
                    exit 1
                fi
            ;;
            "declare")
                _connection_error
            ;;
            *)
                _unknown_error
            ;;
        esac
    else
        printf "\a%s%s\n" "ERROR: " "The Oracle APEX installation script is missing."
        exit 1
    fi
}

function _ords_repair(){
    cd ${ORDS_CONF_DIR}
    # ORDS repair
    printf "%s%s\n" "INFO : " "Set plsql.gateway.mode proxied after Oracle APEX was installed."
    ${ORDS_HOME}/bin/ords config set  plsql.gateway.mode proxied  >/dev/null 2>&1
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3) > /dev/null
    case "${CONN_TYPE}" in
        "simple")
            ${ORDS_HOME}/bin/ords install repair --admin-user sys --password-stdin --db-hostname ${DBHOST} \
            --db-port ${DBPORT} --db-servicename ${DBSERVICENAME}  << _SECRET >/dev/null 2>&1
${ORACLE_PWD}
_SECRET
        ;;
        "string")
            ${ORDS_HOME}/bin/ords  install --admin-user sys --db-custom-url "jdbc:oracle:thin:@${CONN_STRING}" \
            --password-stdin  << _SECRET >/dev/null 2>&1
${ORACLE_PWD}
_SECRET
        ;;
        *)
            _unknown_error
        ;;
    esac
}

function _ords_ver(){
    # Get ORDS version
    ORDS_YEAR=$(echo ${ORDS_VER} | cut -d"." -f1)
    ORDS_QTR=$(echo ${ORDS_VER} | cut -d"." -f2)
    ORDS_PATCH=$(echo ${ORDS_VER}| cut -d"." -f3)
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3) > /dev/null
    # Grant inherit privileges on user sys to ORDS_METADATA;
    case "${CONN_TYPE}" in
        "simple")
            sql -s /nolog << _SQL_SCRIPT > /tmp/ords_db_version 2> /dev/null
            conn sys/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            select version from ORDS_VERSION;
_SQL_SCRIPT
        ;;
        "string") 
            sql -s /nolog << _SQL_SCRIPT > /tmp/ords_db_version 2> /dev/null
            conn sys/${ORACLE_PWD}@${CONN_STRING} as sysdba
            SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
            SET PAGESIZE 0
            select version from ORDS_VERSION;
_SQL_SCRIPT
        ;;
        "declare")
            _connection_error
        ;;
        *)
            _unknown_error
        ;;
    esac
    grep "ORA-00942" /tmp/ords_db_version > /dev/null
    IS_INSTALL=$?
    if [ ${IS_INSTALL} -eq 0 ]; then
        printf "%s%s\n" "INFO : " "The Oracle REST Data Services are not installed on your database."
        _install_ords
    else
        grep "SQL Error" /tmp/ords_db_version > /dev/null
        SQL_ERROR=$?
        if [ ${SQL_ERROR} -eq 0 ]; then
            printf "\a%s%s\n" "ERROR: " "Please validate the database status."
            grep "SQL Error" /tmp/ords_db_version 
            exit 1
        fi
        ORDS_DBVER=$(cat /tmp/ords_db_version|grep -v DEBUG| grep [0-9][0-9].[1-5].[0-9]|tr -d ' ')
        ORDS_DBVER_SHORT=$(cat /tmp/ords_db_version|grep -v DEBUG| grep [0-9][0-9].[1-5].[0-9] | awk -F'.' '{print $1"."$2"."$3}')
        ORDSDB_YEAR=$(echo ${ORDS_DBVER_SHORT} | cut -d"." -f1)
        ORDSDB_QTR=$(echo ${ORDS_DBVER_SHORT} | cut -d"." -f2)
        ORDSDB_PATCH=$(echo ${ORDS_DBVER_SHORT} | cut -d"." -f3)
        if [ "${ORDS_DBVER_SHORT}" = "${ORDS_VER}" ]; then
            printf "%s%s\n" "INFO : " "The Oracle REST Data Services is already installed in your database."
        elif [ ${ORDSDB_YEAR} -gt ${ORDS_YEAR} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle REST Data Services ($ORDS_DBVER) is already installed in your database. Oracle REST Data Servcies will not work correctly, update your docker image."
            exit 1 
        elif [ ${ORDSDB_YEAR} -eq ${ORDS_YEAR} ] && [ ${ORDSDB_QTR} -gt ${ORDS_QTR} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle REST Data Services ($ORDS_DBVER) is already installed in your database. Oracle REST Data Servcies will not work correctly, update your docker image."
            exit 1
        elif [ ${ORDSDB_YEAR} -eq ${ORDS_YEAR} ] && [ ${ORDSDB_QTR} -eq ${ORDS_QTR} ] && [ ${ORDSDB_PATCH} -gt ${ORDS_PATCH} ]; then
            printf "\a%s%s\n" "ERROR: " "A newer Oracle REST Data Services ($ORDS_DBVER) is already installed in your database. Oracle REST Data Servcies will not work correctly, update your docker image."
            exit 1
        else
            printf "%s%s\n" "INFO : " "The Oracle REST Data Services version ${ORDS_DBVER} is installed on your database and will be upgraded to ${ORDS_VER} version"
            _install_ords
        fi
    fi
}

function _install_ords(){
    printf "%s%s\n" "INFO : " "Installing The Oracle REST Data Services $ORDS_VER."
    # Randomize the password for all the ORDS connection pool accounts
    cd ${ORDS_CONF_DIR}
    CONN_TYPE=$(_dbconnect_var | cut -d"_" -f 3) > /dev/null
    case "${CONN_TYPE}" in 
        "simple")
            ${ORDS_HOME}/bin/ords install --admin-user SYS --proxy-user --password-stdin --db-hostname ${DBHOST} \
            --db-port ${DBPORT} --db-servicename ${DBSERVICENAME} --feature-sdw true \
            --log-folder ${INSTALL_LOGS}  << _SECRET > ${INSTALL_LOGS}/ords_install.log 2>&1
${ORACLE_PWD}
oracle
_SECRET
        ;;
        "string")
            ${ORDS_HOME}/bin/ords  install --admin-user sys --db-custom-url "jdbc:oracle:thin:@${CONN_STRING}" \
            --proxy-user --password-stdin --feature-sdw true \
            --log-folder ${INSTALL_LOGS}  << _SECRET > ${INSTALL_LOGS}/ords_install.log 2>&1
${ORACLE_PWD}
oracle
_SECRET
        ;;
        *) 
            _unknown_error
        ;;
    esac
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        printf "%s%s\n" "INFO : " "The Oracle REST Data Services $ORDS_VER has been installed correctly on your database."
    else
        printf "\a%s%s\n" "ERROR: " "The Oracle REST Data Services installation has failed."
        tail -20 ${INSTALL_LOGS}/ords_install.log
        exit 1
    fi
}

function _ords_entrypoint_dir(){
    if [ -d ${ORDS_ENTRYPOINT_DIR} ] ; then
        ls -la ${ORDS_ENTRYPOINT_DIR}/*.sh > /dev/null
        EXIST=$?
        if [ $EXIST -gt 0 ]; then
            printf "%s%s\n" "INFO : " "No custom scripts were detected to run before starting the service."
        else
            printf "%s%s\n" "INFO : " "Files with extensions .sh, were found in ${ORDS_ENTRYPOINT_DIR}. Files will be executed alphabetically."
            for CUSTOM_SCRIPT in $(ls -L $ORDS_ENTRYPOINT_DIR/*.sh | sort); do
                printf "%s%s\n" "INFO : " "Executing script ${CUSTOM_SCRIPT}."
                bash ${CUSTOM_SCRIPT}
            done
        fi
    fi
}

function _config_ords(){
    if [ ! $(ls -A ${ORDS_CONF_DIR}| wc -l ) -gt 0 ]; then
        printf "\a%s%s\n" "ERROR: " "The ORDS config directory ${ORDS_CONF_DIR} is empty, please validate you ords config volume."
        exit 1
    fi
    cd ${ORDS_CONF_DIR}
    # Set standalone accesslogs
    ${ORDS_HOME}/bin/ords config set standalone.access.log /tmp/ords_access_logs/   >/dev/null 2>&1
    mkdir /tmp/ords_access_logs/ >/dev/null 2>&1
    touch /tmp/ords_access_logs/ords_$(date +%Y_%m_%d).log >/dev/null 2>&1
    tail -f  /tmp/ords_access_logs/ords_$(date +%Y_%m_%d).log &
    # Set MongoDB
    ${ORDS_HOME}/bin/ords config set mongo.enabled true  >/dev/null 2>&1
    if [ -d ${APEXI} ]; then
        printf "%s%s\n" "INFO : " "Setup standalone.static.path ${APEX_HOME}/images."
        ${ORDS_HOME}/bin/ords config set standalone.static.path ${APEX_HOME}/images  >/dev/null 2>&1
    fi
    export CERT_FILE="$ORDS_CONF_DIR/ssl/cert.crt"
    export KEY_FILE="$ORDS_CONF_DIR/ssl/key.key"
    # Set sceure if certificates are present
    if [ -e ${CERT_FILE} ] && [ -e ${KEY_FILE} ]; then
        printf "%s%s\n" "INFO : " "The SSL certificates were found, and the Oracle REST Data Serervices instance will run on secure port 8443."
        ${ORDS_HOME}/bin/ords config set standalone.https.cert ${CERT_FILE}  >/dev/null 2>&1
        ${ORDS_HOME}/bin/ords config set standalone.https.cert.key ${KEY_FILE}  >/dev/null 2>&1
        ${ORDS_HOME}/bin/ords config set standalone.https.port 8443  >/dev/null 2>&1
    fi
    # If FORCE SECURE is true and Certificates does not exist, exit
    if ([ "${FORCE_SECURE}" = "TRUE" ] || [ "${FORCE_SECURE}" = "true" ]) && ([ ! -e ${CERT_FILE} ] || [ ! -e ${KEY_FILE}  ]); then 
        printf "\a%s%s\n" "ERROR: " "The FORCE_SECURE flag is TRUE but the certificate files are missing at /ect/ords/config/ssl directory:"
        printf "%s%s\n" "       " "  - /etc/ords/config/ssl/cert.crt certificate file"
        printf "%s%s\n" "       " "  - /etc/ords/config/ssl/key.key  key file"
        exit 1
    fi
    if [ "${DEBUG}" = "TRUE" ] || [ "${DEBUG}" = "true" ]; then 
        ${ORDS_HOME}/bin/ords config set debug.printDebugToScreen true >/dev/null 2>&1
    elif [ "${DEBUG}" = "FALSE" ] || [ "${DEBUG}" = "false" ]; then 
        ${ORDS_HOME}/bin/ords config set debug.printDebugToScreen false >/dev/null 2>&1
    fi
}

function _run_ords(){
    printf "%s%s\n" "INFO : " "Starting the Oracle REST Data Services instance."
    ${ORDS_HOME}/bin/ords serve
}

function _unknown_error(){
    printf "\a%s%s\n" "ERROR: " "Unknown error."
    exit 1
}

function _connection_error(){
    printf "\a%s%s\n" "ERROR: " "Cannot connect to the database with the shared credentials it is necessary to meet one of the below requirements:"
    printf "%s%s\n"   "       " "- CONN_STRING and ORACLE_PWD variables declared."
    printf "%s%s\n"   "       " "- DBHOST, DBPORT, DBSERVICENAME, and ORACLE_PWD variables declared."
    exit 1
}

function _run_cli(){
    printf "%s%s\n" "INFO : " "Running Oracle REST Data Services CLI command."
    ${ORDS_HOME}/bin/ords ${CLI_CMD}
}

function _get_pool(){
    CONNECTION_TYPE=$(grep db.connectionType $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    if [ "${CONNECTION_TYPE}" == "basic" ]; then
        DB_HOST=$(grep db.hostname $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
        DB_PORT=$(grep db.port $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
        DB_NAME=$(grep db.servicename $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
        printf "%s%s\n" "INFO : " "Starting the Oracle REST Data Services instance with the preset configuration in /etc/ords/config:"
        printf "%s%s\n" "INFO : " "  ${DB_HOST}:${DB_PORT}/${DB_NAME}."
    elif [ "${CONNECTION_TYPE}" == "customurl" ]; then
        CONN_STRING=$(grep db.customUR $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
        printf "%s%s\n" "INFO : " "Starting the Oracle REST Data Services instance with the preset configuration in /etc/ords/config:"
        printf "%s%s\n" "INFO : " "  ${CONN_STRING} "
    else
        printf "%s%s\n" "INFO : " "Starting the Oracle REST Data Services instance with the preset configuration in /etc/ords/config."
    fi
}

# Main
CLI_CMD=$@
function _run_script(){
    if [ "${CLI_CMD}" = "" ]; then
        # If credentials are present try to Install/Upgrade before run the service
        if ([ ! -z ${DBHOST} ] && [ ! -z ${DBPORT} ] && [ ! -z ${DBSERVICENAME} ] && [ ! -z ${ORACLE_PWD} ]) || ( [ ! -z ${CONN_STRING} ] && [ ! -z ${ORACLE_PWD} ] ); then
            mkdir -p ${INSTALL_LOGS}
            _test_database
            if [ -f ${APEX_HOME}/apxsilentins.sql ]; then
                _ords_ver
                _apex_ver
                _ords_repair
            else
                _ords_ver
            fi
            _config_ords
            _ords_entrypoint_dir
            _run_ords
        else
            if [ $(ls -A ${ORDS_CONF_DIR}/databases |wc -l) -gt 0 ] && [ -e ${ORDS_CONF_DIR}/global/settings.xml ];  then
                _get_pool
                _config_ords
                _ords_entrypoint_dir
                _run_ords
            else
                printf "\a%s%s\n" "ERROR: " "The container can't find a valid configuration in Oracle REST Data Services config directory /etc/ords/config."
                printf "%s%s\n" "       " "To install the product on your database and create a new configuration set the credentials meeting one of the below requirements:"
                printf "%s%s\n" "       " "    - CONN_STRING and ORACLE_PWD variables declared."
                printf "%s%s\n" "       " "    - DBHOST, DBPORT, DBSERVICENAME, and ORACLE_PWD variables declared."
                exit 1
            fi
        fi
    else
        _run_cli
    fi
}
_run_script

