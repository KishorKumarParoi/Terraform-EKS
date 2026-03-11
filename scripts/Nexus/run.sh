#!/bin/bash

################################################################################
# NEXUS REPOSITORY MANAGER INSTALLATION AND SETUP SCRIPT
# Purpose: Install Docker and deploy Nexus3 for artifact/repository management
# Prerequisites: Ubuntu/Debian system with sudo access
# Nexus Port: 8081
################################################################################

# ============================================================================
# SECTION 1: DOCKER INSTALLATION AND SETUP
# ============================================================================
# Description: Install Docker for containerization and CI/CD pipeline integration

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
sudo systemctl enable docker

echo "=== Verifying Docker Installation ==="
# Non-interactive way to verify Docker is running
if sudo systemctl is-active --quiet docker; then
  echo "✓ Docker service is running"
else
  echo "❌ Docker service failed to start"
  exit 1
fi

echo "=== Testing Docker Installation ==="
# Test Docker with hello-world container (non-interactive)
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
# SECTION 4: NEXUS REPOSITORY MANAGER DEPLOYMENT
# ============================================================================
# Description: Deploy Nexus3 container for artifact repository management

echo "=== Creating Nexus Data Directory ==="
# Create persistent volume for Nexus data
sudo mkdir -p /var/lib/nexus-data
sudo chown -R 200:200 /var/lib/nexus-data  # Nexus UID:GID is 200:200

echo "✓ Nexus data directory created"

echo ""
echo "=== Deploying Nexus3 Container ==="
# Run Nexus3 container with persistent storage
# -d: Run in detached mode
# --name nexus3: Container name for easy reference
# -p 8081:8081: Map port 8081 (host) to 8081 (container)
# -v: Mount volume for persistent data storage
# sonatype/nexus3: Official Nexus3 image from Sonatype
sudo docker run -d \
  --name nexus3 \
  -p 8081:8081 \
  -v /var/lib/nexus-data:/nexus-data \
  sonatype/nexus3

if [ $? -eq 0 ]; then
  echo "✓ Nexus3 container deployed successfully"
else
  echo "❌ Failed to deploy Nexus3 container"
  exit 1
fi

echo ""
echo "=== Waiting for Nexus to Initialize ==="
# Wait for container to be running
sleep 5

# Check container status
CONTAINER_STATUS=$(sudo docker inspect nexus3 --format='{{.State.Status}}' 2>/dev/null)
if [ "$CONTAINER_STATUS" = "running" ]; then
  echo "✓ Nexus3 container is running"
else
  echo "❌ Nexus3 container is not running"
  echo "   Status: $CONTAINER_STATUS"
  sudo docker logs nexus3
  exit 1
fi

# Wait for Nexus service to be ready (can take 30-60 seconds)
echo "=== Waiting for Nexus Service to be Ready ==="
WAIT_COUNT=0
MAX_WAIT=60
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if sudo docker exec nexus3 curl -s http://localhost:8081/ > /dev/null 2>&1; then
    echo "✓ Nexus service is ready"
    break
  fi
  WAIT_COUNT=$((WAIT_COUNT + 5))
  if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
    echo "  Waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    sleep 5
  fi
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo "⚠️  Nexus is taking longer than expected to start"
  echo "   It may still be initializing. Check logs with:"
  echo "   sudo docker logs -f nexus3"
fi

# ============================================================================
# SECTION 5: GET PUBLIC IP ADDRESS
# ============================================================================
# Description: Retrieve EC2 instance public IP for accessing Nexus

echo ""
echo "=== Retrieving Instance Public IP Address ==="
# This IP will be used to access Nexus UI at http://<IP>:8081
INSTANCE_IP=$(curl -s http://checkip.amazonaws.com/)
if [ -z "$INSTANCE_IP" ]; then
  echo "⚠️  Could not retrieve public IP"
  INSTANCE_IP="<YOUR_PUBLIC_IP>"
fi
echo "Nexus URL: http://${INSTANCE_IP}:8081"

# ============================================================================
# SECTION 6: VERIFICATION AND NEXT STEPS
# ============================================================================
# Description: Verify Nexus is running and provide setup instructions

echo ""
echo "============================================================================"
echo "=== Nexus Installation Complete! ==="
echo "============================================================================"
echo ""
echo "NEXUS ACCESS INFORMATION:"
echo "  URL: http://${INSTANCE_IP}:8081"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Access Nexus Web UI:"
echo "   http://${INSTANCE_IP}:8081"
echo ""
echo "2. Get initial admin password (after ~30 seconds):"
echo "   sudo docker exec nexus3 cat /nexus-data/admin.password"
echo ""
echo "3. First Login:"
echo "   - Username: admin"
echo "   - Password: (from above command)"
echo ""
echo "4. Configure Nexus:"
echo "   - Set new admin password"
echo "   - Create repositories (Maven, Docker, npm, etc.)"
echo "   - Create users and roles"
echo "   - Configure repository proxies"
echo ""
echo "USEFUL DOCKER COMMANDS:"
echo "  View Nexus logs: sudo docker logs -f nexus3"
echo "  Stop Nexus: sudo docker stop nexus3"
echo "  Start Nexus: sudo docker start nexus3"
echo "  Remove Nexus: sudo docker rm -v nexus3"
echo "  Restart Nexus: sudo docker restart nexus3"
echo ""
echo "NEXUS REPOSITORY TYPES:"
echo "  - Maven: For Java artifacts (.jar, .pom)"
echo "  - Docker: For container images"
echo "  - npm: For Node.js packages"
echo "  - PyPI: For Python packages"
echo "  - Raw: For binary files"
echo ""
echo "============================================================================"
echo "✓ Script completed successfully!"
echo "============================================================================"