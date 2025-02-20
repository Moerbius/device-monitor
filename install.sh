#!/bin/bash
clear

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Spinner function
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to detect the operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}Cannot detect the operating system.${NC}"
        exit 1
    fi
}

# Function to install prerequisites based on the detected OS
install_prerequisites() {
    case $OS in
        ubuntu|debian)
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y build-essential libssl-dev libcurl4-openssl-dev git libsnmp-dev libconfig++-dev cmake > /dev/null 2>&1
            ;;
        fedora)
            sudo dnf update -y > /dev/null 2>&1
            sudo dnf install -y @development-tools openssl-devel libcurl-devel git net-snmp-devel libconfig-devel cmake > /dev/null 2>&1
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac
}

# Print the company name
echo -e "${BLUE}"
echo "DEVICE MONITOR INSTALLATION"
echo -e "${GREEN}"
echo "=============================================================================="
echo "This script will install the Device Monitor service on your system."
echo "Please ensure you have the following information ready:"
echo "  - CustomerID: The ID of the customer this device belongs to."
echo "  - Device IPs: The IPs or ranges of the devices you want to monitor."
echo "==============================================================================="
echo ""

# Prompt for sudo password upfront
echo -e "${YELLOW}Please enter your sudo password to proceed with the installation...${NC}"
sudo -v

# Detect the operating system
detect_os

# Update package list and install prerequisites
echo -e "${YELLOW}Updating package list and installing prerequisites...${NC}"
(install_prerequisites) & spinner

# Ask the user for the CustomerID
echo -e "${YELLOW}"
read -p "Enter CustomerID: " CUSTOMER_ID
# echo -e "${NC}"

# Ask the user for the IPs or ranges
DEVICE_IPS=()
while true; do
    if [ ${#DEVICE_IPS[@]} -eq 0 ]; then
        read -p "Enter an IP or range: " ip
    else
        read -p "Enter an IP or range (or press Enter to finish): " ip
    fi
    if [ -z "$ip" ] && [ ${#DEVICE_IPS[@]} -gt 0 ]; then
        break
    elif [ -n "$ip" ]; then
        DEVICE_IPS+=("$ip")
    else
        echo -e "${RED}You must enter at least one IP or range.${NC}"
    fi
done

echo -e "${NC}"

# Create the config file
sudo bash -c "cat > /etc/device-monitor/device-monitor.conf <<EOL
# Configuration file for Device Monitor
SNMP_VERSION=\"SNMP_VERSION_1\"
COMMUNITY=\"public\"
INTERVAL=60
CUSTOMER_ID=\"$CUSTOMER_ID\"
DEVICE_IPS = [
EOL"

for ip in "${DEVICE_IPS[@]}"; do
    sudo bash -c "echo \"    \\\"$ip\\\",\" >> /etc/device-monitor/device-monitor.conf"
done

# Remove the last comma and close the array
sudo sed -i '$ s/,$//' /etc/device-monitor/device-monitor.conf
sudo bash -c "cat >> /etc/device-monitor/device-monitor.conf <<EOL
];
EOL"

#mkdir -p "build"
#cd build
#cmake ..
#make
#sudo make install

case $OS in
        ubuntu|debian)
            sudo cp ubuntu/device-monitor /usr/bin/
            ;;
        fedora)
            #sudo dnf update -y > /dev/null 2>&1
            #sudo dnf install -y @development-tools openssl-devel libcurl-devel git net-snmp-devel libconfig-devel cmake > /dev/null 2>&1
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac

sudo systemctl daemon-reload
sudo systemctl enable device-monitor.service
sudo systemctl start device-monitor.service

sudo systemctl status device-monitor.service

echo -e "${GREEN}Installation complete. Device Monitor service is now running.${NC}"