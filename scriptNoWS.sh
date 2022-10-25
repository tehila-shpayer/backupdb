TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
DAYS="Mon Tue Wed Thu Fri Sat Sun"
TOKENS="ss"
ROOT_BAKUPS_DIR="backups"
MYSQL_DIR="mnt/c/Program Files/MySQL/MySQL Server 8.0/bin"
if [ ! -d $ROOT_BAKUPS_DIR ]; then
	echo CREATE $ROOT_BAKUPS_DIR DIRECTORY
	mkdir -p $ROOT_BAKUPS_DIR
	if [ ${?} -ne 0 ]; then
		echo "Error creating $ROOT_BAKUPS_DIR!"
		echo "Script will now exit..."
		exit 1
	fi
fi
BACKUP_DAY="All"
check_config(){
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
if [ -z ${!DAY} ]; then
	echo "The length of variable: \$${DAY} is 0 (zero)!"
	echo "Script will now exit..."
	exit 4
fi				
FLAG="false"
if [ "${!DAY}" == "All" ]; then
	FLAG="true"
else
	for day in "${DAYS[@]}"; do
		echo Check $day
			if [ "${day}" == "${!DAY}" ]; then
				FLAG="true"
			fi
		done
fi
	if [ "${FLAG}" == "false" ]; then
		echo "The value of the \$${DAY} variable is INVALID!"
		echo "Available options: \"Mon\", \"Tue\", \"Wed\", \"Thu\", \"Fri\", \"Sat\", \"Sun\" "
		echo "Script will now exit..."
		exit 5
	fi

	mkdir -p $BACKUPS_DIR/$TIMESTAMP
	BACKUPS_DIR=$BACKUPS_DIR/$TIMESTAMP
}

get_credential() {

	# SQLSRV=$1
	# awsAdminSecretName=hilmaAdmin$SQLSRV
	# SECRET_NAME=${SQLSRV}-${dbName}

	# TMP_FILE=tmp.json
	# # getting secret for mongoAdmin
	# aws secretsmanager get-secret-value --query 'SecretString' --output=text --secret-id ${awsAdminSecretName} >$TMP_FILE
	# if [ $? -ne 0 ]; then
	# 	echo "ERROR on getting admin secrets for $SQLSRV"
	# 	return 1
	# fi

	# USER=$(jq -r '.user' $TMP_FILE)
	# PASSWORD=$(jq -r '.password' $TMP_FILE)
	# HOST=$(jq -r '.host' $TMP_FILE)
	# rm $TMP_FILE
	USER=root
	PASSWORD=hilma
	HOST=localhost

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
			"\"$MYSQL_DIR/mysql.exe\"" -u$USER -p$PASSWORD <tmp.sql >tmp
			rm tmp.sql
			i=0
			while IFS= read -r line; do
				echo i: $i $line
				if [ $i -gt 0 ]; then
					if [ $line != mysql ] && [ $line != sys ] && [ $line != performance_schema ] && [ $line != information_schema ]; then
						echo DB: $line $(date) >>$BACKUPS_DIR/$1/log
						"${MYSQL_DIR}/mysqldump" -u$USER -p$PASSWORD --set-gtid-purged=OFF $line >$BACKUPS_DIR/$1/$line.sql
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
compare_dates() {
	d0=${1::10}
	d1=${2::10}

	if [ "${d0}" \\< "${d1}" ]; then
		return 1
	elif [ "${d0}" \\> "${d1}" ]; then
		return 2
	fi
	return 0
}
timestamp_diff() {
	date0=${1::10}
	time0=${1:(-8)}
	time0=$(echo ${time0} | tr "-" ":" | tr "_" " ")

	date1=${2::10}
	time1=${2:(-8)}
	time1=$(echo ${time1} | tr "-" ":" | tr "_" " ")

	x=$(date --date="${date0} ${time0}" +%s)
	y=$(date --date="${date1} ${time1}" +%s)

	if [ ${x} -lt ${y} ]; then
		tmp=${x}
		x=${y}
		y=${tmp}
	fi

	DIFF=$(((${x} - ${y}) / 86400))
}
get_prev_week() {
	SUN=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Sunday")
	MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Monday")
	timestamp_diff ${MON} ${SUN}
	if [ ${DIFF} -eq 1 ]; then
		MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Monday -1 week")
	fi
}
clean_old() {
	same_day=0
	num_days=0
	num_weeks=0
	num_months=0
	num_years=0
	CURR_DIR=`pwd`
	cd $ROOT_BAKUPS_DIR
	for file in *; do
	echo $file
	filedate=${file//.tgz/}
	echo $filedate
timestamp_diff $TIMESTAMP $filedate
echo $DIFF
	if [ $DIFF -gt 365 ]; then ((num_years = num_years + 1)); fi
	if [ $DIFF -gt 30 ] && [ $DIFF -le 365 ]; then ((num_months = num_months + 1)); fi
	if [ $DIFF -gt 7 ] && [ $DIFF -le 30 ]; then ((num_weeks = num_weeks + 1)); fi
	if [ $DIFF -le 7 ]&& [ $DIFF -ne 0 ]; then ((num_days = num_days + 1)); fi
	if [ $DIFF -eq 0 ]; then ((same_day = same_day + 1)); fi
	done
	if [ $same_day -gt 1 ]; then clean_same_day; fi
	if [ $num_days -gt 7 ]; then clean_day; fi
	if [ $num_weeks -gt 4 ]; then clean_week; fi
	if [ $num_months -gt 12 ]; then clean_month; fi
	
	echo $num_years $num_months $num_weeks $num_days $same_day
	cd $CURR_DIR
}
main() {
	pwd
	check_config
	for tok in ${TOKENS[@]}; do
		echo BACKING UP ${tok}
		conduct_backup ${tok}
	done
	tar -C $BACKUPS_DIR/.. -czvf $BACKUPS_DIR/../$TIMESTAMP.tgz $TIMESTAMP
	rm -rf $BACKUPS_DIR
	clean_old
	echo hello world
}


main
