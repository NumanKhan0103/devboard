pipeline{
    agent any
    environment {
    DOCKER_NS  = "numankhan03404619940"
    // BACKEND_IMG  = "${DOCKER_NS}/devboard-backend:${BUILD_NUMBER}"
    // FRONTEND_IMG = "${DOCKER_NS}/devboard-frontend:${BUILD_NUMBER}"
}
    stages{
        stage("Code"){
            steps{
                echo "Code cloning"
                git url: "https://github.com/NumanKhan0103/devboard.git", branch: "master"
            }
        }
        stage("Login"){
            steps{
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                usernameVariable: 'DOCKER_USER',
                passwordVariable: 'DOCKER_PASS'
                )]){
                    sh '''
                        set +x
                        echo "$DOCKER_PASS" | docker login dhi.io -u "$DOCKER_USER" --password-stdin
                    '''
                }
            }
        }
        stage("Build"){
            parallel{
                // failFast true
                stage("Backend"){
                    steps{
                        sh "docker build -t ${DOCKER_NS}/devboard-backend ./backend"
                    }
                }
                stage("Frontend"){
                    steps{
                        sh "docker build -t ${DOCKER_NS}/devboard-frontend ./frontend"
                    }
                }
            }
        }
        stage("Test"){
           steps{
                echo "Tesing"
            } 
        }
        stage("Docker Hub Push"){
            steps{
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                 usernameVariable: 'DOCKER_USER',
                                 passwordVariable: 'DOCKER_PASS')]) {
                     
                    // Login to Docker Hub                
                    sh 'set +x; echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                
                    // push to Docker Hub
                    sh "docker push ${DOCKER_USER}/devboard-backend:latest"
                    sh "docker push ${DOCKER_USER}/devboard-frontend:latest"
                    }
            }
        }
        stage("Deploy"){
            steps{
                echo "Docker compose to deploy"
            }
        }
    }
    
    post {
        always {
            sh "docker logout dhi.io || true"
            sh "docker logout || true"
        }
    }
}