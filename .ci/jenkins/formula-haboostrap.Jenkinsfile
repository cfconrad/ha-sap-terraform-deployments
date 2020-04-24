/**
 * Run haboostrap formula in ci
 */

pipeline {
    agent { node { label 'sles-sap' } }

    environment {
        PR_MANAGER = '.ci/pr-manager'
        PR_CONTEXT = 'jenkins/shap-formula-test'
    }

    stages {
      stage('Git Clone') { steps {
            deleteDir()
            checkout([$class: 'GitSCM',
                      branches: [[name: "*/${env.BRANCH_NAME}"], [name: '*/master']],
                      doGenerateSubmoduleConfigurations: false,
                      extensions: [[$class: 'LocalBranch'],
                                   [$class: 'WipeWorkspace'],
                                   [$class: 'RelativeTargetDirectory', relativeTargetDir: 'ha-sap-terraform-deployments'],
                                   [$class: 'ChangelogToBranch', options: [compareRemote: "origin", compareTarget: "master"]]],
                      submoduleCfg: [],
                      userRemoteConfigs: [[refspec: '+refs/pull/*:refs/remotes/origin/pr/*',
                                           url: 'https://github.com/SUSE/ha-sap-terraform-deployments']]])

             dir("${WORKSPACE}/ha-sap-terraform-deployments") {
                sh(script: "git checkout ${BRANCH_NAME}", label: "Checkout PR Branch")
            }
        }}
        stage('Setting GitHub in-progress status') { steps {
            sh(script: "ls")
            sh(script: "${PR_MANAGER} update-pr-status ${GIT_COMMIT} ${PR_CONTEXT} 'pending'", label: "Sending pending status")
           } 
        }

        stage('Initialize terraform') { steps {
              sh(script: 'echo terraform init')
           } 
        }

        stage('Apply terraform') {
            steps {
                sh(script: 'echo terraform apply')
            }
        }
    }
    post {
        always {
            sh(script: "echo destroy terraform")
        }
        cleanup {
            dir("${WORKSPACE}@tmp") {
                deleteDir()
            }
            dir("${WORKSPACE}@script") {
                deleteDir()
            }
            dir("${WORKSPACE}@script@tmp") {
                deleteDir()
            }
            dir("${WORKSPACE}") {
                deleteDir()
            }
        }
    }
}
