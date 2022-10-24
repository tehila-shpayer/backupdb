void setBuildStatus(String message, String state, String gitUrl) {
    step([
        $class: "GitHubCommitStatusSetter",
        reposSource: [$class: "ManuallyEnteredRepositorySource", url: gitUrl],
        contextSource: [$class: "ManuallyEnteredCommitContextSource", context: "ci/jenkins/build-status"],
        errorHandlers: [[$class: "ChangingBuildStatusErrorHandler", result: "UNSTABLE"]],
        statusResultSource: [$class: "ConditionalStatusResultSource", results: [[$class: "AnyBuildResult", message: message, state: state]]]
    ]);
}


//git credentials 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
pipeline
{
	agent {label "Minnie"} 
	options {
    		skipDefaultCheckout true
  	}

	environment {
		//setup properly the variables below that will be used in this script
		DEPLOY_SERVER = 'Minnie'
		PM2_NAME = 'backupdb'
		// DOMAIN_NAME = 'checkin-t.carmel6000.com'
		// NODE_ENV = ''
		// CI=false
		// PORT=8250
		// CARMEL_SUBDOMAIN = 'checkin-t'
		// RUN_NODENV = 'staging'
		
	}
    stages       
    {
        stage('Build')
        {
		agent {
			node {
				label "${DEPLOY_SERVER}"
				customWorkspace "www/prod/${PM2_NAME}"
			}
                }
	        options {
        	        skipDefaultCheckout false
        	}

		steps
            	{
		//script debug
		script{
			sh '''
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
			'''
			
		}
// 		sh 'node --version'
//                 //put here all the required commands to build your project as per the example below
// 		sh '''
// 		  for client in client*; do
//                      echo $client
// 		     cd $client
// 		     npm i
//                      npm run build
//                      cd ..
//                   done
//                    cd server
//                    npm i 
//                    npm run build
// 		   cd ..
//                 '''
// //checking apache configuration and domain
// 		sh '''
// 		   SERVER_IP=`dig +short ${DEPLOY_SERVER}.carmel6000.com`
// 		   DOMAIN_IP=`dig +short ${DOMAIN_NAME}`
// 		   if [ "${SERVER_IP}" = "${DOMAIN_IP}" ]; then
// 		   echo IP ARE EQUAL
// 		   else
// 		        echo ERROR: Please check domain name and/or deployment server.
//                         exit 1 # terminate and indicate error
// 		   fi
// 		'''
// //configure APACHE
// 		script{
//                         sh '''
//                         if [ -f 'apache/conf' ]; then
//                                 cd apache
//                                 cp conf ${PM2_NAME}.conf
//                                 sed -i "s/localhost:PORT/localhost:${PORT}/g" ${PM2_NAME}.conf
// 				sed -i "s/LOGDIR/${PM2_NAME}/g" ${PM2_NAME}.conf
//                                 sed -i "s/SUBDOMAIN/${CARMEL_SUBDOMAIN}/g" ${PM2_NAME}.conf
//                                 sed -i "s/PM2_NAME/${PM2_NAME}/g" ${PM2_NAME}.conf
//                    		if grep ${DOMAIN_NAME} ${PM2_NAME}.conf; then
//                         		echo APACHE OK
//                    		else
//                         		echo ERROR with DOMAIN NAME not MATCHING APACHE configuration
// 					exit 1
//                    		fi
//                                 cd ..
//                                 mv apache/${PM2_NAME}.conf /etc/apache2/sites-available
//                                 if [ ! -f /etc/apache2/sites-enabled/${PM2_NAME}.conf ]; then
//                                         echo FILE NOT ENABLED
//                                         sudo /usr/sbin/a2ensite ${PM2_NAME}.conf
//                                 fi
// 				if [ ! -d /var/log/apache2/${PM2_NAME} ]; then
// 					mkdir /var/log/apache2/${PM2_NAME}
// 				fi
//                                 if sudo /usr/sbin/apache2ctl -t; then
// 					sudo systemctl reload apache2
//                                         echo SUCCEEDED
//                                 else
//                                         echo ERROR!!!! APACHE HAS AN ERROR
// 					sudo /usr/sbin/a2dissite ${PM2_NAME}.conf
// 					exit 1
//                                 fi
//                         else
// 				echo WARNING!!!! APACHE HAS NO CONFIGURATION IN GIT
// 			fi
//                         '''

// 		}

// //starting node server
// 		script{
// 		sh '''
// 		if [ -f server/.env.${RUN_NODENV} ]; then
// 		 sed -i "s/^PORT = .*$/PORT = ${PORT}/g" server/.env.production
// 		fi
// 		'''
// 			sh '''
// for file in /etc/apache2/sites-enabled/*.conf
// do
//         echo $file
//         if grep "ProxyPass.*localhost:" $file >tmp; then
// 	echo ""
// 	fi
//         sed -i "s/[^0-9]*//g" tmp
//         if read -r LPORT < tmp; then
//         	echo $LPORT
// 	fi
//         if grep -r ServerName $file > tmp; then
// 	echo ""
// 	fi
//         sed -i '/^ *#/d' tmp
//         sed -i '/^\t#/d' tmp
//         sed -i "s/^ *ServerName *//" tmp
//         sed -i "s/^\t*Servername *//" tmp
//         sed -i 's/www\\.//' tmp
//         if read -r LDOMAIN < tmp; then
// 	echo ""
// 	fi
//         echo $LPORT $LDOMAIN
//         if [ "$LPORT" = "$PORT" ]
//         then
//                 if [ "$LDOMAIN" != "$DOMAIN_NAME" ]
//                 then
//                         echo "ERROR The PORT you have chosen is ALREADY IN USE"
//                         exit 1
//                 fi
//         fi
// done

// 			'''
// 		try {
// 				sh "pm2 status | grep \" ${PM2_NAME} \""
// 				sh "pm2 restart ${PM2_NAME}"
// 			} catch (err) {
// 				sh "export NODE_ENV=${RUN_NODENV}; cd server; pm2 start dist/main.js --name ${PM2_name}"
// 			}
// 		}
		}
       }
    }
    
    post {
        success {
		script {
		def s = checkout scm;
   		setBuildStatus("Build succeeded", "SUCCESS", s.GIT_URL);
		}
        }
        failure {
                script {
                def s = checkout scm;
            	setBuildStatus("Build failed", "FAILURE", s.GIT_URL);
                }
        }
    }
}
