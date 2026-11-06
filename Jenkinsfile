pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        REGISTRY   = '685222357201.dkr.ecr.ap-south-1.amazonaws.com'
        EC2_HOST   = '43.204.227.194'
        SERVICES   = 'user-service product-service order-service'
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "v1.0.${env.BUILD_NUMBER}-${shortSha}"
                }
                echo "Image tag for this build: ${env.IMAGE_TAG}"
            }
        }

        stage('Build') {
            steps {
                sh '''
                    for s in $SERVICES; do
                        docker build -t $REGISTRY/$s:$IMAGE_TAG ./$s
                    done
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    for s in $SERVICES; do
                        echo "Testing $s..."
                        docker run --rm $REGISTRY/$s:$IMAGE_TAG python -c "import app; print('$s OK')"
                    done
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-creds',
                                                  usernameVariable: 'AWS_ACCESS_KEY_ID',
                                                  passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY
                        for s in $SERVICES; do
                            docker push $REGISTRY/$s:$IMAGE_TAG
                        done
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key',
                                                   keyFileVariable: 'SSH_KEY',
                                                   usernameVariable: 'SSH_USER')]) {
                    sh '''
                        SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"
                        ssh $SSH_OPTS $SSH_USER@$EC2_HOST "mkdir -p /opt/app/nginx /opt/app/monitoring"
                        scp $SSH_OPTS deploy/docker-compose.prod.yml deploy/deploy.sh $SSH_USER@$EC2_HOST:/opt/app/
                        scp $SSH_OPTS nginx/default.conf $SSH_USER@$EC2_HOST:/opt/app/nginx/
                        scp $SSH_OPTS monitoring/prometheus.yml monitoring/grafana-datasource.yml $SSH_USER@$EC2_HOST:/opt/app/monitoring/
                        ssh $SSH_OPTS $SSH_USER@$EC2_HOST "sed -i 's/\\r$//' /opt/app/deploy.sh && bash /opt/app/deploy.sh $IMAGE_TAG $REGISTRY"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    for i in $(seq 1 12); do
                        if curl -fsS http://$EC2_HOST/api/orders; then
                            echo ""
                            echo "Health check passed"
                            exit 0
                        fi
                        echo "Waiting for app... ($i/12)"
                        sleep 5
                    done
                    echo "Health check FAILED"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "Deployed ${env.IMAGE_TAG} to http://${env.EC2_HOST}"
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
    }
}