    TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S") 
    DAYS="Mon Tue Wed Thu Fri Sat Sun"
    TOKENS="mysql8aws mysql8a mysql8b" # For any additional entry add the appropriate
    
    
    
    ROOT_BAKUPS_DIR="backups"
    if [ ! -d $ROOT_BAKUPS_DIR ]; then
        echo CREATE $ROOT_BAKUPS_DIR DIRECTORY
        mkdir -p $ROOT_BAKUPS_DIR
        if [ ${?} -ne 0 ]; then
            echo "Error creating $ROOT_BAKUPS_DIR!"
            echo "Script will now exit..."
            exit 1
        fi

    fi

    BACKUP_DAY="All" # The day of the week that the backup should be taken. All, Mon, Tue, Wed, Thu, Fri, Sat, Sun

    check_config() {
        if [ ! -d $ROOT_BAKUPS_DIR ]; then
            echo CREATE $ROOT_BAKUPS_DIR DIRECTORY
            mkdir -p $ROOT_BAKUPS_DIR
            if [ ${?} -ne 0 ]; then
                echo "Error creating $ROOT_BAKUPS_DIR!"
                echo "Script will now exit..."
                exit 1
            fi

        fi

        BACKUPS_DIR=$ROOT_BAKUPS_DIR
        DAY="BACKUP_DAY"
        # echo "${DAY}"
        if [ -z ${!DAY} ]; then
            echo "The length of variable: \$${DAY} is 0 (zero)!"
            echo "Script will now exit..."
            exit 4
        fi

        if [ ! -z "${DAY}" ]; then
            echo "hello"
        fi
        

        
        # FLAG="false"
        # if [ "${!DAY}" == "All" ]; then
        # 	FLAG="true"
        # else
        # 	for day in "${DAYS[@]}"; do
        # 		echo Check $day
        # 		if [ "${day}" == "${!DAY}" ]; then
        # 			FLAG="true"
        # 		fi
        # 	done
        # fi

        # if [ "${FLAG}" == "false" ]; then
        # 	echo "The value of the \$${DAY} variable is INVALID!"
        # 	echo "Available options: \"Mon\", \"Tue\", \"Wed\", \"Thu\", \"Fri\", \"Sat\", \"Sun\" "
        # 	echo "Script will now exit..."
        # 	exit 5
        # fi

        # echo Backing up at $BACKUPS_DIR/$TIMESTAMP

        # if [ -d $BACKUPS_DIR/$TIMESTAMP ]; then
        # 	TT=$(date "+%H-%M-%S")
        # 	mv $BACKUPS_DIR/$TIMESTAMP $BACKUPS_DIR/${TIMESTAMP}_${TT}
        # fi

        # mkdir -p $BACKUPS_DIR/$TIMESTAMP
        # BACKUPS_DIR=$BACKUPS_DIR/$TIMESTAMP
    }

    get_credential() {

        SQLSRV=$1
        awsAdminSecretName=hilmaAdmin$SQLSRV
        SECRET_NAME=${SQLSRV}-${dbName}

        TMP_FILE=tmp.json
        #getting secret for mongoAdmin
        aws secretsmanager get-secret-value --query 'SecretString' --output=text --secret-id ${awsAdminSecretName} >$TMP_FILE
        if [ $? -ne 0 ]; then
            echo "ERROR on getting admin secrets for $SQLSRV"
            return 1
        fi

        USER=$(jq -r '.user' $TMP_FILE)
        PASSWORD=$(jq -r '.password' $TMP_FILE)
        HOST=$(jq -r '.host' $TMP_FILE)
        rm $TMP_FILE

    }
    conduct_backup() {
        mkdir -p $BACKUPS_DIR/$1
        get_credential $1
        if [ $? -eq 0 ]; then
            echo Dumping ALL DBs $(date) >>$BACKUPS_DIR/$1/log
            # mysqldump -h$HOST -u$USER -p$PASSWORD --all-databases --triggers --routines --events >$BACKUPS_DIR/$1/alldbs.sql
            # if [ $? -ne 0 ]; then
                echo ERROR on mysqldump for ALL DBS
                echo DUMPING TABLES SEPARATELY >>$BACKUPS_DIR/$1/log

                echo SHOW DATABASES >tmp.sql
                mysql -h$HOST -u$USER -p$PASSWORD <tmp.sql >tmp
                rm tmp.sql
                i=0
                while IFS= read -r line; do
                    echo i: $i $line
                    if [ $i -gt 0 ]; then
                        if [ $line != mysql ] && [ $line != sys ] && [ $line != performance_schema ] && [ $line != information_schema ]; then
                            echo DB: $line $(date) >>$BACKUPS_DIR/$1/log
                            mysqldump -h$HOST -u$USER -p$PASSWORD --set-gtid-purged=OFF $line >$BACKUPS_DIR/$1/$line.sql
                            if [ $? -ne 0 ]; then
                                echo ERROR on mysqldump for $line >>$BACKUPS_DIR/$1/log
                            fi
                        fi
                    fi
                    ((i = i + 1))
                done <tmp
                rm tmp
            # fi
            echo Dump COMPLETED $(date) >>$BACKUPS_DIR/$1/log
        else
            echo ERROR on $1 BACKUP!!!!!
        fi
    }
    main() {
        check_config
        # for tok in ${TOKENS[@]}; do
        #     echo BACKING UP ${tok}
        #     conduct_backup ${tok}
        # done
        # tar -C $BACKUPS_DIR/.. -czvf $BACKUPS_DIR/../$TIMESTAMP.tgz $TIMESTAMP
        # rm -rf $BACKUPS_DIR
        # clean_old
        # echo hello world
    }


    main
