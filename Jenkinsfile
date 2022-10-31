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
        stage('Build') {
		agent {
			node {
				label "${DEPLOY_SERVER}"
				customWorkspace "www/prod/${PM2_NAME}"
			}
                }
	        options {
        	        skipDefaultCheckout false
        	}

		steps {
			script{
				sh '''#!/bin/bash
				./script.sh
				'''
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
