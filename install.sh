#!/bin/bash

# Server Configuration Script
# This script provides a menu-driven interface to perform various server configuration tasks.
# It allows users to install essential apps, set up NGINX and PHP, configure NVM, enable passwordless sudo,
# set up SSH key-based authentication and more.

# Author: Decaded (https://github.com/decaded)

# Function to display a menu and get user's choice
show_menu() {
  clear
  echo "Welcome to the Server Configuration Script"
  echo "You are running this script as user '$USER'"
  echo "----------------------------------------"
  echo "1) Install Essential Apps"
  echo "2) Install NGINX and PHP"
  echo "3) Install Node Version Manager (NVM)"
  echo "4) Enable Passwordless sudo access"
  echo "5) Set up SSH key-based authentication"
  echo "6) Configure Static IP Address"
  echo

  if [ -f "/etc/ssh/sshd_config_decoscript.backup" ]; then
    echo "9) Restore SSH Configuration"
  fi

  echo "0) Exit"
  echo
  read -rp "Enter your choice: " choice
  case $choice in
  1) install_essential_apps ;;
  2) install_nginx_and_php ;;
  3) install_nvm ;;
  4) enable_passwordless_sudo "$USER" ;;
  5) setup_ssh_key_authentication ;;
  6) configure_static_ip ;;
  9)
    if [ -f "/etc/ssh/sshd_config_decoscript.backup" ]; then
      restore_ssh_config
    else
      echo "Invalid choice. Please select a valid option."
      show_menu
    fi
    ;;
  0)
    clear
    read -rp "Do you want to remove the 'install.sh' script file? (Y/n): " delete_script
    if [[ "$delete_script" =~ ^[Yy]$ || "$delete_script" == "" ]]; then
      echo "Deleting the script file..."
      rm "$0"
    else
      echo
      echo "You chose to keep the script file."
      echo "You can remove this script manually using 'rm install.sh'"
    fi
    echo
    echo "Exiting. Goodbye!"
    exit
    ;;
  *)
    echo "Invalid choice. Please select a valid option."
    show_menu
    ;;
  esac
}

# Function to check if the script has sudo privileges
check_sudo_privileges() {
  sudo -n true
  if [ $? -ne 0 ]; then
    echo "You need sudo privilege to run this script."
    exit 1
  fi
}

# Function to install essential apps using dialog
install_essential_apps() {
  clear

  # Check if dialog is installed, and if not, install it
  if ! [ -x "$(command -v dialog)" ]; then
    echo "Dialog is not installed. Installing dialog..."
    sudo apt update && sudo apt install dialog -y

    # Check if the installation was successful
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install dialog. Exiting."
      return
    fi
  fi

  if ! [ -x "$(command -v curl)" ]; then
    echo "Curl is not installed. Installing curl..."
    sudo apt update && sudo apt install curl -y

    # Check if the installation was successful
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install curl. Exiting."
      return
    fi
  fi

  # Define the dialog menu options
  app_options=("1" "htop - Interactive process viewer" off
    "2" "screen - Terminal multiplexer" off
    "3" "nload - Network traffic monitor" off
    "4" "nano - Text editor" off
    "5" "firewalld - Firewall management" off
    "6" "fail2ban - Intrusion prevention system" off
    "7" "unattended-upgrades - Automatic updates" off
    "8" "git - Version control system" off
    "9" "pi-hole - Ad blocker and DHCP server" off)

  # Display the dialog menu and store the user's choices
  choices=$(dialog --clear --title "Essential Apps Installer" --checklist "Choose which apps to install:" 0 0 0 "${app_options[@]}" 2>&1 >/dev/tty)

  # Check if the user canceled or made no selection
  if [ $? -ne 0 ]; then
    clear
    echo "Canceled. Returning to the main menu."
    return
  fi

  # Process user choices and install selected apps
  selected_applications=""

  for choice in $choices; do
    case $choice in
    1) selected_applications+=" htop" ;;
    2) selected_applications+=" screen" ;;
    3) selected_applications+=" nload" ;;
    4) selected_applications+=" nano" ;;
    5) selected_applications+=" firewalld" ;;
    6) selected_applications+=" fail2ban" ;;
    7) selected_applications+=" unattended-upgrades" ;;
    8) selected_applications+=" git" ;;
    9) selected_applications+=" pi-hole" ;;
    esac
  done

  if [ -z "$selected_applications" ]; then
    echo "No apps selected. Returning to the main menu."
    return
  fi

  # Check if Pi-hole was selected
  if [[ "$selected_applications" == *"pi-hole"* ]]; then
    # Pi-hole installation
    echo "Installing Pi-hole..."
    curl -sSL https://install.pi-hole.net | bash
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install Pi-hole. Please check your internet connection and try again."
      return
    fi
  fi

  # Remove Pi-hole from the list of selected applications
  selected_applications="${selected_applications//pi-hole/}"

  # Check if there are any remaining selected applications
  if [ -z "$selected_applications" ]; then
    echo "No apps selected. Returning to the main menu."
    return
  fi

  # Install the remaining selected applications using apt
  echo "Installing selected apps: $selected_applications"
  sudo apt update && sudo apt install $selected_applications -y

  # Check if there was an error during installation
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install some or all of the selected apps. Please check your internet connection and try again."
    return
  fi

  # Check if firewalld was selected
  if [[ "$selected_applications" == *"firewalld"* ]]; then
    configure_firewall
  fi

  # Check if Fail2ban was selected
  if [[ "$selected_applications" == *"fail2ban"* ]]; then
    configure_fail2ban
  fi

  # Check if unattended-upgrades was selected
  if [[ "$selected_applications" == *"unattended-upgrades"* ]]; then
    sudo dpkg-reconfigure -plow unattended-upgrades
  fi

  # Configure Git only if it was selected
  if [[ "$selected_applications" == *"git"* ]]; then
    configure_git
  fi

  echo "Installation complete."
  return
}

# Function to configure the firewall with checks
configure_firewall() {
  clear

  # Check if firewalld is installed
  if ! command -v firewall-cmd &>/dev/null; then
    echo "Firewalld is not installed. Please install it before configuring firewall rules."
    return
  fi

  # Enable firewalld
  sudo systemctl enable firewalld

  echo "#######################################################"
  echo "Firewall configuration"
  echo "## WARNING ##"
  echo "## THIS CAN CUT YOU OUT OF THE SERVER ##"
  echo "## CHECK TWICE BEFORE PROCEEDING ##"
  echo "## YOU HAVE BEEN WARNED ##"
  echo "#######################################################"

  read -rp "Please provide your current SSH port (default is 22): " sshPort

  # Check if the SSH port is already open
  if sudo firewall-cmd --list-ports | grep -q "$sshPort/tcp"; then
    echo "Port $sshPort [TCP] is already open. Skipping."
    return
  fi

  validate_port "$sshPort"
  if [ $? -ne 0 ]; then
    echo "Invalid port input. Exiting."
    exit 1
  fi

  echo "Opening port $sshPort TCP..."
  sudo firewall-cmd --permanent --zone=public --add-port="$sshPort"/tcp
  if [ $? -ne 0 ]; then
    echo "Error: Failed to open firewall port."
    exit 1
  fi

  echo "Reload configuration..."
  sudo firewall-cmd --reload
  if [ $? -ne 0 ]; then
    echo "Error: Failed to reload firewall configuration."
    exit 1
  fi

  echo
}

# Function to set up SSH key-based authentication
setup_ssh_key_authentication() {
  clear

  # Check if SSH service is installed
  if ! dpkg -l | grep -q "openssh-server"; then
    echo "SSH service (openssh-server) is not installed."

    # Ask the user if they want to install SSH service
    read -rp "Do you want to install SSH service? (Y/n): " install_ssh_service

    if [[ "$install_ssh_service" =~ ^[Yy]$ || "$install_ssh_service" == "" ]]; then
      sudo apt update
      sudo apt install openssh-server -y
    else
      echo "SSH service will not be installed. Returning to the main menu."
      return
    fi
  fi

  clear
  # Create a backup of the sshd_config file
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config_decoscript.backup

  echo "#######################################################"
  echo "SSH configuration"
  echo "Backup was made to '/etc/ssh/sshd_config_decoscript.backup'."
  echo "You can restore it using restore function in this script."
  echo "Please provide your public key below."
  echo "#######################################################"

  # Read the user-provided public key and save it to a variable
  IFS= read -r ssh_public_key

  # Create the ~/.ssh directory if it doesn't exist
  mkdir -p "$HOME/.ssh"

  authorized_keys_file="$HOME/.ssh/authorized_keys"

  # Check if the authorized_keys file exists and the key is not already present
  if [ -f "$authorized_keys_file" ] && ! grep -q "$ssh_public_key" "$authorized_keys_file"; then
    # Save the public key to the authorized_keys file
    echo "$ssh_public_key" >>"$authorized_keys_file"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to save the public key to authorized_keys file."
      exit 1
    fi
    echo
    echo "Public key added to authorized_keys."
  elif [ ! -f "$authorized_keys_file" ]; then
    echo "Creating authorized_keys file..."
    echo "$ssh_public_key" >"$authorized_keys_file"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to create authorized_keys file."
      exit 1
    fi
    echo
    echo "Public key added to authorized_keys."
  else
    echo
    echo "The provided public key is already present in authorized_keys. No changes were made."
  fi

  # Enable key-based authentication and disable password-based authentication for SSH
  sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sudo sed -i 's/^#PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sudo sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

  # Restart the SSH service for changes to take effect
  sudo service ssh restart
  if [ $? -ne 0 ]; then
    echo "Error: Failed to restart the SSH service."
    exit 1
  fi

  echo "SSH key-based authentication has been enabled, and password-based authentication has been disabled."

  echo "#######################################################"
  echo
}

# Function to enable passwordless sudo access
enable_passwordless_sudo() {
  clear
  local username="$1"

  if sudo grep -qE "^\s*$username\s+ALL=\(ALL\) NOPASSWD:ALL\s*$" /etc/sudoers; then
    echo "Passwordless sudo access is already enabled for '$username'."
  else
    echo -n "Do you really want to enable passwordless sudo access for '$username'? (y/n): "
    read -r enable_sudo_option

    if [[ "$enable_sudo_option" =~ ^[Yy]$ ]]; then
      # Append to /etc/sudoers using echo and sudo
      echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo
      if [ $? -ne 0 ]; then
        echo "Error: Failed to enable passwordless sudo access."
        exit 1
      fi
      echo "Passwordless sudo access has been enabled for '$username'."
      echo "Please log out and log back in for the changes to take effect."
    else
      echo "Passwordless sudo access will not be enabled."
    fi
  fi
  echo
}

# Function to install NGINX and PHP with firewall checks
install_nginx_and_php() {
  clear

  # Check if NGINX is already installed
  if dpkg -l | grep -q "nginx"; then
    echo "NGINX is already installed. Skipping NGINX installation."
  else
    # Install NGINX
    sudo apt install nginx -y
  fi

  # Check if PHP is already installed
  if dpkg -l | grep -q "php8.4"; then
    echo "PHP is already installed. Skipping PHP installation."
  else
    # Install PHP
    sudo apt install php8.4 php8.4-fpm -y
  fi

  # Remove apache2 if it exists
  if dpkg -l | awk '/apache2/ {print }' | grep -q .; then
    echo "Apache2 is installed. Removing."
    sudo service apache2 stop
    sudo apt remove apache2 -y
    sudo apt purge apache2 -y
    sudo apt autoremove -y
    sudo service nginx start # start nginx after removing apache
  fi

  echo "#######################################################"
  echo "Firewall configuration"
  echo "#######################################################"

  # Check if firewalld is installed
  if ! command -v firewall-cmd &>/dev/null; then
    echo "Firewalld is not installed. Skipping."

  else
    # Check if port 80 is open
    if ! sudo firewall-cmd --list-ports | grep -q "80/tcp"; then
      echo "Opening port 80 [TCP]..."
      sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
    else
      echo "Port 80 [TCP] is already open. Skipping."
    fi

    # Check if port 443 is open
    if ! sudo firewall-cmd --list-ports | grep -q "443/tcp"; then
      echo "Opening port 443 [TCP]..."
      sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
    else
      echo "Port 443 [TCP] is already open. Skipping."
    fi

    echo "Reload configuration..."
    sudo firewall-cmd --reload
    echo
  fi

  # Create a directory for SSL certs if it doesn't exist
  if [ -d "/etc/nginx/cert" ]; then
    echo "Directory /etc/nginx/cert exists, skipping."
  else
    echo "Creating directory /etc/nginx/cert"
    sudo mkdir /etc/nginx/cert # make folder for SSL certs so it's easier for me to just dump them there later
  fi

  echo
  echo "Finished setting up NGINX and PHP."
  echo "You can upload SSL certificates into /etc/nginx/cert"
  echo
}

# Function to install Node Version Manager (NVM)
install_nvm() {
  clear
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm ls-remote
  echo "Above you can see a list of all available NodeJS versions."
  echo "Choose NodeJS version to install (e.g., 18.17.0):"
  read -r versionToInstall
  nvm install "$versionToInstall"
  echo
}

# Function to restore SSH configuration
restore_ssh_config() {
  clear
  if [[ -f "/etc/ssh/sshd_config_decoscript.backup" ]]; then
    echo "Restoring SSH configuration..."
    sudo cp /etc/ssh/sshd_config_decoscript.backup /etc/ssh/sshd_config
    if [ $? -ne 0 ]; then
      echo "Error: Failed to restore SSH configuration."
      exit 1
    fi

    sudo service ssh restart
    if [ $? -ne 0 ]; then
      echo "Error: Failed to restart the SSH service."
      exit 1
    fi

    echo "SSH configuration has been restored."
    sudo rm /etc/ssh/sshd_config_decoscript.backup
  else
    echo "Error: Backup file /etc/ssh/sshd_config_decoscript.backup not found."
  fi
}

# Function to validate if a given input is a valid port number
validate_port() {
  local port="$1"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo "Error: Invalid port number. Please enter a valid numeric port between 1 and 65535."
    return 1 # Invalid port
  fi
  return 0 # Valid port
}

# Function to configure Git
configure_git() {
  while true; do
    clear
    echo "Git Configuration"

    # Check if there is already a defined Git user
    current_git_name=$(git config --global user.name)

    if [ -n "$current_git_name" ]; then
      echo "Git user '$current_git_name' is already defined."
      read -rp "Do you want to change the Git user configuration? (y/N): " git_change_config

      case "$git_change_config" in
      [yY])
        configure_git_user
        ;;
      *)
        echo "Skipping Git configuration."
        break
        ;;
      esac
    else
      configure_git_user
    fi

    # Ask the user to confirm the changes
    read -rp "Are these changes correct? (y/N): " confirm_changes

    case "$confirm_changes" in
    [yY])
      echo
      echo "Remember, You can always check your configuration by running 'git config --list' in the console."
      echo
      break
      ;;
    *)
      echo "Reconfiguring Git..."
      ;;
    esac
  done
}

# Function to configure Git user
configure_git_user() {
  clear
  echo "Git User Configuration"
  read -rp "Enter your Git name: " git_name
  read -rp "Enter your Git email: " git_email
  read -rp "Enter the default Git branch (default is 'master'): " git_default_branch

  # Set default branch to 'master' if input is empty
  git_default_branch=${git_default_branch:-"master"}

  # Set Git configurations
  git config --global user.name "$git_name"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch "$git_default_branch"

  # Display the changes
  echo
  echo "Git has been configured with name: $git_name, email: $git_email, and default branch: $git_default_branch."
}

# Function to configure fail2ban
configure_fail2ban() {
  clear
  echo "Choose the Fail2ban configuration to use:"
  echo "1) Default configuration"
  echo "2) User custom configuration (provide link)"

  # Read user input
  read -rp "Enter your choice (1/2): " fail2ban_config_choice

  case $fail2ban_config_choice in
  1)
    echo "Installing Fail2ban with default configuration..."
    # Install Fail2ban
    sudo apt install fail2ban -y
    ;;
  2)
    read -rp "Enter the URL of the user custom configuration: " fail2ban_custom_config_url

    # Check if the URL is valid and accessible
    if wget --spider "$fail2ban_custom_config_url" 2>/dev/null; then
      # Install Fail2ban if not already installed
      sudo apt install fail2ban -y
      sudo wget -O /etc/fail2ban/jail.local "$fail2ban_custom_config_url"
      echo "User custom Fail2ban configuration applied."
    else
      echo "Warning: Invalid URL or unable to reach the URL. Using the default configuration."
      # Install Fail2ban with the default configuration
      sudo apt install fail2ban -y
    fi
    ;;
  *)
    echo "Invalid choice. Using the default configuration."
    ;;
  esac

  echo "Fail2ban configuration completed."
}

# Function to configure a static IP address using Netplan
configure_static_ip() {
  clear
  echo "Configuring a static IP address using Netplan."

  # Check if Netplan is installed, and if not, install it
  if ! [ -x "$(command -v netplan)" ]; then
    echo "Netplan is not installed. Installing..."
    sudo apt update && sudo apt install netplan -y
  fi

  # Check if ifconfig is installed, and if not, install it
  if ! [ -x "$(command -v ifconfig)" ]; then
    echo "Ifconfig (net-tools) is not installed. Installing..."
    sudo apt update && sudo apt install net-tools -y
  fi

  # Get network device information from 'ifconfig -a'
  device_info=$(sudo ifconfig -a)

  # Display available network devices
  echo "Available network devices:"
  echo "$device_info"

  # Prompt the user to enter the desired network device
  read -rp "Enter the network device name (e.g., enp5s0): " network_device

  # Check if the selected device exists in the device information
  if ! echo "$device_info" | grep -q "$network_device:"; then
    echo "Error: The selected network device '$network_device' does not exist. Please enter a valid device name."
    return
  fi

  # Prompt the user for IP address, net mask, gateway, and DNS servers
  read -rp "Enter the static IP address (e.g., 192.168.1.100): " static_ip_address
  read -rp "Enter the net mask (e.g., 20): " net_mask
  read -rp "Enter the gateway (e.g., 192.168.1.1): " gateway
  read -rp "Enter DNS server 1 (e.g., 8.8.8.8): " dns_server_1
  read -rp "Enter DNS server 2 (optional, press Enter to skip): " dns_server_2

  # Check if any of the mandatory fields are empty
  if [ -z "$static_ip_address" ] || [ -z "$net_mask" ] || [ -z "$gateway" ] || [ -z "$dns_server_1" ]; then
    echo "Error: All mandatory fields must be filled. Aborting static IP configuration."
    return
  fi

  # Create a Netplan configuration file for the static IP address
  cat <<EOL | sudo tee "/etc/netplan/01-network-manager-all.yaml" >/dev/null
network:
  version: 2
  ethernets:
    $network_device:
      addresses: [$static_ip_address/$net_mask]
      gateway4: $gateway
      nameservers:
        addresses: [$dns_server_1${dns_server_2:+, $dns_server_2}]
EOL

  # Apply the Netplan configuration
  sudo netplan apply

  echo "Static IP address configuration completed for $network_device."
}

# Main script
check_sudo_privileges

while true; do
  show_menu
  read -rp "Press Enter to continue..."
done
