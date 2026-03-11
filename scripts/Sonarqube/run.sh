#!/bin/bash

################################################################################
# SONARQUBE CODE QUALITY ANALYSIS INSTALLATION AND SETUP SCRIPT
# Purpose: Install Docker and deploy SonarQube for code quality management
# Prerequisites: Ubuntu/Debian system with sudo access
# SonarQube Port: 9000
################################################################################

# ============================================================================
# SECTION 1: DOCKER INSTALLATION AND SETUP
# ============================================================================
# Description: Install Docker for containerization and CI/CD pipeline integration

echo ""
echo "=== Installing Docker Dependencies ==="
# ca-certificates: Verify SSL certificates for secure connections
# curl: Required for downloading Docker GPG key
sudo apt update -y
sudo apt install -y ca-certificates curl

echo "=== Adding Docker's Official GPG Key ==="
# Create secure directory for GPG keys
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker's official GPG key for repository verification
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

# Set proper permissions for GPG key (readable by all users)
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "=== Adding Docker Repository ==="
# Add official Docker repository with GPG signature verification
# Uses Ubuntu codename to ensure correct repository version
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "=== Updating Package Manager (Docker Repository) ==="
sudo apt update -y

echo "=== Installing Docker Components ==="
# docker-ce: Docker Community Edition (main container engine)
# docker-ce-cli: Docker command-line interface
# containerd.io: Container runtime daemon
# docker-buildx-plugin: Build extension for advanced builds
# docker-compose-plugin: Multi-container orchestration plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ============================================================================
# SECTION 2: DOCKER SERVICE CONFIGURATION
# ============================================================================
# Description: Enable and start Docker service

echo ""
echo "=== Starting Docker Service ==="
sudo systemctl start docker

echo "=== Enabling Docker Service (Auto-start on Reboot) ==="
sudo systemctl enable docker > /dev/null 2>&1

echo "=== Verifying Docker Installation ==="
# Non-interactive status check
if sudo systemctl is-active --quiet docker; then
  echo "✓ Docker service is running"
else
  echo "❌ Docker failed to start"
  exit 1
fi

echo "=== Testing Docker Installation ==="
# Test Docker with hello-world container (non-interactive, remove after test)
sudo docker run --rm hello-world > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Docker is working correctly"
else
  echo "❌ Docker test failed"
  exit 1
fi

# ============================================================================
# SECTION 3: DOCKER GROUP CONFIGURATION
# ============================================================================
# Description: Configure Docker group for non-root access

echo ""
echo "=== Configuring Docker Permissions ==="

# Create docker group if it doesn't exist
if ! getent group docker > /dev/null; then
  echo "Creating docker group..."
  sudo groupadd docker
fi

echo ""
echo "=== Applying Docker Group Changes ==="

# Add to docker group
sudo usermod -aG docker $USER

# Apply changes without breaking script using sg command
if command -v sg &> /dev/null; then
  # sg is available - use it
  sg docker -c "docker ps > /dev/null 2>&1" && echo "✓ Docker access ready"
else
  # sg not available - just inform user
  echo "⚠️  Run 'newgrp docker' or reboot to activate group changes"
fi

# ============================================================================
# SECTION 4: DOCKER SOCKET PERMISSIONS
# ============================================================================
# Description: Fix Docker socket permissions

echo "=== Setting Docker Socket Permissions ==="

# Wait for Docker socket to be created
SOCKET_WAIT=0
while [ ! -S /var/run/docker.sock ] && [ $SOCKET_WAIT -lt 10 ]; do
  echo "Waiting for Docker socket..."
  sleep 1
  SOCKET_WAIT=$((SOCKET_WAIT + 1))
done

if [ -S /var/run/docker.sock ]; then
  sudo chown root:docker /var/run/docker.sock
  sudo chmod 660 /var/run/docker.sock
  echo "✓ Docker socket permissions fixed"
else
  echo "⚠️  Docker socket not found - continuing anyway"
fi

# ============================================================================
# SECTION 5: SONARQUBE ENVIRONMENT SETUP
# ============================================================================
# Description: Configure system settings and create directories for SonarQube

echo ""
echo "=== Setting System Kernel Parameters ==="
# SonarQube requires specific kernel parameter settings
# vm.max_map_count: Needed for Elasticsearch (used by SonarQube)
sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
echo "✓ Kernel parameters configured"

echo "=== Creating SonarQube Data Directories ==="
# Create persistent volumes for SonarQube data and Elasticsearch
sudo mkdir -p /var/lib/sonarqube/data
sudo mkdir -p /var/lib/sonarqube/logs
sudo mkdir -p /var/lib/sonarqube/extensions
sudo mkdir -p /var/lib/sonarqube/conf

# Set proper ownership (SonarQube runs as UID 999)
sudo chown -R 999:999 /var/lib/sonarqube
echo "✓ SonarQube data directories created and configured"

# ============================================================================
# SECTION 6: SONARQUBE CONTAINER DEPLOYMENT
# ============================================================================
# Description: Deploy SonarQube LTS Community Edition container

echo ""
echo "=== Deploying SonarQube Container ==="
# Deploy SonarQube container with persistent storage
# -d: Run in detached mode (background)
# --name sonarqube: Container name for easy reference
# -p 9000:9000: Map port 9000 (host) to 9000 (container) for web UI
# -p 9092:9092: Internal port for search engine
# -v: Mount volumes for persistent data, logs, extensions, and configuration
# sonarqube:lts-community: Official SonarQube LTS Community Edition image

# Remove existing container if it exists
sudo docker rm -f sonarqube > /dev/null 2>&1 || true

# Deploy new container
sudo docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  -p 9092:9092 \
  -e sonar.es.bootstrap.checks.disable=true \
  -e sonar.search.javaAdditionalOpts="-Dbootstrap.system_call_filter=false" \
  -v /var/lib/sonarqube/data:/opt/sonarqube/data \
  -v /var/lib/sonarqube/logs:/opt/sonarqube/logs \
  -v /var/lib/sonarqube/extensions:/opt/sonarqube/extensions \
  -v /var/lib/sonarqube/conf:/opt/sonarqube/conf \
  sonarqube:lts-community > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "✓ SonarQube container deployed"
else
  echo "❌ Failed to deploy SonarQube container"
  exit 1
fi

# ============================================================================
# SECTION 7: WAIT FOR SONARQUBE TO START
# ============================================================================
# Description: Wait for SonarQube service to be ready

echo ""
echo "=== Waiting for SonarQube to Initialize ==="
echo "This may take 30-60 seconds..."

# Check if container is running
WAIT_COUNT=0
while [ $WAIT_COUNT -lt 5 ]; do
  CONTAINER_STATUS=$(sudo docker inspect sonarqube --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
  if [ "$CONTAINER_STATUS" = "running" ]; then
    break
  fi
  echo "  Waiting for container to start... ($WAIT_COUNT/5)"
  sleep 2
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

# Wait for SonarQube service API to respond
WAIT_COUNT=0
MAX_WAIT=60
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if sudo docker exec sonarqube curl -s http://localhost:9000/api/system/status 2>/dev/null | grep -q "UP\|STARTING"; then
    echo "✓ SonarQube is ready"
    break
  fi
  
  ELAPSED=$((WAIT_COUNT * 2))
  if [ $((ELAPSED % 10)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
    echo "  Waiting for SonarQube... (${ELAPSED}s elapsed)"
  fi
  
  sleep 2
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo "⚠️  SonarQube is taking longer than expected to start"
  echo "   It may still be initializing in the background"
fi

# ============================================================================
# SECTION 8: VERIFY SONARQUBE CONTAINER
# ============================================================================
# Description: Verify SonarQube is running properly

echo ""
echo "=== Verifying SonarQube Container ==="

# Check container status
CONTAINER_STATUS=$(sudo docker inspect sonarqube --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
if [ "$CONTAINER_STATUS" = "running" ]; then
  echo "✓ SonarQube container is running"
else
  echo "❌ SonarQube container is not running (Status: $CONTAINER_STATUS)"
  echo "   Attempting to view logs:"
  sudo docker logs sonarqube 2>/dev/null | tail -20
  exit 1
fi

# ============================================================================
# SECTION 9: GET PUBLIC IP ADDRESS
# ============================================================================
# Description: Retrieve EC2 instance public IP for accessing SonarQube

echo ""
echo "=== Retrieving Instance Public IP Address ==="
# This IP will be used to access SonarQube UI at http://<IP>:9000
INSTANCE_IP=$(curl -s http://checkip.amazonaws.com/)
if [ -z "$INSTANCE_IP" ]; then
  INSTANCE_IP="<YOUR_PUBLIC_IP>"
fi
echo "Your public IP: $INSTANCE_IP"

# ============================================================================
# SECTION 10: VERIFICATION AND NEXT STEPS
# ============================================================================
# Description: Verify SonarQube is running and provide setup instructions

echo ""
echo "============================================================================"
echo "=== SonarQube Installation Complete! ==="
echo "============================================================================"
echo ""
echo "SONARQUBE ACCESS INFORMATION:"
echo "  URL: http://${INSTANCE_IP}:9000"
echo ""
echo "FIRST LOGIN CREDENTIALS:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Access SonarQube Web UI:"
echo "   http://${INSTANCE_IP}:9000"
echo ""
echo "2. Login with default credentials:"
echo "   - Username: admin"
echo "   - Password: admin"
echo ""
echo "3. Change admin password immediately:"
echo "   - Click on profile icon (top-right)"
echo "   - Select 'My Account' → 'Security'"
echo "   - Set a strong new password"
echo ""
echo "4. Create Quality Gate:"
echo "   - Administration → Quality Gates"
echo "   - Create custom quality gate rules"
echo ""
echo "5. Create Projects:"
echo "   - Projects → Create Project"
echo "   - Generate project token"
echo "   - Configure scanner in Jenkins/CI pipeline"
echo ""
echo "6. Install SonarQube Scanner:"
echo "   - For Jenkins: Install 'SonarQube Scanner' plugin in Jenkins"
echo "   - For CLI: install sonar-scanner locally"
echo ""
echo "JENKINS INTEGRATION:"
echo "  - In Jenkins: Manage Jenkins → Configure System → SonarQube servers"
echo "  - Add SonarQube server URL: http://${INSTANCE_IP}:9000"
echo "  - Create authentication token in SonarQube"
echo "  - Use in Jenkinsfile with SonarQube step"
echo ""
echo "SONARQUBE SCANNER COMMAND:"
echo "  sonar-scanner \\"
echo "    -Dsonar.projectKey=my-project \\"
echo "    -Dsonar.sources=. \\"
echo "    -Dsonar.host.url=http://${INSTANCE_IP}:9000 \\"
echo "    -Dsonar.login=<PROJECT_TOKEN>"
echo ""
echo "USEFUL DOCKER COMMANDS:"
echo "  View SonarQube logs: sudo docker logs -f sonarqube"
echo "  View last 50 lines: sudo docker logs --tail 50 sonarqube"
echo "  Check Elasticsearch: sudo docker exec sonarqube curl -s http://localhost:9200"
echo "  Stop SonarQube: sudo docker stop sonarqube"
echo "  Start SonarQube: sudo docker start sonarqube"
echo "  Restart SonarQube: sudo docker restart sonarqube"
echo "  Remove SonarQube: sudo docker rm -v sonarqube"
echo ""
echo "SONARQUBE DOCUMENTATION:"
echo "  - Analysis with Jenkins: https://docs.sonarqube.org/latest/analyzing-source-code/scanners/sonarscanner-for-jenkins/"
echo "  - Quality Gates: https://docs.sonarqube.org/latest/user-guide/quality-gates/"
echo "  - Project Maintenance: https://docs.sonarqube.org/latest/user-guide/projects/"
echo ""
echo "============================================================================"
echo "✓ Script completed successfully!"
echo "============================================================================"