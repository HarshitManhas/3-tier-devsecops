#!/bin/bash
# ================================================================
# SonarQube EC2 - Bootstrap Script
# Installs: Docker, SonarQube 10.4 + PostgreSQL 15
# Dedicated EC2 - no Jenkins here
#
# Logs: tail -f /var/log/bootstrap.log
# Default login: admin / admin (change immediately!)
# ================================================================
set -e
exec > >(tee -a /var/log/bootstrap.log) 2>&1
echo "============================================"
echo " SonarQube Bootstrap: $(date)"
echo "============================================"

hostnamectl set-hostname sonarqube-server

# ── System Update ─────────────────────────────────────────────────
echo ">>> [1/4] Updating system..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git unzip gnupg ca-certificates \
  lsb-release apt-transport-https software-properties-common

# ── Kernel settings (required by Elasticsearch inside SonarQube) ──
echo ">>> [2/4] Configuring kernel parameters for Elasticsearch..."
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=65536
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "fs.file-max=65536" >> /etc/sysctl.conf
ulimit -n 65536
ulimit -u 4096
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "sonarqube - nofile 65536" >> /etc/security/limits.conf
echo "sonarqube - nproc  4096"  >> /etc/security/limits.conf
echo "✅ Kernel parameters set"

# ── Docker ────────────────────────────────────────────────────────
echo ">>> [3/4] Installing Docker..."
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
echo "✅ Docker installed"

# ── SonarQube via Docker Compose ──────────────────────────────────
echo ">>> [4/4] Starting SonarQube + PostgreSQL..."
mkdir -p /opt/sonarqube

cat > /opt/sonarqube/docker-compose.yml <<'COMPOSE_EOF'
version: '3.8'
services:
  sonarqube:
    image: sonarqube:10.4-community
    container_name: sonarqube
    restart: unless-stopped
    depends_on:
      sonardb:
        condition: service_healthy
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonardb:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonarpassword
      SONAR_WEB_JAVAOPTS: "-Xmx1g -Xms512m"
      SONAR_CE_JAVAOPTS: "-Xmx1g -Xms512m"
      SONAR_SEARCH_JAVAOPTS: "-Xmx1g -Xms512m"
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc:
        soft: 4096
        hard: 4096

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
      retries: 10

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  sonardb_data:
COMPOSE_EOF

docker compose -f /opt/sonarqube/docker-compose.yml up -d

# ── Systemd service so SonarQube starts on reboot ─────────────────
cat > /etc/systemd/system/sonarqube.service <<'SERVICE_EOF'
[Unit]
Description=SonarQube via Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/sonarqube
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable sonarqube

# ── Wait and verify ───────────────────────────────────────────────
echo ">>> Waiting 60s for SonarQube to initialise..."
sleep 60

# Check container status
docker compose -f /opt/sonarqube/docker-compose.yml ps

# ── MOTD ──────────────────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<check-ip>")
cat > /etc/motd <<MOTD

┌════════════════════════════════════════════════════════┐
║  DevOps Project — SONARQUBE SERVER (t3.medium)     ║
╠════════════════════════════════════════════════════════╣
║  SonarQube URL  →  http://${PUBLIC_IP}:9000          ║
║  Default login  →  admin / admin                    ║
║  CHANGE PASSWORD IMMEDIATELY after first login!     ║
╠════════════════════════════════════════════════════════╣
║  Containers:                                        ║
║  docker compose -f /opt/sonarqube/docker-compose.yml ps  ║
║  docker logs sonarqube -f                          ║
┗════════════════════════════════════════════════════════┛

MOTD

echo ""
echo "╔════════════════════════════════════════╗"
echo "║ SonarQube Bootstrap DONE ✔ $(date '+%H:%M') ║"
echo "╠════════════════════════════════════════╣"
echo " URL: http://${PUBLIC_IP}:9000"
echo " Wait ~3 mins for SonarQube to fully start"
echo " Login: admin / admin (change immediately!)"
echo "╚════════════════════════════════════════╝"
