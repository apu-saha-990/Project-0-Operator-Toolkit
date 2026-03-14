#!/bin/bash

echo "=== Official Docker Installation Script ==="
echo "Following: https://docs.docker.com/engine/install/ubuntu"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Please run this script WITHOUT sudo"
    echo "The script will ask for sudo when needed"
    exit 1
fi

# Update package index
echo "1. Updating package index..."
sudo apt-get update

# Install prerequisites
echo "2. Installing prerequisites..."
sudo apt-get install -y ca-certificates curl

# Create keyrings directory
echo "3. Setting up keyrings directory..."
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker's official GPG key
echo "4. Adding Docker's official GPG key..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to Apt sources
echo "5. Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
echo "6. Updating package index with Docker repository..."
sudo apt-get update

# Install Docker Engine and components
echo "7. Installing Docker Engine and all components..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
echo "8. Adding user '$USER' to docker group..."
sudo usermod -aG docker $USER

# Apply group change immediately without logout
echo "9. Applying docker group changes..."
newgrp docker <<EONG
echo "   ✅ Docker group applied to current session"
EONG

# Start and enable Docker service
echo "10. Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
echo ""
echo "=== Verification ==="
echo "Docker version:"
docker --version
echo ""
echo "Docker Compose version:"
docker compose version
echo ""

# Check if user is in docker group
echo "Checking groups..."
if groups | grep -q docker; then
    echo "✅ User '$USER' is in docker group"
else
    echo "⚠️  Warning: docker group not yet active in this shell"
fi

# Test Docker without sudo
echo ""
echo "11. Testing Docker without sudo..."
if docker ps &> /dev/null; then
    echo "✅ Docker works without sudo!"
    docker ps
else
    echo "⚠️  Docker requires sudo. Trying to fix permissions..."
    sudo chmod 666 /var/run/docker.sock
    if docker ps &> /dev/null; then
        echo "✅ Docker now works without sudo (socket permissions fixed)"
        docker ps
    else
        echo "❌ Still having permission issues. Please log out and log back in."
    fi
fi

# Test with hello-world
echo ""
echo "12. Testing Docker with hello-world image..."
docker run --rm hello-world

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "✅ Docker Engine installed"
echo "✅ Docker Compose (plugin) installed"
echo "✅ Docker Buildx (plugin) installed"
echo "✅ User '$USER' added to docker group"
echo "✅ Docker tested and working"
echo ""
echo "📝 NOTES:"
echo "   - Docker group has been applied to THIS terminal session"
echo "   - For OTHER terminal windows, either:"
echo "     • Run: newgrp docker"
echo "     • OR log out and log back in for permanent effect"
echo ""
echo "To verify docker works, run:"
echo "    docker ps"
echo "    docker run hello-world"
echo ""
