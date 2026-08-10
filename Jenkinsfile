/*
 * DevOps Project - Jenkins CI Pipeline
 * Architecture: 2-EC2 Setup
 *   EC2 1 (this server): Jenkins single-node - runs all pipeline stages
 *   EC2 2 (separate):   SonarQube - receives SAST scan requests
 * Registry: DockerHub (docker.io)
 * Stages: Gitleaks → Install → Tests → SonarQube → Trivy FS → Docker Build → Trivy Image → DockerHub Push → GitOps
 */
pipeline {
    // Single-node Jenkins - runs everything on the same server
    agent any

    tools {
        nodejs 'nodejs20'
    }

    environment {
        // DockerHub Configuration
        // Add in Jenkins: Manage Jenkins → Credentials → Global
        //   ID: dockerhub-creds  Kind: Username + Password
        //   Username: your DockerHub username
        //   Password: your DockerHub Access Token (NOT your password)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        DOCKERHUB_USERNAME    = "${DOCKERHUB_CREDENTIALS_USR}"
        APP_NAME              = 'devops-project'

        // DockerHub image names: username/repo-name
        // e.g. johndoe/devops-project-frontend
        FRONTEND_REPO     = "${DOCKERHUB_USERNAME}/${APP_NAME}-frontend"
        BACKEND_REPO      = "${DOCKERHUB_USERNAME}/${APP_NAME}-backend"

        // Image tag: git short SHA + build number (unique + traceable)
        IMAGE_TAG         = "${env.GIT_COMMIT?.take(8) ?: 'latest'}-${env.BUILD_NUMBER}"

        // AWS (still needed for EKS kubeconfig only, not for registry)
        AWS_REGION        = 'ap-south-1'

        // SonarQube - dedicated EC2
        // Jenkins credential: Kind=Secret text, ID=SONARQUBE_URL
        // Value: http://SONARQUBE_EC2_IP:9000
        SONARQUBE_URL     = credentials('SONARQUBE_URL')
        SCANNER_HOME      = tool 'sonar-scanner'
        SONAR_PROJECT_KEY = 'devops-project-3tier'

        // GitOps Repo
        GITOPS_REPO       = credentials('GITOPS_REPO_URL')
        GITOPS_BRANCH     = 'main'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        // ── Stage 1: Secret Scanning ────────────────────────────────
        stage('🔑 Gitleaks Secret Scan') {
            steps {
                script {
                    sh '''
                        echo "Running Gitleaks secret detection..."
                        gitleaks detect \
                            --source . \
                            --config .gitleaks.toml \
                            --report-format json \
                            --report-path gitleaks-report.json \
                            --exit-code 1 \
                            --redact \
                            --no-git
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
                failure {
                    error '[❌ SECURITY GATE] Gitleaks found secrets in codebase. Build aborted.'
                }
            }
        }

        // ── Stage 2: Install Dependencies ───────────────────────────
        stage('📦 Install Dependencies') {
            parallel {
                stage('Backend Deps') {
                    steps {
                        dir('api') { sh 'npm ci' }
                    }
                }
                stage('Frontend Deps') {
                    steps {
                        dir('client') { sh 'npm ci' }
                    }
                }
            }
        }

        // ── Stage 3: Unit Tests ──────────────────────────────────
        stage('🧪 Unit Tests') {
            steps {
                dir('api') {
                    sh '''
                        export JWT_SECRET="ci-test-secret-key-minimum-32-chars"
                        export DB_HOST=localhost DB_USER=test DB_PASSWORD=test DB_NAME=test
                        npm run test:ci || true
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'api/junit.xml'
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'api/coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        // ── Stage 4: SonarQube SAST ──────────────────────────────
        stage('🔍 SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        ${SCANNER_HOME}/bin/sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.sources=api/controllers,api/middleware,api/models,api/routes,api/app.js,client/src \
                            -Dsonar.tests=api/tests \
                            -Dsonar.javascript.lcov.reportPaths=api/coverage/lcov.info \
                            -Dsonar.exclusions="**/node_modules/**,**/coverage/**,**/build/**"
                    '''
                }
            }
        }

        stage('✅ SonarQube Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── Stage 5: Trivy Filesystem Scan ────────────────────────
        stage('🛡️ Trivy Filesystem Scan') {
            steps {
                sh '''
                    trivy fs . \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --ignore-unfixed \
                        --output trivy-fs-report.txt
                    cat trivy-fs-report.txt
                    # Fail on CRITICAL only
                    trivy fs . \
                        --exit-code 1 \
                        --severity CRITICAL \
                        --ignore-unfixed \
                        --quiet
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: true
                }
            }
        }

        // ── Stage 6: Docker Build ────────────────────────────────
        stage('🐳 Build Docker Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        sh '''
                            docker build \
                                --build-arg REACT_APP_API_URL=https://api.${APP_NAME}.yourdomain.com \
                                -t ${FRONTEND_REPO}:${IMAGE_TAG} \
                                -t ${FRONTEND_REPO}:latest \
                                ./client
                        '''
                    }
                }
                stage('Build Backend') {
                    steps {
                        sh '''
                            docker build \
                                -t ${BACKEND_REPO}:${IMAGE_TAG} \
                                -t ${BACKEND_REPO}:latest \
                                ./api
                        '''
                    }
                }
            }
        }

        // ── Stage 7: Trivy Image Scan ────────────────────────────
        stage('🔬 Trivy Image Scan') {
            parallel {
                stage('Scan Frontend Image') {
                    steps {
                        sh '''
                            trivy image \
                                --exit-code 0 \
                                --severity HIGH,CRITICAL \
                                --format table \
                                --output trivy-frontend-image.txt \
                                ${FRONTEND_REPO}:${IMAGE_TAG}
                            cat trivy-frontend-image.txt
                            trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed ${FRONTEND_REPO}:${IMAGE_TAG}
                        '''
                    }
                    post {
                        always { archiveArtifacts artifacts: 'trivy-frontend-image.txt', allowEmptyArchive: true }
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh '''
                            trivy image \
                                --exit-code 0 \
                                --severity HIGH,CRITICAL \
                                --format table \
                                --output trivy-backend-image.txt \
                                ${BACKEND_REPO}:${IMAGE_TAG}
                            cat trivy-backend-image.txt
                            trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed ${BACKEND_REPO}:${IMAGE_TAG}
                        '''
                    }
                    post {
                        always { archiveArtifacts artifacts: 'trivy-backend-image.txt', allowEmptyArchive: true }
                    }
                }
            }
        }

        // ── Stage 8: Push to DockerHub ───────────────────────────
        stage('🐋 Push to DockerHub') {
            steps {
                sh '''
                    echo "Logging in to DockerHub..."
                    echo "${DOCKERHUB_CREDENTIALS_PSW}" | docker login \
                        --username "${DOCKERHUB_USERNAME}" \
                        --password-stdin

                    echo "Pushing frontend image..."
                    docker push ${FRONTEND_REPO}:${IMAGE_TAG}
                    docker push ${FRONTEND_REPO}:latest

                    echo "Pushing backend image..."
                    docker push ${BACKEND_REPO}:${IMAGE_TAG}
                    docker push ${BACKEND_REPO}:latest

                    echo "✅ Images pushed to DockerHub:"
                    echo "   docker.io/${FRONTEND_REPO}:${IMAGE_TAG}"
                    echo "   docker.io/${BACKEND_REPO}:${IMAGE_TAG}"

                    docker logout
                '''
            }
        }

        // ── Stage 9: Update GitOps Repo ──────────────────────────
        stage('🔄 Update GitOps Repo') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-gitops-creds',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        rm -rf /tmp/gitops
                        git clone https://${GIT_USER}:${GIT_TOKEN}@$(echo ${GITOPS_REPO} | sed 's|https://||') /tmp/gitops
                        cd /tmp/gitops

                        # Update frontend image tag
                        sed -i "s|image: ${FRONTEND_REPO}:.*|image: ${FRONTEND_REPO}:${IMAGE_TAG}|g" \
                            apps/frontend/deployment.yaml

                        # Update backend image tag
                        sed -i "s|image: ${BACKEND_REPO}:.*|image: ${BACKEND_REPO}:${IMAGE_TAG}|g" \
                            apps/backend/deployment.yaml

                        git config user.email "jenkins@devops-project.com"
                        git config user.name  "Jenkins CI"

                        git add apps/frontend/deployment.yaml apps/backend/deployment.yaml

                        if ! git diff --cached --quiet; then
                            git commit -m "ci: update images to ${IMAGE_TAG} [skip ci]"
                            git push origin ${GITOPS_BRANCH}
                            echo "✅ GitOps repo updated with tag ${IMAGE_TAG}"
                        else
                            echo "ℹ️ No image tag changes detected"
                        fi

                        rm -rf /tmp/gitops
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline PASSED - Image Tag: ${IMAGE_TAG}"
        }
        failure {
            echo "❌ Pipeline FAILED at stage: ${env.STAGE_NAME}"
        }
        always {
            // Cleanup local Docker images
            sh '''
                docker rmi ${FRONTEND_REPO}:${IMAGE_TAG} || true
                docker rmi ${BACKEND_REPO}:${IMAGE_TAG}  || true
                docker system prune -f || true
            '''
        }
    }
}
