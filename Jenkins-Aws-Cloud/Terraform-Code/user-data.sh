#!/bin/bash
set -e  

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Jenkins setup..."

# Update system and install dependencies
echo "Updating system and installing dependencies..."
yum update -y
amazon-linux-extras install docker -y
yum install -y git

# Start Docker service
echo "Starting Docker..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create Jenkins directory
mkdir -p /opt/jenkins

# Create docker-compose.yml directly 
echo "Creating docker-compose.yml..."
cat > /opt/jenkins/docker-compose.yml << 'EOF'
version: '3.8'
services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - /jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    restart: unless-stopped
EOF

# Create mount point for EBS volume
mkdir -p /jenkins-data

# Wait for EBS volume to be attached (with timeout)
echo "Waiting for EBS volume..."
counter=0
max_attempts=30
while [ ! -e /dev/sdh ] && [ $counter -lt $max_attempts ]; do
    echo "Waiting for EBS volume... attempt $((counter + 1))/$max_attempts"
    sleep 5
    counter=$((counter + 1))
done

if [ ! -e /dev/sdh ]; then
    echo "ERROR: EBS volume not found at /dev/sdh"
    exit 1
fi

# Check if volume needs formatting
echo "Checking EBS volume..."
if ! blkid /dev/sdh > /dev/null 2>&1; then
    echo "Formatting EBS volume as ext4..."
    mkfs -t ext4 /dev/sdh
else
    echo "EBS volume already formatted"
fi

# Mount the volume
echo "Mounting EBS volume..."
mount /dev/sdh /jenkins-data

# Make mount persistent
echo "/dev/sdh /jenkins-data ext4 defaults,nofail 0 2" >> /etc/fstab

# Set permissions
echo "Setting permissions..."
chown -R ec2-user:ec2-user /jenkins-data
chown -R ec2-user:ec2-user /opt/jenkins

# Start Jenkins with Docker Compose
echo "Starting Jenkins..."
cd /opt/jenkins
docker-compose up -d

# Wait for Jenkins to initialize
echo "Waiting for Jenkins to start..."
sleep 30

# Get the initial admin password
echo "Retrieving initial admin password..."
for i in {1..10}; do
    if docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
        break
    fi
    echo "Waiting for Jenkins to generate password... attempt $i/10"
    sleep 10
done

# Display completion message
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "=========================================="
echo "JENKINS SETUP COMPLETE!"
echo "Access Jenkins at: http://$PUBLIC_IP:8080"
echo "=========================================="
echo "Check /var/log/user-data.log for full logs"