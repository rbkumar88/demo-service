/*
 * Quick Reference: https://jenkins.io/doc/book/pipeline/syntax/
 */
def img
def imgTags
pipeline {
    agent any
    options {
        disableConcurrentBuilds()
        skipStagesAfterUnstable()
    }
    stages {
        stage('Pre Build Check') {
            steps {
                script {
                    def mvn_model = readMavenPom file: 'pom.xml'
                    env.PROJ_MVN_VERSION = mvn_model.getVersion();
                    env.PROJ_MVN_ARTIFACT_ID = mvn_model.getArtifactId();
                    env.PROJ_PACKAGING = mvn_model.getPackaging();
                    
                    env.SERVICE_ID = 'demo-service'
                }
            }
        }
        
        stage('Build / Unit Test') {
            steps {
                // https://wiki.jenkins.io/display/JENKINS/Pipeline+Maven+Plugin
                withMaven(
                    // jdk: buildJdk, 
                    // maven: buildMvn, 
                    mavenSettingsConfig: 'portal-mvn-deploy-settings',
                    mavenLocalRepo: '.repository', 
                    options:[
                        artifactsPublisher(disabled: false),
                        junitPublisher(ignoreAttachments: false),
                        dependenciesFingerprintPublisher(),
                        invokerPublisher(),
                        pipelineGraphPublisher(),
                        openTasksPublisher(disabled: true),
                        findbugsPublisher(disabled: true),
                        concordionPublisher(disabled: true),
                        jgivenPublisher(disabled: true)
                    ]) {
                        // withMaven does -B and -V
                        // DO NOT clean here, or built npm modules will go away
                        sh "mvn verify -U -e -fae"
                }
            }
        }

        stage('Docker Image Build') {
            // TODO For services, add a docker package stage here.
            steps {
                script {
                    env.SHORT_COMMIT = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
                    img = docker.build("connect-portal/demo-service", ('-f Dockerfile --build-arg VERSION='+ env.PROJ_MVN_VERSION + 
                        ' --build-arg ARTIFACT_ID=' + env.PROJ_MVN_ARTIFACT_ID + 
                        ' .'))
                }
            }
        }

        stage('Deploy to Nexus') {
            when {
                not { expression { return params.skip_deploy } }
            }
            steps {
                // See https://issues.jenkins-ci.org/browse/JENKINS-38963
                // ithCredentials([usernamePassword(credentialsId: 'Connect-portal-nexus-maven', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USERNAME')]) {
                    // Try deploying to Nexus
                    withMaven(
                        // jdk: buildJdk,
                        // maven: buildMvn,
                        mavenSettingsConfig: 'portal-mvn-deploy-settings',
                        mavenLocalRepo: '.repository',
                        options:[
                            artifactsPublisher(disabled: false),
                            dependenciesFingerprintPublisher(),
                            pipelineGraphPublisher(),
                            junitPublisher(disabled: true),
                            invokerPublisher(disabled: true),
                            openTasksPublisher(disabled: true),
                            findbugsPublisher(disabled: true),
                            concordionPublisher(disabled: true),
                            jgivenPublisher(disabled: true)
                        ]) {
                            // See https://issues.apache.org/jira/browse/MDEPLOY-124, this steps builds again anyways,
                            // hence using skipTests to save time
                            sh "mvn deploy -e -ff -DskipTests -Dskip.npm"
                        }
                //}

                script {
                    // Tag and Push Image to Nexus Repo
                    docker.withRegistry("${env.DOCKER_REGISTRY}",'NEXUS-REPO-CREDENTIALS') {
                        env.IMG_TAG = env.PROJ_MVN_VERSION + '-' + env.SHORT_COMMIT
                        imgTags = [env.IMG_TAG, 'latest']
                        imgTags.each {
                            img.push(it)    
                        }
                    }
                }
            }
        }

        stage('OSE Deploy') {
            steps {
                openshiftDeploy apiURL: "$env.OSE_API_URL", 
                    authToken: "$env.OSE_AUTH_TOKEN", 
                    depCfg: "$env.SERVICE_ID", 
                    namespace: "$env.OSE_NAMESPACE", 
                    verbose: 'false', 
                    waitTime: "$env.DEPLOY_WAIT_TIME", 
                    waitUnit: 'sec'
            }
        }
    }
    post {
        always {
            script {
                // Wrapping in script to be able to ignore the delete dir failure
                try {
                    deleteDir() /* clean up our workspace */
                } catch (e) {
                    // Delete might fail - don't fail the build
                    echo "Error deleting workspace[${pwd()}] post build."
                }
            }
        }
        success {
             echo 'Build Succeeded!'
             mail(to: "${env.RECIPIENT_LIST}",
                    subject: "Build Deployed: [${env.ENVIRONMENT}] ${env.JOB_NAME.split('/')[3]}/${env.JOB_BASE_NAME} ${env.BUILD_DISPLAY_NAME}",
                    body: ("URL: ${currentBuild.absoluteUrl}\n" +
                            "Branch: ${env.BRANCH_NAME}\n" +
                            "Artifact Version: ${env.PROJ_MVN_VERSION}\n" +
                            "Docker Image Tags: ${imgTags == null ? 'N/A' : imgTags.join(', ')}\n" +
                            "\nIs Release Build: ${params.release_build ? 'Yes' : 'No'}"))
        }
        failure {
            echo 'Build Failed!'
            mail(to: "${env.RECIPIENT_LIST}",
                    subject: "Build Failure: [${env.ENVIRONMENT}] ${env.JOB_NAME.split('/')[3]}/${env.JOB_BASE_NAME} ${env.BUILD_DISPLAY_NAME}",
                    body: ("URL: ${currentBuild.absoluteUrl}\n" +
                            "Branch: ${env.BRANCH_NAME}\n" +
                            "Artifact Version: ${env.PROJ_MVN_VERSION}\n" +
                            "Docker Image Tags: ${imgTags == null ? 'N/A' : imgTags.join(', ')}\n" +
                            "\nIs Release Build: ${params.release_build ? 'Yes' : 'No'}"))
        }
    }
}
