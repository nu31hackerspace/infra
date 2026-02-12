#!/bin/bash


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  VPS Deployment Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local required="$4"
    
    while true; do
        if [ -n "$default" ]; then
            echo -e "${YELLOW}$prompt${NC} (default: $default):"
        else
            echo -e "${YELLOW}$prompt${NC}:"
        fi
        
        read -r input
        
        # Use default if input is empty and default is provided
        if [ -z "$input" ] && [ -n "$default" ]; then
            input="$default"
        fi
        
        # Check if required field is empty
        if [ "$required" = "true" ] && [ -z "$input" ]; then
            echo -e "${RED}This field is required. Please enter a value.${NC}"
            continue
        fi
        
        # Store the value
        eval "$var_name=\"$input\""
        break
    done
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<< "$ip"
        for part in "${ip_parts[@]}"; do
            if [ "$part" -lt 0 ] || [ "$part" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

if ! ansible --version > /dev/null 2>&1; then
    echo -e "${RED}Error: Ansible is not installed or not found in PATH. Please install Ansible before running this script.${NC}"
    exit 1
fi

echo -e "${GREEN}Please provide the following information for VPS deployment:${NC}"
echo ""

# Prompt for VPS IP address
while true; do
    prompt_input "Enter VPS IP address" "vps_ip" "" "true"
    if validate_ip "$vps_ip"; then
        break
    else
        echo -e "${RED}Invalid IP address format. Please enter a valid IP (e.g., 192.168.1.100)${NC}"
    fi
done

# Prompt for SSH user (default: root)
prompt_input "Enter SSH user for initial connection" "ssh_user" "root" "true"

# Prompt for SSH port (default: 2222)
while true; do
    prompt_input "Enter SSH port for the new configuration" "ssh_port" "2222" "true"
    if validate_port "$ssh_port"; then
        break
    else
        echo -e "${RED}Invalid port number. Please enter a number between 1-65535${NC}"
    fi
done

# Prompt for SSH public key
echo -e "${YELLOW}Enter your SSH public key (from 1Password or ~/.ssh/id_rsa.pub):${NC}"
echo -e "${BLUE}You can copy it from 1Password or run: cat ~/.ssh/id_rsa.pub${NC}"
read -r deploy_user_public_key

# Validate that public key is provided
if [ -z "$deploy_user_public_key" ]; then
    echo -e "${RED}SSH public key is required. Please provide your public key.${NC}"
    exit 1
fi

# Prompt for SSH private key path
prompt_input "Enter path to SSH private key" "ssh_private_key" "~/.ssh/id_rsa" "true"

# Expand the tilde and check if SSH private key exists
ssh_private_key_expanded=$(eval echo $ssh_private_key)
if [ ! -f "$ssh_private_key_expanded" ]; then
    echo -e "${RED}SSH private key not found at: $ssh_private_key_expanded${NC}"
    echo -e "${YELLOW}Please make sure your SSH key exists and try again.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Deployment Summary${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${BLUE}VPS IP:${NC} $vps_ip"
echo -e "${BLUE}SSH User:${NC} $ssh_user"
echo -e "${BLUE}SSH Port:${NC} $ssh_port"
echo -e "${BLUE}SSH Private Key:${NC} $ssh_private_key"
echo -e "${BLUE}Public Key:${NC} ${deploy_user_public_key:0:50}..."
echo ""

# Confirm deployment
echo -e "${YELLOW}Do you want to proceed with the deployment? (y/N):${NC}"
read -r confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting deployment...${NC}"
echo ""

# Create temporary inventory file
temp_inventory=$(mktemp)
cat > "$temp_inventory" << EOF
[vps-servers]
vps-server ansible_host=$vps_ip ansible_user=$ssh_user ansible_ssh_private_key_file=$ssh_private_key_expanded
EOF

# Run the Ansible playbook
ansible-playbook -i "$temp_inventory" setup_vps/ansible/install-docker.yml \
  --limit "vps-servers" \
  --extra-vars "ssh_port=$ssh_port deploy_user_public_key='$deploy_user_public_key'"

# Clean up temporary inventory
rm -f "$temp_inventory"

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Deployment Successful!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}You can now connect to your VPS using:${NC}"
    echo -e "${YELLOW}ssh -p $ssh_port root@$vps_ip${NC}"
    echo ""
    echo -e "${BLUE}Firewall ports opened:${NC}"
    echo -e "${YELLOW}- SSH: $ssh_port${NC}"
    echo -e "${YELLOW}- HTTP: 80${NC}"
    echo -e "${YELLOW}- HTTP: 8080${NC}"
    echo -e "${YELLOW}- HTTPS: 443${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}================================${NC}"
    echo -e "${RED}  Deployment Failed!${NC}"
    echo -e "${RED}================================${NC}"
    echo -e "${YELLOW}Please check the error messages above and try again.${NC}"
    exit 1
fi 