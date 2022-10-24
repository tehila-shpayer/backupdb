void setBuildStatus(String message, String state, String gitUrl) {
    step([
        $class: "GitHubCommitStatusSetter",
        reposSource: [$class: "ManuallyEnteredRepositorySource", url: gitUrl],
        contextSource: [$class: "ManuallyEnteredCommitContextSource", context: "ci/jenkins/build-status"],
        errorHandlers: [[$class: "ChangingBuildStatusErrorHandler", result: "UNSTABLE"]],
        statusResultSource: [$class: "ConditionalStatusResultSource", results: [[$class: "AnyBuildResult", message: message, state: state]]]
    ]);
}



pipeline
{
	agent {label "Minnie"} 
	options {
    		skipDefaultCheckout true
  	}

	environment {
		//setup properly the variables below that will be used in this script
		DEPLOY_SERVER = 'Minnie'
		PM2_NAME = 'checkin-t'
		DOMAIN_NAME = 'checkin-t.carmel6000.com'
		NODE_ENV = ''
		CI=false
		PORT=8250
		CARMEL_SUBDOMAIN = 'checkin-t'
		RUN_NODENV = 'staging'
		
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
		sh 'node --version'
                //put here all the required commands to build your project as per the example below
		sh '''
		  for client in client*; do
                     echo $client
		     cd $client
		     npm i
                     npm run build
                     cd ..
                  done
                   cd server
                   npm i 
                   npm run build
		   cd ..
                '''
//checking apache configuration and domain
		sh '''
		   SERVER_IP=`dig +short ${DEPLOY_SERVER}.carmel6000.com`
		   DOMAIN_IP=`dig +short ${DOMAIN_NAME}`
		   if [ "${SERVER_IP}" = "${DOMAIN_IP}" ]; then
		   echo IP ARE EQUAL
		   else
		        echo ERROR: Please check domain name and/or deployment server.
                        exit 1 # terminate and indicate error
		   fi
		'''
//configure APACHE
		script{
                        sh '''
                        if [ -f 'apache/conf' ]; then
                                cd apache
                                cp conf ${PM2_NAME}.conf
                                sed -i "s/localhost:PORT/localhost:${PORT}/g" ${PM2_NAME}.conf
				sed -i "s/LOGDIR/${PM2_NAME}/g" ${PM2_NAME}.conf
                                sed -i "s/SUBDOMAIN/${CARMEL_SUBDOMAIN}/g" ${PM2_NAME}.conf
                                sed -i "s/PM2_NAME/${PM2_NAME}/g" ${PM2_NAME}.conf
                   		if grep ${DOMAIN_NAME} ${PM2_NAME}.conf; then
                        		echo APACHE OK
                   		else
                        		echo ERROR with DOMAIN NAME not MATCHING APACHE configuration
					exit 1
                   		fi
                                cd ..
                                mv apache/${PM2_NAME}.conf /etc/apache2/sites-available
                                if [ ! -f /etc/apache2/sites-enabled/${PM2_NAME}.conf ]; then
                                        echo FILE NOT ENABLED
                                        sudo /usr/sbin/a2ensite ${PM2_NAME}.conf
                                fi
				if [ ! -d /var/log/apache2/${PM2_NAME} ]; then
					mkdir /var/log/apache2/${PM2_NAME}
				fi
                                if sudo /usr/sbin/apache2ctl -t; then
					sudo systemctl reload apache2
                                        echo SUCCEEDED
                                else
                                        echo ERROR!!!! APACHE HAS AN ERROR
					sudo /usr/sbin/a2dissite ${PM2_NAME}.conf
					exit 1
                                fi
                        else
				echo WARNING!!!! APACHE HAS NO CONFIGURATION IN GIT
			fi
                        '''

		}

//starting node server
		script{
		sh '''
		if [ -f server/.env.${RUN_NODENV} ]; then
		 sed -i "s/^PORT = .*$/PORT = ${PORT}/g" server/.env.production
		fi
		'''
			sh '''
for file in /etc/apache2/sites-enabled/*.conf
do
        echo $file
        if grep "ProxyPass.*localhost:" $file >tmp; then
	echo ""
	fi
        sed -i "s/[^0-9]*//g" tmp
        if read -r LPORT < tmp; then
        	echo $LPORT
	fi
        if grep -r ServerName $file > tmp; then
	echo ""
	fi
        sed -i '/^ *#/d' tmp
        sed -i '/^\t#/d' tmp
        sed -i "s/^ *ServerName *//" tmp
        sed -i "s/^\t*Servername *//" tmp
        sed -i 's/www\\.//' tmp
        if read -r LDOMAIN < tmp; then
	echo ""
	fi
        echo $LPORT $LDOMAIN
        if [ "$LPORT" = "$PORT" ]
        then
                if [ "$LDOMAIN" != "$DOMAIN_NAME" ]
                then
                        echo "ERROR The PORT you have chosen is ALREADY IN USE"
                        exit 1
                fi
        fi
done

			'''
		try {
				sh "pm2 status | grep \" ${PM2_NAME} \""
				sh "pm2 restart ${PM2_NAME}"
			} catch (err) {
				sh "export NODE_ENV=${RUN_NODENV}; cd server; pm2 start dist/main.js --name ${PM2_name}"
			}
		}
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
