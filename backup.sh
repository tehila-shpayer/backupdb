#!/usr/bin/env bash

#+-----------------------------------------------------------------------+
#|              Copyright (C) 2016-2018 George Z. Zachos                 |
#+-----------------------------------------------------------------------+
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Contact Information:
# Name: George Z. Zachos
# Email: gzzachos <at> gmail.com

# Description: This shell script backups the directories specified in the
# CONFIGURATION SECTION below by compressing and storing them. It is designed
# to be executed @midnight (same as @daily) using Cron.
#
# Example cron entry:
# @midnight /root/bin/backup.sh
#
# Details: Every "<token-uppercase>_BACKUP_DAY" a backup is taken.
# If no backup was taken the previous week (Mon -> Sun) AND  if no
# backup was taken this week, a backup is taken no matter what.
#
# Backups older than 5 weeks (counting current week) are deleted unless
# the total number of backups is less than 6 (<=5).

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S") # Do NOT modify!
#TIMESTAMP=$(date "+%Y-%m-%d") # Do NOT modify!
DAYS=(Mon Tue Wed Thu Fri Sat Sun)

###################################################################
#                    CONFIGURATION SECTION                        #
###################################################################

# The configuration section is the only section you should modify,
# unless you really(!) know what you are doing!!!

# Make sure to always comply with the name format of the variables
# below. As you may have noticed, all variables related to each
# other begin with the same token (i.e. WIKI, CLOUD, ...).

# To add any additional directories to be backed up, you should only
# add three (3) new lines and modify ${TOKENS} variable. See the
# examples below to get a better understanding.

# Example of ${TOKENS} variable.
#TOKENS="MYSQL8A MYSQL8B MYSQL8AWS MONGO"	# For any additional entry add the appropriate
TOKENS="mysql8aws mysql8a mysql8b" # For any additional entry add the appropriate
# <token-uppercase> separating it with a space
# character from existing tokens.

# Template - The three lines that should be added for every new directory addition.
# <token-uppercase>_BACKUPS_DIR="/path/to/dir"     # No '/' at the end of the path!
# <token-uppercase>_DIR="/path/to/another-dir"     # No '/' at the end of the path!
# <token-uppercase>_BACKUP_DAY="<weekday-3-letters>"

# Example No.1
ROOT_BAKUPS_DIR="C:/backup"
BACKUP_DAY="All" # The day of the week that the backup should be taken. All, Mon, Tue, Wed, Thu, Fri, Sat, Sun

###################################################################
#                          check_config()                         #
###################################################################

# Checks if the directory where the backups will be saved exists
# (creates it if needed), then checks if the directory to be backed
# up exists and finally if the day for the backup to be taken
# is valid.
#
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
	# DIR="${1}_DIR"
	DAY="BACKUP_DAY"

	# echo DAY ${DAY} !! ${!DAY}
	# echo BACKUPS_DIR ${BACKUPS_DIR}

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
	echo Backing up at $BACKUPS_DIR/$TIMESTAMP
	# if [ -d $BACKUPS_DIR/$TIMESTAMP ]; then
	# 	TT=$(date "+%H-%M-%S")
	# 	mv $BACKUPS_DIR/$TIMESTAMP $BACKUPS_DIR/${TIMESTAMP}_${TT}
	# fi
	mkdir -p $BACKUPS_DIR/$TIMESTAMP
	BACKUPS_DIR=$BACKUPS_DIR/$TIMESTAMP
}

###################################################################
#                          compare_dates()                        #
###################################################################

# Compares the dates which are extracted from the two (2) timestamps
# given as function parameters.
# Return value:	'0' - if date0 = date1
#          	'1' - if date0 < date1
#          	'2' - if date0 > date1
#
# Parameters:	$1 -> Timestamp #0
#		$2 -> Timestamp #1
#
# The format of Timestamp #0 and #1 matches the template of ${TIMESTAMP}.
# i.e. 2016-06-20_11-50-20
compare_dates() {
	d0=${1::10}
	d1=${2::10}

	if [ "${d0}" \< "${d1}" ]; then
		return 1
	elif [ "${d0}" \> "${d1}" ]; then
		return 2
	fi
	return 0
}

###################################################################
#                         timestamp_diff()                        #
###################################################################

# Calculates and returns the difference (absolute value in days)
# between the two (2) timestamps given as function parameters.
# The result is stored in variable ${DIFF}.
#
# Parameters:   $1 -> Timestamp #0
#               $2 -> Timestamp #1
#
# The format of Timestamp #0 and #1 matches the template of ${TIMESTAMP}.
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

###################################################################
#                        get_prev_week()                          #
###################################################################

# Calculates the timestamp of previous week's Monday and Sunday
# (time 00:00:00). Monday is assumed to be the first day of the week.
# The results are stored in ${MON} and ${SUN}.
get_prev_week() {
	SUN=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Sunday")
	MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Monday")
	timestamp_diff ${MON} ${SUN}
	if [ ${DIFF} -eq 1 ]; then
		MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="last Monday -1 week")
	fi
}
#################
#
#################
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

###################################################################
#                        conduct_backup()                         #
###################################################################

# Takes a backup of the ${<some-token>_DIR} directory and temporarily
# stores it in /tmp/. if the 'tar' command exits with no errors, the
# temporary file is moved to the directory held in ${<some-token>_BACKUPS_DIR}.
#
# Parameter:	$1 -> {WIKI, CLOUD, ...}
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

# ###################################################################
# #                        check_backups()                          #
# ###################################################################

# # Does all the job.
# # 	- Checks if a backup was taken this week.
# #	- Checks if a any backups were taken the last 6 weeks.
# #	- If today is "<token-uppercase>_BACKUP_DAY" a backup is taken.
# #	- If no backups were taken this week or the preview one,
# #	  a backup is taken.
# #	- If the total number of backups is more than 5 (>=6),
# #	  excess backups which are older than 5 weeks are deleted.
# #	  (counting current week in those 5)
# # Parameter:	$1 -> {WIKI, CLOUD, ...}
# check_backups() {
# 	TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
# 	BACKUPS_DIR="${1}_BACKUPS_DIR"
# 	BACKUP_FILES=$(ls -1 ${!BACKUPS_DIR} | grep -E \
# 		"^backup_${TOKEN_LOWERCASE}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}.tar.gz" \
# 		2>/dev/null | sort -r)
# 	BACKUP_DAY="${1}_BACKUP_DAY"
# 	TODAY=$(date +%a)
# 	FILENUM_SUM=0
# 	DELETED_SUM=0

# 	get_prev_week

# 	# Update $MON and $SUN to hold the timestamp of current week.
# 	MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="${MON::10} +1 week")
# 	SUN=$(date "+%Y-%m-%d_%H-%M-%S" --date="${SUN::10} +1 week")

# 	echo -e "\n##### $1\n"

# 	for week in $(seq 1 6); do
# 		FILENUM=0
# 		echo "WEEK ${week}: {${MON::10} -> ${SUN::10}}"

# 		for file in ${BACKUP_FILES}; do
# 			BACKUP_TIME=${file:(-26):19}
# 			compare_dates ${BACKUP_TIME} ${SUN}
# 			x=${?}
# 			compare_dates ${BACKUP_TIME} ${MON}
# 			y=${?}
# 			if [ ${x} -le 1 ] && [ ${y} -eq 2 -o ${y} -eq 0 ]; then
# 				echo -e "\t${file}"
# 				((FILENUM++))

# 				if [ ${week} -eq 6 ] && [ $((FILENUM_SUM + FILENUM)) -gt 5 ]; then
# 					echo -e "\t[rm ${!BACKUPS_DIR}/${file}]"
# 					rm ${!BACKUPS_DIR}/${file}
# 					((DELETED_SUM++))
# 				fi
# 			fi
# 		done

# 		echo IN 1 week: ${week} today ${TODAY} bcakupday ${!BACKUP_DAY} filenum_sum ${FILENUM_SUM} filenum ${FILENUM}
# 		if [ ${week} -eq 1 ] && [ "${TODAY}" == "${!BACKUP_DAY}" ] || [ "${!BACKUP_DAY}" == "All" ]; then
# 			echo IN 2
# 			conduct_backup ${1}
# 			((FILENUM++))
# 		fi

# 		((FILENUM_SUM += FILENUM))

# 		if [ ${week} -eq 2 ] && [ ${FILENUM_SUM} -eq 0 ]; then
# 			echo IN 3
# 			conduct_backup ${1}
# 			((FILENUM++))
# 			((FILENUM_SUM++))
# 		fi

# 		if [ ${FILENUM} -eq 0 ]; then
# 			echo IN 4
# 			echo -e "\tNo backup files were found!"
# 		fi

# 		MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="${MON::10} -1 week")
# 		SUN=$(date "+%Y-%m-%d_%H-%M-%S" --date="${SUN::10} -1 week")
# 	done

# 	echo " "
# 	echo "===== REPORT ====="
# 	echo "${FILENUM_SUM} ${2} backup file(s) exist!"
# 	echo "${DELETED_SUM} ${2} backup file(s) were deleted!"
# 	echo "$((FILENUM_SUM - DELETED_SUM)) ${2} OLD backup file(s) currently exist!"
# }

###################################################################
#                              clean_old()                        #
###################################################################
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
	if [ same_day -gt 1 ]; then clean_same_day; fi
	if [ num_days -gt 7 ]; then clean_day; fi
	if [ num_weeks -gt 4 ]; then clean_week; fi
	if [ num_months -gt 12 ]; then clean_month; fi
	
	echo $num_years $num_months $num_weeks $num_days $same_day
	cd $CURR_DIR
}
###################################################################
#                              main()                             #
###################################################################

# For every directory (to be backed up) configuration conducts a
# configuration check and calls check_backups function.
main() {
	check_config
	for tok in ${TOKENS[@]}; do
		echo BACKING UP ${tok}
		conduct_backup ${tok}
	done
	tar -C $BACKUPS_DIR/.. -czvf $BACKUPS_DIR/../$TIMESTAMP.tgz $TIMESTAMP
	rm -rf $BACKUPS_DIR
	clean_old
}


main
#clean_old
