TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
DAYS="Mon Tue Wed Thu Fri Sat Sun"
# TOKENS="mongo_admin_carmel6000 mongo_admin_Hospikol hilmaAdminmysql8aws hilmaAdminmysql8b"
TOKENS="hilmaAdminmysql8aws"
ROOT_BAKUPS_DIR="backups"
BUCKET_KEY="backup-databases-hilma"
BUCKET="s3://${BUCKET_KEY}/"
BACKUP_DAY="Sun"
BACKUP_MONTH="01"
BACKUP_YEAR="01-01"

check_config(){
	RES=$(aws s3api list-buckets --query 'Buckets[?Name==`'"$BUCKET_KEY"'`].Name | [0]')
	if [ $RES == 'null' ]; then
		aws s3api create-bucket --bucket $BUCKET_KEY --region eu-west-1  --create-bucket-configuration LocationConstraint=eu-west-1
		aws s3api put-public-access-block --bucket $BUCKET_KEY --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
		echo "CREATING NEW BUCKET ${BUCKET_KEY}"
	fi 

	mkdir -p "$TIMESTAMP"
	BACKUPS_DIR=$TIMESTAMP
}

get_credential() {

	SQLSRV=$1

	TMP_FILE=tmp.json
	# getting secret for mongoAdmin
	aws secretsmanager get-secret-value --query 'SecretString' --output=text --secret-id ${SQLSRV} >$TMP_FILE
	if [ $? -ne 0 ]; then
		echo "ERROR on getting admin secrets for $SQLSRV"
		return 1
	fi
	user_param='user'
	if [ ${1::5} == "hilma" ]; then
		user_param="user"
	elif [ ${1::5} == "mongo" ]; then
		user_param="username"
	fi

	USER=$(jq -r .$user_param $TMP_FILE)
	PASSWORD=$(jq -r '.password' $TMP_FILE)
	HOST=$(jq -r '.host' $TMP_FILE)
	PORT=$(jq -r '.port' $TMP_FILE)
	rm $TMP_FILE
}

conduct_mysql_backup() {
	USER=$1
	PASSWORD=$2
	HOST=$3
	SRVNAME=$4

	echo SHOW DATABASES >tmp.sql
	mysql -h$HOST -u$USER -p$PASSWORD <tmp.sql >tmp
	rm tmp.sql
	i=0
	while IFS= read -r line; do
		echo i: $i $line
		if [ $i -gt 0 ]; then
			if [ $line != mysql ] && [ $line != sys ] && [ $line != performance_schema ] && [ $line != information_schema ]; then
				echo DB: $line $(date) >>$BACKUPS_DIR/$SRVNAME/log
				mysqldump -h$HOST -u$USER -p$PASSWORD --set-gtid-purged=OFF $line >$BACKUPS_DIR/$SRVNAME/$line.sql
				if [ $? -ne 0 ]; then
					echo ERROR on mysqldump for $line >>$BACKUPS_DIR/$SRVNAME/log
				fi
			fi
		fi
		((i = i + 1))
	done <tmp
	rm tmp
	echo Dump COMPLETED $(date) >>$BACKUPS_DIR/$SRVNAME/log
}

conduct_mongo_backup() {
	USER=$1
	PASSWORD=$2
	HOST=$3
	PORT=$4
	SRVNAME=$5
	
	mongo mongodb+srv://$HOST:$PORT/admin --username=$USER --password=$PASSWORD mongo.js > tmp
	i=0
	while IFS= read -r line; do
		echo i: $i $line
		line=${line:1:(-1)}
		if [ $i -gt 0 ]; then
			if [ $line != admin ] && [ $line != local ] && [ $line != config ]; then
				echo DB: $line $(date)
				mongodump mongodb+srv://$HOST --username=$USER --password=$PASSWORD --db $line --out $BACKUPS_DIR/$SRVNAME
				if [ $? -ne 0 ]; then
					echo ERROR on mysqldump for $line >>$BACKUPS_DIR/$SRVNAME/log
				fi
			fi
		fi
		((i = i + 1))
	done < tmp
	rm tmp

	echo Dump COMPLETED $(date) >>$BACKUPS_DIR/$SRVNAME/log	
}

conduct_backup() {
	mkdir -p $BACKUPS_DIR/$1
	get_credential $1

	if [ $? -eq 0 ]; then
		echo Dumping ALL DBs $(date) >>$BACKUPS_DIR/$1/log

		echo DUMPING TABLES SEPARATELY >>$BACKUPS_DIR/$1/log

		
		if [ ${SQLSRV::5} == "hilma" ]; then
			conduct_mysql_backup $USER $PASSWORD $HOST $1
		elif [ ${SQLSRV::5} == "mongo" ]; then
			conduct_mongo_backup $USER $PASSWORD $HOST $PORT $1
		fi	 

		echo Dump COMPLETED $(date) >>$BACKUPS_DIR/$1/log
	else
		echo ERROR on $1 BACKUP!!!!!
	fi
}

compare_dates() {
	date0=${1::10}
	time0=${1:(-8)}
	time0=$(echo ${time0} | tr "-" ":" | tr "_" " ")

	date1=${2::10}
	time1=${2:(-8)}
	time1=$(echo ${time1} | tr "-" ":" | tr "_" " ")

	x=$(date --date="${date0} ${time0}" +%s)
	y=$(date --date="${date1} ${time1}" +%s)

	if [ ${x} -lt ${y} ]; then
		RESULT=1
	elif [ ${y} -lt ${x} ]; then
		RESULT=2
	else
		RESULT=0
	fi
}

move_to_directory() {
	
	CURRENT_DAY=$(date +"%a")
	CURRENT_MONTH_DATE=$(date +"%d")
	CURRENT_YEAR_DATE=$(date +"%m-%d")	

	if [ $CURRENT_YEAR_DATE == $BACKUP_YEAR ]; then
		aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}year_backups/ 
	elif [ $CURRENT_MONTH_DATE == $BACKUP_MONTH ]; then
		aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}month_backups/
	elif [ $CURRENT_DAY == $BACKUP_DAY ]; then
		aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}week_backups/
	else
		aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}day_backups/
	fi
}

clean_old() {
	clean_backup_directories "day_backups" 7
	clean_backup_directories "week_backups" 4
	clean_backup_directories "month_backups" 12
	clean_backup_directories "year_backups" 10
}
delete_last_backup() {

	date=${TIMESTAMP::10}
	oldest_file=$TIMESTAMP
	folder=$1	
	query='Contents[?starts_with(Key,`'$folder'`)].Key'
	aws s3api list-objects --bucket ${BUCKET_KEY} --query $query > TMP_FILE
	while read filepath; do
	    if [[ ! $filepath == *log* ]]; then 
			file=${filepath:(-24):19}
			compare_dates $file $oldest_file
			if [ $RESULT -eq 1 ]; then
				oldest_file=$file
			fi	 
		fi	
	done <<< "$(jq -c '.[]' TMP_FILE)"
	while read filepath; do
	    if [[ ! $filepath == *log* ]]; then 
			file=${filepath:(-24):19}
			if [ "${file}" == "${oldest_file}" ]; then
				filepath=${filepath:1}
				filepath=${filepath::(-1)}
				aws s3 rm $BUCKET${filepath}
			fi 
		fi 
	done <<< "$(jq -c '.[]' TMP_FILE)"

	rm TMP_FILE
}

clean_backup_directories() {
	DELETE_DIR=$BUCKET$1/
	num_files=$(aws s3 ls ${DELETE_DIR} | wc -l)

	while [ $num_files -gt $2 ]; do
		delete_last_backup $1
		new_num_files=$(aws s3 ls ${DELETE_DIR} | wc -l)
		if [ $num_files -eq $new_num_files ]; then 
			echo "ERROR on deleting old backups for $1 directory"
			exit 1
		fi
		num_files=$new_num_files
	done
}

simulate() {
	i=0
	while [ $i -lt 700  ]; do
		y=$(date --date="2020-01-01 08:00:00" +%s)
		((y = $y + 86400*$i))
		TIMESTAMP=$(date -u -d @$y "+%Y-%m-%d_%H-%M-%S")
		CURRENT_DAY=$(date -u -d @$y "+%a")
		CURRENT_MONTH_DATE=$(date -u -d @$y "+%d")
		CURRENT_YEAR_DATE=$(date -u -d @$y "+%m-%d")

		check_config
		tar -C $BACKUPS_DIR/.. -czvf $BACKUPS_DIR/../$TIMESTAMP.tgz $TIMESTAMP
		rm -rf $BACKUPS_DIR
		if [ $CURRENT_YEAR_DATE == $BACKUP_YEAR ]; then
			aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}year_backups/ 
		elif [ $CURRENT_MONTH_DATE == $BACKUP_MONTH ]; then
			aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}month_backups/
		elif [ $CURRENT_DAY == $BACKUP_DAY ]; then
			aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}week_backups/
		else
			aws s3 mv $BACKUPS_DIR.tgz ${BUCKET}day_backups/
		fi
		clean_old
		((i=$i+1))
	done
}

main() {
	check_config
# 	for tok in ${TOKENS[@]}; do
# 		echo BACKING UP ${tok}
# 		conduct_backup ${tok}
# 	done
# 	tar -C $BACKUPS_DIR/.. -czvf $BACKUPS_DIR/../$TIMESTAMP.tgz $TIMESTAMP
# 	rm -rf $BACKUPS_DIR
# 	move_to_directory
# 	clean_old
}

simulate
