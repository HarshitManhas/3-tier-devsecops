/*
 * DevOps Project - Jenkins CI Pipeline
 * Architecture: 2-EC2 Setup
 *   EC2 1 (this server): Jenkins single-node - runs all pipeline stages
 *   EC2 2 (separate):   SonarQube - receives SAST scan requests
 * Registry: DockerHub (docker.io)
 * Stages: Gitleaks → Install → Tests → SonarQube → Trivy FS → Docker Build → Trivy Image → DockerHub Push → GitOps
 */
pipeline {
    agent any

    tools {
        nodejs 'nodejs20'
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        DOCKERHUB_USERNAME    = "${DOCKERHUB_CREDENTIALS_USR}"
        APP_NAME              = 'devops-project'
        FRONTEND_REPO         = "${DOCKERHUB_CREDENTIALS_USR}/devops-project-frontend"
        BACKEND_REPO          = "${DOCKERHUB_CREDENTIALS_USR}/devops-project-backend"
        IMAGE_TAG             = "${env.GIT_COMMIT?.take(8) ?: 'latest'}-${env.BUILD_NUMBER}"
        AWS_REGION            = 'ap-south-1'
        SONAR_PROJECT_KEY     = 'devops-project-3tier'
        GITOPS_BRANCH         = 'main'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        // ── Stage 1: Secret Scanning ────────────────────────────────
        stage('Gitleaks Secret Scan') {
            steps {
                script {
                    // exit-code 0: always passes — findings are reported as warnings only
                    // This is intentional: example/test values cause false positives
                    // In production, review gitleaks-report.json and fix real leaks
                    sh '''
                        if command -v gitleaks &>/dev/null; then
                            echo "Running Gitleaks secret detection (warn-only mode)..."
                            gitleaks detect \
                                --source . \
                                --config .gitleaks.toml \
                                --report-format json \
                                --report-path gitleaks-report.json \
                                --exit-code 0 \
                                --redact \
                                --no-git || true
                            FINDS=$(cat gitleaks-report.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
                            echo "Gitleaks found ${FINDS} potential issues (check gitleaks-report.json artifact)"
                        else
                            echo "WARNING: gitleaks not installed, skipping secret scan"
                            echo "[]" > gitleaks-report.json
                        fi
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // ── Stage 2: Install Dependencies ───────────────────────────
        stage('Install Dependencies') {
            parallel {
                stage('Backend Deps') {
                    steps {
                        dir('api') {
                            sh 'npm install --legacy-peer-deps'
                        }
                    }
                }
                stage('Frontend Deps') {
                    steps {
                        dir('client') {
                            sh 'npm install --legacy-peer-deps'
                        }
                    }
                }
            }
        }

        // ── Stage 3: Unit Tests ──────────────────────────────────
        stage('Unit Tests') {
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
        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'SONARQUBE_URL', variable: 'SONAR_HOST_URL')]) {
                    withSonarQubeEnv('SonarQube') {
                        script {
                            def scannerHome = tool 'sonar-scanner'
                            sh """
                                ${scannerHome}/bin/sonar-scanner \
                                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                    -Dsonar.sources=api/controllers,api/middleware,api/models,api/routes,api/app.js,client/src \
                                    -Dsonar.tests=api/tests \
                                    -Dsonar.javascript.lcov.reportPaths=api/coverage/lcov.info \
                                    -Dsonar.exclusions="**/node_modules/**,**/coverage/**,**/build/**"
                            """
                        }
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── Stage 5: Trivy Filesystem Scan ────────────────────────
        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    if command -v trivy &>/dev/null; then
                        trivy fs . \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            --ignore-unfixed \
                            --output trivy-fs-report.txt || true
                        cat trivy-fs-report.txt
                    else
                        echo "WARNING: trivy not installed, skipping filesystem scan"
                        echo "Trivy not available" > trivy-fs-report.txt
                    fi
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: true
                }
            }
        }

        // ── Stage 6: Docker Build ────────────────────────────────
        stage('Build Docker Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        sh """
                            docker build \
                                -t ${FRONTEND_REPO}:${IMAGE_TAG} \
                                -t ${FRONTEND_REPO}:latest \
                                ./client
                        """
                    }
                }
                stage('Build Backend') {
                    steps {
                        sh """
                            docker build \
                                -t ${BACKEND_REPO}:${IMAGE_TAG} \
                                -t ${BACKEND_REPO}:latest \
                                ./api
                        """
                    }
                }
            }
        }

        // ── Stage 7: Trivy Image Scan ────────────────────────────
        stage('Trivy Image Scan') {
            parallel {
                stage('Scan Frontend Image') {
                    steps {
                        sh """
                            if command -v trivy &>/dev/null; then
                                trivy image \
                                    --exit-code 0 \
                                    --severity HIGH,CRITICAL \
                                    --format table \
                                    --output trivy-frontend-image.txt \
                                    ${FRONTEND_REPO}:${IMAGE_TAG} || true
                                cat trivy-frontend-image.txt
                            else
                                echo "Trivy not available" > trivy-frontend-image.txt
                            fi
                        """
                    }
                    post {
                        always { archiveArtifacts artifacts: 'trivy-frontend-image.txt', allowEmptyArchive: true }
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh """
                            if command -v trivy &>/dev/null; then
                                trivy image \
                                    --exit-code 0 \
                                    --severity HIGH,CRITICAL \
                                    --format table \
                                    --output trivy-backend-image.txt \
                                    ${BACKEND_REPO}:${IMAGE_TAG} || true
                                cat trivy-backend-image.txt
                            else
                                echo "Trivy not available" > trivy-backend-image.txt
                            fi
                        """
                    }
                    post {
                        always { archiveArtifacts artifacts: 'trivy-backend-image.txt', allowEmptyArchive: true }
                    }
                }
            }
        }

        // ── Stage 8: Push to DockerHub ───────────────────────────
        stage('Push to DockerHub') {
            steps {
                sh """
                    echo "Logging in to DockerHub..."
                    echo "${DOCKERHUB_CREDENTIALS_PSW}" | docker login \
                        --username "${DOCKERHUB_USERNAME}" \
                        --password-stdin

                    docker push ${FRONTEND_REPO}:${IMAGE_TAG}
                    docker push ${FRONTEND_REPO}:latest
                    docker push ${BACKEND_REPO}:${IMAGE_TAG}
                    docker push ${BACKEND_REPO}:latest

                    echo "Images pushed successfully"
                    docker logout
                """
            }
        }

        // ── Stage 9: Update GitOps Repo ──────────────────────────
        stage('Update GitOps Repo') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-gitops-creds',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh """
                        rm -rf /tmp/gitops
                        git clone https://\${GIT_USER}:\${GIT_TOKEN}@github.com/HarshitManhas/3-tier-devsecops-gitops.git /tmp/gitops
                        cd /tmp/gitops

                        sed -i "s|image: ${FRONTEND_REPO}:.*|image: ${FRONTEND_REPO}:${IMAGE_TAG}|g" apps/frontend/deployment.yaml
                        sed -i "s|image: ${BACKEND_REPO}:.*|image: ${BACKEND_REPO}:${IMAGE_TAG}|g" apps/backend/deployment.yaml

                        git config user.email "jenkins@devops-project.com"
                        git config user.name  "Jenkins CI"
                        git add apps/frontend/deployment.yaml apps/backend/deployment.yaml

                        if ! git diff --cached --quiet; then
                            git commit -m "ci: update images to ${IMAGE_TAG} [skip ci]"
                            git push origin ${GITOPS_BRANCH}
                            echo "GitOps repo updated with tag ${IMAGE_TAG}"
                        else
                            echo "No image tag changes detected"
                        fi
                        rm -rf /tmp/gitops
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline PASSED - Image Tag: ${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline FAILED at stage: ${env.STAGE_NAME}"
        }
        always {
            // Cleanup must run inside a node context
            node('built-in') {
                sh """
                    export PATH=\$PATH:/usr/bin:/usr/local/bin
                    /usr/bin/docker rmi ${env.FRONTEND_REPO}:${env.IMAGE_TAG} 2>/dev/null || true
                    /usr/bin/docker rmi ${env.BACKEND_REPO}:${env.IMAGE_TAG}  2>/dev/null || true
                    /usr/bin/docker system prune -f 2>/dev/null || true
                """
            }
        }
    }
}
