pipeline {
    agent any
    
    tools {
        maven 'maven3'
        jdk 'jdk17'
    }
    
    environment {
        SCANNER_HOME = tool(name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation')
        IMAGE_TAG = "v${BUILD_NUMBER}"
        DOCKER_REGISTRY = "kishorkumarparoi"
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/boardgame"
        SONAR_TOKEN = credentials('sonar-token')
        NEXUS_URL = "http://3.235.232.192:8081"
        NEXUS_VERSION = "nexus3"
        NEXUS_REPOSITORY = "maven-snapshots"
        NEXUS_CREDENTIAL_ID = "nexus-cred"
        // KUBECONFIG = credentials('kubeconfig')
    }

    stages {
        stage('Git Checkout') {
            steps {
                echo "📦 Checking out source code..."
                git branch: 'main', 
                    credentialsId: 'git', 
                    url: 'https://github.com/KishorKumarParoi/Boardgame.git'
            }
        }

        stage('Compile') {
            steps {
                echo "🔨 Compiling Maven project..."
                sh 'mvn clean compile'
            }
        }
        
        stage('Unit Tests') {
            steps {
                echo "✅ Running unit tests..."
                sh 'mvn test'
            }
        }
        
        stage('Code Coverage') {
            steps {
                echo "📊 Running JaCoCo coverage..."
                sh 'mvn jacoco:report'
                publishHTML([
                    reportDir: 'target/site/jacoco',
                    reportFiles: 'index.html',
                    reportName: 'JaCoCo Coverage Report'
                ])
            }
        }
        
        stage('Trivy Filesystem Scan') {
            steps {
                echo "🔍 Scanning filesystem for vulnerabilities..."
                sh '''
                    trivy fs --format json -o fs-report.json . || true
                    trivy fs --format table -o fs-report.html . || true
                '''
                publishHTML([
                    reportDir: '.',
                    reportFiles: 'fs-report.html',
                    reportName: 'Trivy Filesystem Scan'
                ])
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                echo "🔬 Running SonarQube analysis..."
                withSonarQubeEnv('sonar-server') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=boardgame \
                        -Dsonar.projectName=boardgame \
                        -Dsonar.sources=src \
                        -Dsonar.java.binaries=target/classes \
                        -Dsonar.language=java \
                        -Dsonar.sourceEncoding=UTF-8
                    '''
                }
            }
        }
        
        stage('Quality Gate Check') {
            steps {
                echo "🚪 Waiting for SonarQube quality gate..."
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        
        stage('Maven Build') {
            steps {
                echo "📦 Building with Maven..."
                sh 'mvn clean package -DskipTests'
            }
        }
        
   stage('Publish to Nexus') {
    steps {
        echo "📤 Pushing artifacts to Nexus..."
        sh '''
            # Create Maven settings file with credentials
            mkdir -p ~/.m2
            cat > ~/.m2/settings.xml <<'SETTINGS_EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>maven-releases</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
    <server>
      <id>maven-snapshots</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
  </servers>
</settings>
SETTINGS_EOF

            # Deploy to Nexus
            mvn deploy -DskipTests
        '''
    }
}
        
        stage('Docker Build & Tag') {
            steps {
                echo "🐳 Building Docker image..."
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', url: 'https://index.docker.io/v1/') {
                        sh '''
                            docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                            docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
                            echo "Docker images built successfully"
                            docker images | grep boardgame
                        '''
                    }
                }
            }
        }
        
        stage('Trivy Image Scan') {
            steps {
                echo "🔍 Scanning Docker image for vulnerabilities..."
                sh '''
                    trivy image --format json -o image-report.json ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                    trivy image --format table -o image-report.html ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                '''
                publishHTML([
                    reportDir: '.',
                    reportFiles: 'image-report.html',
                    reportName: 'Trivy Image Scan'
                ])
            }
        }
        
        stage('Push Docker Image') {
            steps {
                echo "📤 Pushing image to Docker Hub..."
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', url: 'https://index.docker.io/v1/') {
                        sh '''
                            docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                            docker push ${DOCKER_IMAGE}:latest
                            echo "Docker image pushed successfully"
                        '''
                    }
                }
            }
        }
        
        stage('Update Deployment File in Boardgame'){
            steps{
                script{
                    withCredentials([usernamePassword(credentialsId: 'git', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                      sh '''
                        git clone https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/KishorKumarParoi/Boardgame.git
                        cd Boardgame
                        sed -i "s|kishorkumarparoi/boardgame:.*|kishorkumarparoi/boardgame:${IMAGE_TAG}|g" k8s/08-deploy.yaml
                        echo "Updated Deploy file"
                        cat k8s/08-deploy.yaml
                        git config user.name "KishorKumarParoi"
                        git config user.email "kishor.ruet.cse@gmail.com"
                        git add k8s/08-deploy.yaml
                        git commit -m "Update image tag to ${IMAGE_TAG}"
                        git push origin main
                        '''
                   }
                }
            }
        }
        
    //     stage('Deploy to Kubernetes') {
    //         steps {
    //             echo "☸️  Deploying to Kubernetes..."
    //             script {
    //                 withKubeConfig([credentialsId: 'kubeconfig']) {
    //                     sh '''
    //                         # Update image tag in deployment
    //                         sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|g" k8s/03-deployment.yaml
                            
    //                         # Create namespace if not exists
    //                         kubectl create namespace boardgame --dry-run=client -o yaml | kubectl apply -f -
                            
    //                         # Apply manifests
    //                         kubectl apply -f k8s/
                            
    //                         # Wait for rollout
    //                         kubectl rollout status deployment/boardgame-app -n boardgame --timeout=5m
                            
    //                         # Display deployment info
    //                         echo "========== Deployment Status =========="
    //                         kubectl get all -n boardgame
    //                         echo "========== Service Info =========="
    //                         kubectl get svc boardgame-service -n boardgame
    //                     '''
    //                 }
    //             }
    //         }
    //     }
        
    //     stage('Verify Deployment') {
    //         steps {
    //             echo "✅ Verifying deployment..."
    //             script {
    //                 withKubeConfig([credentialsId: 'kubeconfig']) {
    //                     sh '''
    //                         # Wait for pods to be ready
    //                         sleep 10
                            
    //                         # Check pod status
    //                         kubectl get pods -n boardgame
                            
    //                         # Get service endpoint
    //                         ENDPOINT=$(kubectl get svc boardgame-service -n boardgame -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    //                         echo "Application URL: http://$ENDPOINT"
                            
    //                         # Test health endpoint
    //                         kubectl run curl-test --image=curlimages/curl:latest -i --rm --restart=Never -- \
    //                           curl http://boardgame-app:8080 || true
    //                     '''
    //                 }
    //             }
    //         }
    //     }
    }
    
  post {
    success {
        echo "✅ Build succeeded! Sending success email..."
        emailext(
            subject: "✅ BUILD SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: '''
                <html>
                    <body style="font-family: Arial, sans-serif;">
                        <h2 style="color: green;">✅ Build Successful</h2>
                        <table border="1" cellpadding="10">
                            <tr><td><b>Job Name:</b></td><td>${JOB_NAME}</td></tr>
                            <tr><td><b>Build #:</b></td><td>${BUILD_NUMBER}</td></tr>
                            <tr><td><b>Status:</b></td><td style="color: green;"><b>SUCCESS</b></td></tr>
                            <tr><td><b>URL:</b></td><td><a href="${BUILD_URL}">${BUILD_URL}</a></td></tr>
                            <tr><td><b>Docker Image:</b></td><td>${DOCKER_IMAGE}:${IMAGE_TAG}</td></tr>
                        </table>
                        <p><i>Automated notification from Jenkins</i></p>
                    </body>
                </html>
            ''',
            to: "kishor.ruet.cse@gmail.com",
            mimeType: 'text/html',
            attachLog: false
        )
    }
    
    failure {
        echo "❌ Build failed! Sending failure email..."
        emailext(
            subject: "❌ BUILD FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: '''
                <html>
                    <body style="font-family: Arial, sans-serif;">
                        <h2 style="color: red;">❌ Build Failed</h2>
                        <table border="1" cellpadding="10">
                            <tr><td><b>Job Name:</b></td><td>${JOB_NAME}</td></tr>
                            <tr><td><b>Build #:</b></td><td>${BUILD_NUMBER}</td></tr>
                            <tr><td><b>Status:</b></td><td style="color: red;"><b>FAILED</b></td></tr>
                            <tr><td><b>Console:</b></td><td><a href="${BUILD_URL}console">View Logs</a></td></tr>
                        </table>
                        <p><i>Automated notification from Jenkins</i></p>
                    </body>
                </html>
            ''',
            to: "kishor.ruet.cse@gmail.com",
            mimeType: 'text/html',
            attachLog: true
        )
    }
    
    always {
        echo "🧹 Cleaning up workspace..."
        deleteDir()
    }
  }
}
