import os

base_dir = r"C:\Users\harsh\.gemini\antigravity\scratch\3-tier-devsecops"

files = [
    (r"ansible\inventory\hosts.yml", r'''---
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/your-key.pem
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  hosts:
    jenkins:
      ansible_host: "{{ lookup('env', 'JENKINS_IP') | default('REPLACE_WITH_JENKINS_IP') }}"
      # Get IP from: terraform output jenkins_public_ip'''),
    
    (r"ansible\playbooks\tools-setup.yml", r'''---
# Installs all DevSecOps tools on Jenkins server
- name: Install DevSecOps Tools
  hosts: jenkins
  become: true
  gather_facts: true

  vars:
    trivy_version: "0.50.1"
    gitleaks_version: "8.18.2"
    kubectl_version: "1.29.0"
    helm_version: "3.14.3"
    nodejs_version: "20"

  tasks:
    # ── System Prerequisites ─────────────────────────────────────
    - name: Update apt cache
      apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Install prerequisite packages
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
          - git
          - unzip
          - jq
          - python3-pip
          - python3-boto3
        state: present

    # ── Docker ─────────────────────────────────────────────────
    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker CE
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-buildx-plugin
          - docker-compose-plugin
        state: present

    - name: Add jenkins user to docker group
      user:
        name: jenkins
        groups: docker
        append: true

    - name: Start and enable Docker service
      systemd:
        name: docker
        state: started
        enabled: true

    # ── AWS CLI v2 ──────────────────────────────────────────────
    - name: Download AWS CLI v2
      get_url:
        url: https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
        dest: /tmp/awscliv2.zip
        mode: '0644'

    - name: Unzip AWS CLI
      unarchive:
        src: /tmp/awscliv2.zip
        dest: /tmp/
        remote_src: true

    - name: Install AWS CLI
      command: /tmp/aws/install --update
      args:
        creates: /usr/local/bin/aws

    # ── kubectl ────────────────────────────────────────────────
    - name: Download kubectl
      get_url:
        url: "https://dl.k8s.io/release/v{{ kubectl_version }}/bin/linux/amd64/kubectl"
        dest: /usr/local/bin/kubectl
        mode: '0755'

    # ── Helm ───────────────────────────────────────────────────
    - name: Download Helm
      get_url:
        url: "https://get.helm.sh/helm-v{{ helm_version }}-linux-amd64.tar.gz"
        dest: /tmp/helm.tar.gz
        mode: '0644'

    - name: Extract Helm
      unarchive:
        src: /tmp/helm.tar.gz
        dest: /tmp/
        remote_src: true

    - name: Install Helm
      copy:
        src: /tmp/linux-amd64/helm
        dest: /usr/local/bin/helm
        mode: '0755'
        remote_src: true

    # ── Trivy ──────────────────────────────────────────────────
    - name: Download Trivy
      get_url:
        url: "https://github.com/aquasecurity/trivy/releases/download/v{{ trivy_version }}/trivy_{{ trivy_version }}_Linux-64bit.deb"
        dest: /tmp/trivy.deb
        mode: '0644'

    - name: Install Trivy
      apt:
        deb: /tmp/trivy.deb
        state: present

    # ── Gitleaks ──────────────────────────────────────────────
    - name: Download Gitleaks
      get_url:
        url: "https://github.com/gitleaks/gitleaks/releases/download/v{{ gitleaks_version }}/gitleaks_{{ gitleaks_version }}_linux_x64.tar.gz"
        dest: /tmp/gitleaks.tar.gz
        mode: '0644'

    - name: Extract and install Gitleaks
      unarchive:
        src: /tmp/gitleaks.tar.gz
        dest: /usr/local/bin/
        remote_src: true
        include:
          - gitleaks

    - name: Set Gitleaks permissions
      file:
        path: /usr/local/bin/gitleaks
        mode: '0755'

    # ── Node.js ───────────────────────────────────────────────
    - name: Add NodeSource repository
      shell: |
        curl -fsSL https://deb.nodesource.com/setup_{{ nodejs_version }}.x | bash -
      args:
        creates: /usr/bin/node

    - name: Install Node.js
      apt:
        name: nodejs
        state: present

    # ── Verify all installations ──────────────────────────────
    - name: Verify all tools
      shell: |
        echo "Docker: $(docker --version)"
        echo "AWS CLI: $(aws --version)"
        echo "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        echo "Helm: $(helm version --short)"
        echo "Trivy: $(trivy --version)"
        echo "Gitleaks: $(gitleaks version)"
        echo "Node.js: $(node --version)"
      register: tool_versions
      changed_when: false

    - name: Print tool versions
      debug:
        msg: "{{ tool_versions.stdout_lines }}"'''),

    (r"ansible\playbooks\jenkins-setup.yml", r'''---
# Install and configure Jenkins LTS
- name: Install Jenkins
  hosts: jenkins
  become: true
  gather_facts: true

  vars:
    jenkins_plugins:
      - git
      - workflow-aggregator
      - pipeline-stage-view
      - docker-workflow
      - docker-plugin
      - aws-credentials
      - pipeline-aws
      - sonar
      - nodejs
      - junit
      - htmlpublisher
      - credentials-binding
      - build-timeout
      - timestamper
      - ws-cleanup
      - github
      - slack

  tasks:
    - name: Add Jenkins GPG key
      apt_key:
        url: https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
        state: present

    - name: Add Jenkins repository
      apt_repository:
        repo: "deb https://pkg.jenkins.io/debian-stable binary/"
        state: present
        filename: jenkins

    - name: Install Java 17 (Jenkins dependency)
      apt:
        name: openjdk-17-jdk
        state: present
        update_cache: true

    - name: Install Jenkins
      apt:
        name: jenkins
        state: present
        update_cache: true

    - name: Start and enable Jenkins
      systemd:
        name: jenkins
        state: started
        enabled: true

    - name: Wait for Jenkins to start
      wait_for:
        port: 8080
        host: localhost
        delay: 10
        timeout: 120

    - name: Get initial admin password
      command: cat /var/lib/jenkins/secrets/initialAdminPassword
      register: jenkins_password
      changed_when: false

    - name: Display initial admin password
      debug:
        msg: "Jenkins initial admin password: {{ jenkins_password.stdout }}"

    - name: Install Jenkins plugins via CLI
      command: |
        java -jar /var/cache/jenkins/war/WEB-INF/lib/cli-*.jar \
          -s http://localhost:8080 \
          -auth admin:{{ jenkins_password.stdout }} \
          install-plugin {{ item }} -deploy
      loop: "{{ jenkins_plugins }}"
      ignore_errors: true

    - name: Allow Jenkins to use Docker socket
      file:
        path: /var/run/docker.sock
        group: docker
        mode: '0666'

    - name: Restart Jenkins after plugin install
      systemd:
        name: jenkins
        state: restarted'''),

    (r"ansible\playbooks\sonarqube-setup.yml", r'''---
# Install SonarQube via Docker on Jenkins server
- name: Setup SonarQube
  hosts: jenkins
  become: true
  gather_facts: true

  vars:
    sonarqube_version: "10.4-community"
    sonarqube_port: 9000

  tasks:
    - name: Set vm.max_map_count for SonarQube (Elasticsearch requirement)
      sysctl:
        name: vm.max_map_count
        value: '262144'
        state: present
        reload: true

    - name: Set fs.file-max for SonarQube
      sysctl:
        name: fs.file-max
        value: '65536'
        state: present
        reload: true

    - name: Create SonarQube docker-compose directory
      file:
        path: /opt/sonarqube
        state: directory
        mode: '0755'

    - name: Create SonarQube docker-compose file
      copy:
        dest: /opt/sonarqube/docker-compose.yml
        content: |
          version: '3.8'
          services:
            sonarqube:
              image: sonarqube:{{ sonarqube_version }}
              container_name: sonarqube
              restart: unless-stopped
              environment:
                SONAR_JDBC_URL: jdbc:postgresql://sonardb:5432/sonar
                SONAR_JDBC_USERNAME: sonar
                SONAR_JDBC_PASSWORD: sonarpassword
              ports:
                - "{{ sonarqube_port }}:9000"
              volumes:
                - sonarqube_data:/opt/sonarqube/data
                - sonarqube_extensions:/opt/sonarqube/extensions
                - sonarqube_logs:/opt/sonarqube/logs
              depends_on:
                sonardb:
                  condition: service_healthy
              ulimits:
                nofile:
                  soft: 65536
                  hard: 65536

            sonardb:
              image: postgres:15-alpine
              container_name: sonardb
              restart: unless-stopped
              environment:
                POSTGRES_DB: sonar
                POSTGRES_USER: sonar
                POSTGRES_PASSWORD: sonarpassword
              volumes:
                - sonardb_data:/var/lib/postgresql/data
              healthcheck:
                test: ["CMD-SHELL", "pg_isready -U sonar"]
                interval: 10s
                timeout: 5s
                retries: 5

          volumes:
            sonarqube_data:
            sonarqube_extensions:
            sonarqube_logs:
            sonardb_data:
        mode: '0644'

    - name: Start SonarQube
      command: docker compose up -d
      args:
        chdir: /opt/sonarqube
      changed_when: true

    - name: Wait for SonarQube to be ready
      uri:
        url: "http://localhost:{{ sonarqube_port }}/api/system/status"
        method: GET
        status_code: 200
      register: sonarqube_status
      until: sonarqube_status.json.status == 'UP'
      retries: 30
      delay: 10

    - name: SonarQube is ready
      debug:
        msg: "SonarQube is up at http://{{ inventory_hostname }}:{{ sonarqube_port }} - Default credentials: admin/admin"'''),

    (r"ansible\ansible.cfg", r'''[defaults]
inventory         = inventory/hosts.yml
remote_user       = ubuntu
host_key_checking = False
pipelining        = True
gathering         = smart
fact_caching      = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600
retry_files_enabled = False

[privilege_escalation]
become      = True
become_method = sudo
become_user = root'''),

    (r"gitops\apps\namespace.yaml", r'''apiVersion: v1
kind: Namespace
metadata:
  name: devops-project
  labels:
    app.kubernetes.io/name: devops-project
    app.kubernetes.io/managed-by: argocd'''),

    (r"gitops\apps\frontend\deployment.yaml", r'''apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: devops-project
  labels:
    app: frontend
    tier: frontend
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      serviceAccountName: frontend-sa

      # Security Context at Pod level
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault

      containers:
        - name: frontend
          # IMAGE TAG IS UPDATED BY JENKINS CI PIPELINE
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/devops-project-prod-frontend:latest
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP

          # Container Security Context
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            runAsUser: 1001
            capabilities:
              drop: ["ALL"]
              add: ["NET_BIND_SERVICE"]

          # Resource Limits
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "300m"

          # Health Probes
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3

          startupProbe:
            httpGet:
              path: /health
              port: 3000
            failureThreshold: 12
            periodSeconds: 5

          env:
            - name: REACT_APP_API_URL
              valueFrom:
                configMapKeyRef:
                  name: frontend-config
                  key: api_url

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: frontend

      terminationGracePeriodSeconds: 30'''),

    (r"gitops\apps\frontend\service.yaml", r'''apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: devops-project
  labels:
    app: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
    - name: http
      port: 80
      targetPort: 3000
      protocol: TCP'''),

    (r"gitops\apps\frontend\configmap.yaml", r'''apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: devops-project
data:
  api_url: "https://api.yourdomain.com"  # Replace with your domain'''),

    (r"gitops\apps\frontend\hpa.yaml", r'''apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: devops-project
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80'''),

    (r"gitops\apps\frontend\networkpolicy.yaml", r'''apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: devops-project
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from ingress controller only
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: TCP
          port: 3000
  egress:
    # Allow DNS
    - ports:
        - protocol: UDP
          port: 53
    # Allow to backend only
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 5000
    # Allow HTTPS outbound (for fonts, CDN)
    - ports:
        - protocol: TCP
          port: 443'''),

    (r"gitops\apps\backend\deployment.yaml", r'''apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: devops-project
  labels:
    app: backend
    tier: backend
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      serviceAccountName: backend-sa

      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault

      containers:
        - name: backend
          # IMAGE TAG IS UPDATED BY JENKINS CI PIPELINE
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/devops-project-prod-backend:latest
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 5000
              protocol: TCP

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1001
            capabilities:
              drop: ["ALL"]

          resources:
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "512Mi"
              cpu: "500m"

          livenessProbe:
            httpGet:
              path: /health
              port: 5000
            initialDelaySeconds: 30
            periodSeconds: 20
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /ready
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 3

          startupProbe:
            httpGet:
              path: /health
              port: 5000
            failureThreshold: 15
            periodSeconds: 5

          env:
            - name: NODE_ENV
              value: production
            - name: PORT
              value: "5000"
            - name: ALLOWED_ORIGINS
              valueFrom:
                configMapKeyRef:
                  name: backend-config
                  key: allowed_origins
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: host
            - name: DB_PORT
              value: "3306"
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: dbname
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: jwt_secret
            - name: JWT_EXPIRES_IN
              value: "24h"
            - name: ADMIN_EMAIL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: admin_email
            - name: ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: admin_password

          volumeMounts:
            - name: tmp-dir
              mountPath: /tmp

      volumes:
        - name: tmp-dir
          emptyDir: {}

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: backend

      terminationGracePeriodSeconds: 30'''),

    (r"gitops\apps\backend\service.yaml", r'''apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: devops-project
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - name: http
      port: 5000
      targetPort: 5000
      protocol: TCP'''),

    (r"gitops\apps\backend\configmap.yaml", r'''apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: devops-project
data:
  allowed_origins: "https://yourdomain.com,https://www.yourdomain.com"  # Replace with your domain'''),

    (r"gitops\apps\backend\hpa.yaml", r'''apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: devops-project
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80'''),

    (r"gitops\apps\backend\networkpolicy.yaml", r'''apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: devops-project
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from frontend pods only
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 5000
    # Allow from ingress (direct API access)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: TCP
          port: 5000
  egress:
    # DNS
    - ports:
        - protocol: UDP
          port: 53
    # MySQL on RDS (port 3306)
    - ports:
        - protocol: TCP
          port: 3306
    # AWS Secrets Manager (HTTPS)
    - ports:
        - protocol: TCP
          port: 443'''),

    (r"gitops\infra\rbac.yaml", r'''# ServiceAccounts, Roles, and RoleBindings
---
# Frontend ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: devops-project
  labels:
    app: frontend
automountServiceAccountToken: false
---
# Backend ServiceAccount (with IRSA annotation for Secrets Manager)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: devops-project
  labels:
    app: backend
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/devops-project-prod-backend-sa-role  # Replace ACCOUNT_ID
automountServiceAccountToken: true
---
# Role for backend to read secrets (if using k8s secrets directly)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-role
  namespace: devops-project
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
    resourceNames: ["db-credentials", "app-secrets"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-rolebinding
  namespace: devops-project
subjects:
  - kind: ServiceAccount
    name: backend-sa
    namespace: devops-project
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: backend-role'''),

    (r"gitops\infra\ingress.yaml", r'''# AWS Load Balancer Controller Ingress with ACM TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devops-project-ingress
  namespace: devops-project
  annotations:
    # AWS Load Balancer Controller
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip

    # TLS - Replace with your ACM certificate ARN
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID  # Replace

    # Security
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/wafv2-acl-arn: ""  # Optional: Add WAFv2

    # Health checks
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'

    # Idle timeout
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
spec:
  rules:
    # Frontend: yourdomain.com
    - host: yourdomain.com   # Replace with your domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-svc
                port:
                  number: 80

    # Backend API: api.yourdomain.com
    - host: api.yourdomain.com   # Replace with your domain
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-svc
                port:
                  number: 5000
          - path: /health
            pathType: Exact
            backend:
              service:
                name: backend-svc
                port:
                  number: 5000'''),

    (r"gitops\infra\externalsecrets.yaml", r'''# ExternalSecretsOperator - pulls secrets from AWS Secrets Manager
# Requires: helm install external-secrets external-secrets/external-secrets -n external-secrets-system
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: backend-sa
            namespace: devops-project
---
# DB Credentials from Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: devops-project
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
    - secretKey: host
      remoteRef:
        key: devops-project-prod/rds/credentials
        property: host
    - secretKey: port
      remoteRef:
        key: devops-project-prod/rds/credentials
        property: port
    - secretKey: dbname
      remoteRef:
        key: devops-project-prod/rds/credentials
        property: dbname
    - secretKey: username
      remoteRef:
        key: devops-project-prod/rds/credentials
        property: username
    - secretKey: password
      remoteRef:
        key: devops-project-prod/rds/credentials
        property: password
---
# App Secrets (JWT, Admin credentials)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: devops-project
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
    - secretKey: jwt_secret
      remoteRef:
        key: devops-project-prod/app/secrets
        property: jwt_secret
    - secretKey: admin_email
      remoteRef:
        key: devops-project-prod/app/secrets
        property: admin_email
    - secretKey: admin_password
      remoteRef:
        key: devops-project-prod/app/secrets
        property: admin_password'''),

    (r"gitops\argocd\app-of-apps.yaml", r'''# App of Apps pattern - single ArgoCD application that manages all others
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-project-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/3-tier-devsecops-gitops  # Replace with your GitOps repo
    targetRevision: main
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground'''),

    (r"gitops\argocd\apps\frontend-app.yaml", r'''apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/3-tier-devsecops-gitops  # Replace
    targetRevision: main
    path: apps/frontend
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
  revisionHistoryLimit: 5'''),

    (r"gitops\argocd\apps\backend-app.yaml", r'''apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/3-tier-devsecops-gitops  # Replace
    targetRevision: main
    path: apps/backend
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
  revisionHistoryLimit: 5'''),

    (r"gitops\infra\monitoring\prometheus-values.yaml", r'''# kube-prometheus-stack Helm values
# helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f prometheus-values.yaml

grafana:
  enabled: true
  adminPassword: "CHANGE_ME"  # Change in production
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
    hosts:
      - grafana.yourdomain.com  # Replace with your domain
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: default
          orgId: 1
          folder: ""
          type: file
          disableDeletion: false
          options:
            path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 37
        datasource: Prometheus
      nginx-ingress:
        gnetId: 9614
        revision: 1
        datasource: Prometheus

prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    additionalScrapeConfigs:
      - job_name: devops-project-backend
        static_configs:
          - targets: ['backend-svc.devops-project.svc.cluster.local:5000']
        metrics_path: /metrics

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true'''),

    (r"gitops\infra\monitoring\loki-values.yaml", r'''# Loki Stack Helm values for centralized logging
# helm install loki grafana/loki-stack -n monitoring -f loki-values.yaml

loki:
  enabled: true
  persistence:
    enabled: true
    size: 20Gi
  config:
    schema_config:
      configs:
        - from: 2024-01-01
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h

promtail:
  enabled: true
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_namespace]
            action: keep
            regex: devops-project|monitoring
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: replace
            target_label: app

grafana:
  enabled: false  # Using the one from kube-prometheus-stack
  sidecar:
    datasources:
      enabled: true''')
]

for file_path, content in files:
    full_path = os.path.join(base_dir, file_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)

print("Files created successfully.")
