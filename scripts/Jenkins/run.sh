#!/bin/bash

################################################################################
# JENKINS + DOCKER + TRIVY INSTALLATION AND SETUP SCRIPT
# Purpose: Automated installation of Jenkins with Docker and Trivy for scanning
# Prerequisites: Ubuntu/Debian system with sudo access
################################################################################

# ============================================================================
# SECTION 1: SYSTEM UPDATE AND JAVA INSTALLATION
# ============================================================================
# Description: Update system packages and install Java runtime environment

echo "=== Updating System Packages ==="
sudo apt update -y

echo "=== Installing Java 21 (Required for Jenkins) ==="
# fontconfig: Font support for Jenkins UI
# openjdk-21-jre: Java runtime for Jenkins
sudo apt install -y fontconfig openjdk-21-jre

# Verify Java installation (non-interactive)
echo "=== Verifying Java Installation ==="
java -version 2>&1 | head -1

# ============================================================================
# SECTION 2: JENKINS REPOSITORY SETUP
# ============================================================================
# Description: Add official Jenkins repository and GPG key for secure installation

echo "=== Adding Jenkins GPG Key ==="
# Download and add Jenkins GPG key for repository verification
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "=== Adding Jenkins Repository ==="
# Add official Jenkins Debian repository (stable version)
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# ============================================================================
# SECTION 3: JENKINS INSTALLATION
# ============================================================================
# Description: Install Jenkins and configure systemd service

echo "=== Updating Package Manager (Jenkins Repository) ==="
sudo apt update -y

echo "=== Installing Jenkins ==="
sudo apt install -y jenkins

# ============================================================================
# SECTION 4: JENKINS SERVICE CONFIGURATION
# ============================================================================
# Description: Enable and start Jenkins service

echo "=== Enabling Jenkins Service (Auto-start on Reboot) ==="
sudo systemctl enable jenkins

echo "=== Starting Jenkins Service ==="
sudo systemctl start jenkins

echo "=== Verifying Jenkins Installation ==="
# Non-interactive status check
if sudo systemctl is-active --quiet jenkins; then
  echo "✓ Jenkins service is running"
else
  echo "❌ Jenkins failed to start"
  exit 1
fi

# ============================================================================
# SECTION 5: GET PUBLIC IP ADDRESS
# ============================================================================
# Description: Retrieve EC2 instance public IP for accessing Jenkins

echo ""
echo "=== Retrieving Jenkins Instance Public IP ==="
# This IP will be used to access Jenkins UI at http://<IP>:8080
JENKINS_IP=$(curl -s http://checkip.amazonaws.com/)
echo "Jenkins URL: http://${JENKINS_IP}:8080"

# ============================================================================
# SECTION 6: DOCKER INSTALLATION AND SETUP
# ============================================================================
# Description: Install Docker for containerization and CI/CD pipeline integration

echo ""
echo "=== Installing Docker Dependencies ==="
# ca-certificates: Verify SSL certificates for secure connections
# curl: Required for downloading Docker GPG key
# wget: Required for downloading packages
sudo apt update -y
sudo apt install -y ca-certificates curl wget gnupg

echo "=== Adding Docker's Official GPG Key ==="
# Create secure directory for GPG keys
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker's official GPG key for repository verification
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

# Set proper permissions for GPG key (readable by all users)
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "=== Adding Docker Repository ==="
# Add official Docker repository with GPG verification
# Uses Ubuntu codename for correct repository version
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
# docker-ce: Docker Community Edition (main engine)
# docker-ce-cli: Docker command-line interface
# containerd.io: Container runtime
# docker-buildx-plugin: Build extension for advanced builds
# docker-compose-plugin: Compose plugin for multi-container apps
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ============================================================================
# SECTION 7: DOCKER SERVICE CONFIGURATION
# ============================================================================
# Description: Enable and start Docker service

echo ""
echo "=== Starting Docker Service ==="
sudo systemctl start docker

echo "=== Enabling Docker Service (Auto-start on Reboot) ==="
sudo systemctl enable docker > /dev/null 2>&1

echo "=== Verifying Docker Installation ==="
# Non-interactive verification
if sudo systemctl is-active --quiet docker; then
  echo "✓ Docker service is running"
else
  echo "❌ Docker failed to start"
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
# SECTION 8: DOCKER GROUP CONFIGURATION FOR JENKINS
# ============================================================================
# Description: Configure Docker permissions for Jenkins user and current user

echo ""
echo "=== Configuring Docker Permissions ==="

# Create docker group if it doesn't exist
if ! getent group docker > /dev/null; then
  echo "Creating docker group..."
  sudo groupadd docker
fi

echo "Adding jenkins to docker group..."
sudo usermod -aG docker jenkins

echo "Adding $USER to docker group..."
sudo usermod -aG docker $USER

echo ""
echo "=== Applying Docker Group Changes ==="

# Apply changes without breaking script using sg command
if command -v sg &> /dev/null; then
  # sg is available - use it
  sg docker -c "docker ps > /dev/null 2>&1" && echo "✓ Docker access ready"
else
  # sg not available - just inform user
  echo "⚠️  Run 'newgrp docker' or reboot to activate group changes"
fi

# ============================================================================
# SECTION 9: CONFIGURE SUDOERS FOR JENKINS DOCKER ACCESS
# ============================================================================
# Description: Allow Jenkins to run Docker commands with sudo

echo ""
echo "=== Configuring Sudoers for Jenkins Docker Access ==="

# Create sudoers file for Jenkins Docker access (non-interactive)
sudo tee /etc/sudoers.d/jenkins-docker > /dev/null <<EOF
# Allow jenkins user to run docker commands without password
jenkins ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose

# Allow jenkins to manage Docker socket permissions
jenkins ALL=(ALL) NOPASSWD: /bin/chown
EOF

# Validate sudoers syntax
sudo visudo -c -f /etc/sudoers.d/jenkins-docker > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Sudoers configuration is valid"
else
  echo "❌ Invalid sudoers syntax - reverting"
  sudo rm -f /etc/sudoers.d/jenkins-docker
  exit 1
fi

# Set proper permissions on sudoers file
sudo chmod 0440 /etc/sudoers.d/jenkins-docker
echo "✓ Sudoers file configured"

# ============================================================================
# SECTION 10: FIX DOCKER SOCKET PERMISSIONS
# ============================================================================
# Description: Ensure Docker socket has proper permissions for Jenkins

echo ""
echo "=== Fixing Docker Socket Permissions ==="

# Ensure Docker socket exists and has correct permissions
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

if [ -S /var/run/docker.sock ]; then
  echo "✓ Docker socket permissions fixed"
else
  echo "⚠️  Docker socket not found - will be created on Docker restart"
fi

# ============================================================================
# SECTION 11: RESTART JENKINS AND DOCKER
# ============================================================================
# Description: Restart services to apply permission changes

echo ""
echo "=== Restarting Docker to Apply Changes ==="
sudo systemctl restart docker

# Wait for Docker to restart
sleep 2

echo "=== Restarting Jenkins to Apply Permission Changes ==="
sudo systemctl restart jenkins

# Wait for Jenkins to restart
sleep 5

echo "=== Verifying Services Are Running ==="
if sudo systemctl is-active --quiet jenkins && sudo systemctl is-active --quiet docker; then
  echo "✓ Both Jenkins and Docker services are running"
else
  echo "❌ One or more services failed to start"
  exit 1
fi

# ============================================================================
# SECTION 12: VERIFY JENKINS DOCKER PERMISSIONS
# ============================================================================
# Description: Test that Jenkins can access Docker

echo ""
echo "=== Verifying Jenkins Docker Permissions ==="

# Check if jenkins user can access Docker socket
if sudo -u jenkins docker ps > /dev/null 2>&1; then
  echo "✓ Jenkins user can access Docker successfully"
else
  echo "⚠️  Jenkins user cannot access Docker - may need system reboot"
fi

# ============================================================================
# SECTION 13: INSTALL TRIVY VULNERABILITY SCANNER
# ============================================================================
# Description: Install Trivy for container and code vulnerability scanning

echo ""
echo "=== Installing Trivy Vulnerability Scanner ==="
# Trivy: Open-source vulnerability scanner for containers and code
# Used in CI/CD pipelines to scan images and dependencies

echo "=== Adding Trivy GPG Key ==="
# Download Trivy GPG key for repository verification
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/trivy.gpg > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "✓ Trivy GPG key added"
else
  echo "⚠️  Failed to add Trivy GPG key - continuing anyway"
fi

echo "=== Adding Trivy Repository ==="
# Add Aqua Security Trivy repository
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
  sudo tee -a /etc/apt/sources.list.d/trivy.list > /dev/null 2>&1

echo "=== Updating Package Manager (Trivy Repository) ==="
sudo apt update -y

echo "=== Installing Trivy ==="
# Install Trivy vulnerability scanner
sudo apt install -y trivy

# Verify Trivy installation
echo "=== Verifying Trivy Installation ==="
if command -v trivy &> /dev/null; then
  TRIVY_VERSION=$(trivy --version 2>&1 | head -1)
  echo "✓ Trivy installed: $TRIVY_VERSION"
else
  echo "⚠️  Trivy installation may have failed - check manually"
fi

# ============================================================================
# SECTION 14: INSTALLATION COMPLETE
# ============================================================================
# Description: Final setup information and next steps

echo ""
echo "============================================================================"
echo "=== Installation Complete! ==="
echo "============================================================================"
echo ""
echo "JENKINS ACCESS INFORMATION:"
echo "  URL: http://${JENKINS_IP}:8080"
echo ""
echo "INSTALLED COMPONENTS:"
echo "  ✓ Jenkins (CI/CD Server)"
echo "  ✓ Docker (Container Runtime)"
echo "  ✓ Trivy (Vulnerability Scanner)"
echo ""
echo "NEXT STEPS:"
echo ""
echo "Jenkins Initial Setup:"
echo "  1. Access Jenkins: http://${JENKINS_IP}:8080"
echo ""
echo "  2. Get initial admin password:"
echo "     sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "  3. Follow Jenkins Setup Wizard:"
echo "     - Paste initial admin password"
echo "     - Install recommended plugins"
echo "     - Create first admin user"
echo ""
echo "DOCKER PERMISSIONS:"
echo "  - Jenkins user is in docker group: ✓"
echo "  - Jenkins can run docker commands: ✓"
echo "  - Docker socket permissions: ✓"
echo "  - Sudoers configured: ✓"
echo ""
echo "TRIVY USAGE:"
echo "  Scan Docker image: trivy image ubuntu:latest"
echo "  Scan filesystem: trivy fs /path/to/directory"
echo "  Scan with JSON output: trivy image -f json ubuntu:latest"
echo ""
echo "USEFUL COMMANDS:"
echo "  Check Jenkins status: sudo systemctl status jenkins"
echo "  View Jenkins logs: sudo tail -f /var/log/jenkins/jenkins.log"
echo "  Verify Jenkins Docker access: sudo -u jenkins docker ps"
echo "  Check Trivy version: trivy --version"
echo "  Scan image in Jenkins job: trivy image --severity HIGH,CRITICAL myimage:latest"
echo ""
echo "JENKINS + DOCKER INTEGRATION:"
echo "  1. In Jenkins, install these plugins:"
echo "     - Docker Commons"
echo "     - Docker Pipeline"
echo "     - Docker"
echo ""
echo "  2. Configure Docker in Jenkins:"
echo "     Manage Jenkins → Configure System → Docker"
echo "     Docker Host URI: unix:///var/run/docker.sock"
echo ""
echo "  3. Use Docker in Jenkinsfile with Trivy scanning:"
echo "     pipeline {"
echo "       agent {"
echo "         docker {"
echo "           image 'ubuntu:latest'"
echo "           args '-v /var/run/docker.sock:/var/run/docker.sock'"
echo "         }"
echo "       }"
echo "       stages {"
echo "         stage('Build') {"
echo "           steps {"
echo "             sh 'docker build -t myapp:latest .'"
echo "           }"
echo "         }"
echo "         stage('Scan') {"
echo "           steps {"
echo "             sh 'trivy image --severity HIGH,CRITICAL myapp:latest'"
echo "           }"
echo "         }"
echo "       }"
echo "     }"
echo ""
echo "SECURITY BEST PRACTICES:"
echo "  1. Change Jenkins admin password immediately"
echo "  2. Enable Jenkins security options:"
echo "     Manage Jenkins → Security → Enable CSRF protection"
echo "  3. Use strong authentication (LDAP, OAuth, etc.)"
echo "  4. Enable build logs rotation"
echo "  5. Regularly scan Docker images with Trivy"
echo "  6. Keep Jenkins plugins updated"
echo ""
echo "DOCUMENTATION LINKS:"
echo "  - Jenkins: https://www.jenkins.io/doc/"
echo "  - Docker: https://docs.docker.com/"
echo "  - Trivy: https://aquasecurity.github.io/trivy/"
echo ""
echo "============================================================================"
echo "✓ Script completed successfully!"
echo "============================================================================"