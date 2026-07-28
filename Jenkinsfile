pipeline {
    agent { label 'docker-agent' }
   
    environment {
        IMAGE_NAME = 'mattiaangelone/flask-app-example'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:latest", "./flask-app")
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                        dockerImage.push('latest')
                    } 
                }
            }
        }
    }
}            
