#!/bin/bash

echo "=== Docker Complete Removal Script ==="
echo ""

# Stop Docker services
echo "1. Stopping Docker services..."
sudo systemctl stop docker 2>/dev/null
sudo systemctl stop docker.socket 2>/dev/null
sudo systemctl stop containerd 2>/dev/null

# Remove all Docker packages
echo "2. Removing Docker packages..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose 2>/dev/null
sudo apt-get purge -y docker docker-engine docker.io containerd runc 2>/dev/null
sudo apt-get purge -y docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin 2>/dev/null

# Remove Docker directories and files
echo "3. Removing Docker directories..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf /usr/local/bin/docker-compose
sudo rm -rf ~/.docker

# Remove Docker repository and GPG keys
echo "4. Removing Docker repositories and keys..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.asc
sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg

# Remove docker group
echo "5. Removing docker group..."
sudo groupdel docker 2>/dev/null

# Clean up
echo "6. Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

# Verify removal
echo ""
echo "=== Verification ==="
if command -v docker &> /dev/null; then
    echo "❌ Docker is still installed"
    docker --version
else
    echo "✅ Docker has been removed"
fi

if command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is still installed"
    docker-compose --version
else
    echo "✅ Docker Compose has been removed"
fi

echo ""
echo "=== Done! ==="
echo "Docker has been completely removed from your system."
