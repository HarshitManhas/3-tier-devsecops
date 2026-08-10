#!/bin/bash
# ================================================================
# Jenkins EC2 - Complete Bootstrap Script
# Installs: Jenkins, Docker, Trivy, Gitleaks, AWS CLI,
#           kubectl, Helm, Node.js, Terraform, Ansible
# NO SonarQube here - it runs on its own dedicated EC2
#
# Logs: tail -f /var/log/bootstrap.log
# ================================================================
set -e
exec > >(tee -a /var/log/bootstrap.log) 2>&1
echo "============================================"
echo " Jenkins Bootstrap: $(date)"
echo "============================================"

TERRAFORM_VERSION="1.7.5"
KUBECTL_VERSION="1.29.0"
HELM_VERSION="3.14.3"
TRIVY_VERSION="0.50.1"
GITLEAKS_VERSION="8.18.2"
NODEJS_VERSION="20"

# ── System Update ─────────────────────────────────────────────────
echo ">>> [1/10] Updating system..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl wget git unzip zip jq \
  software-properties-common gnupg \
  lsb-release ca-certificates \
  apt-transport-https \
  python3-pip python3-boto3 python3-botocore \
  net-tools
hostnamectl set-hostname jenkins-server

# ── Java 17 ───────────────────────────────────────────────────────
echo ">>> [2/10] Installing Java 17..."
apt-get install -y openjdk-17-jdk
java -version
echo "✅ Java installed"

# ── Jenkins LTS ───────────────────────────────────────────────────
echo ">>> [3/10] Installing Jenkins LTS..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins
echo "✅ Jenkins installed"

# ── Docker ────────────────────────────────────────────────────────
echo ">>> [4/10] Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl start docker && systemctl enable docker
usermod -aG docker ubuntu
usermod -aG docker jenkins
chmod 666 /var/run/docker.sock
echo "✅ Docker installed"

# ── Terraform ─────────────────────────────────────────────────────
echo ">>> [5/10] Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y && apt-get install -y terraform
terraform version
echo "✅ Terraform installed"

# ── Ansible ───────────────────────────────────────────────────────
echo ">>> [6/10] Installing Ansible..."
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible
pip3 install boto3 botocore --quiet
ansible-galaxy collection install amazon.aws community.aws --quiet 2>/dev/null || true
ansible --version
echo "✅ Ansible installed"

# ── AWS CLI v2 ────────────────────────────────────────────────────
echo ">>> [7/10] Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o /tmp/awscliv2.zip -d /tmp/awscli
/tmp/awscli/aws/install --update
aws --version
echo "✅ AWS CLI installed"

# ── kubectl ───────────────────────────────────────────────────────
echo ">>> [8/10] Installing kubectl..."
curl -fsSLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# ── Helm ──────────────────────────────────────────────────────────
curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  | tar -xz -C /tmp
install /tmp/linux-amd64/helm /usr/local/bin/helm
echo "✅ kubectl + Helm installed"

# ── Trivy ─────────────────────────────────────────────────────────
echo ">>> [9/10] Installing Trivy..."
wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.deb" \
  -O /tmp/trivy.deb
dpkg -i /tmp/trivy.deb
trivy image --download-db-only 2>/dev/null || true
echo "✅ Trivy installed"

# ── Gitleaks ──────────────────────────────────────────────────────
echo ">>> [10/10] Installing Gitleaks + Node.js..."
wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  -O /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
chmod +x /usr/local/bin/gitleaks

# ── Node.js ───────────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash -
apt-get install -y nodejs
echo "✅ Gitleaks + Node.js installed"

# ── Wait for Jenkins and get password ─────────────────────────────
echo ">>> Waiting for Jenkins to fully start..."
sleep 40
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
  echo "$PASS" > /home/ubuntu/jenkins-password.txt
  chmod 644 /home/ubuntu/jenkins-password.txt
fi

# ── MOTD ──────────────────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<check-ip>")
cat > /etc/motd <<MOTD

┌════════════════════════════════════════════════════════┐
║   DevOps Project — JENKINS SERVER (t3.large)       ║
╠════════════════════════════════════════════════════════╣
║  Jenkins UI  →  http://${PUBLIC_IP}:8080             ║
║  Password    →  cat ~/jenkins-password.txt           ║
╠════════════════════════════════════════════════════════╣
║  Tools: Jenkins | Docker | Trivy | Gitleaks         ║
║         AWS CLI | kubectl | Helm | Node.js           ║
║         Terraform | Ansible                          ║
┗════════════════════════════════════════════════════════┛

MOTD

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║ Jenkins Bootstrap DONE ✔  $(date '+%H:%M') ║"
echo "╠══════════════════════════════════════════╣"
jenkins --version 2>/dev/null | head -1 || echo "Jenkins: starting..."
terraform version | head -1
ansible --version | head -1
docker --version
aws --version
kubectl version --client --short 2>/dev/null
helm version --short
trivy --version | head -1
gitleaks version
node --version
echo "╚══════════════════════════════════════════╝"
echo "Jenkins password: $(cat /home/ubuntu/jenkins-password.txt 2>/dev/null)"
echo "Log: /var/log/bootstrap.log"
