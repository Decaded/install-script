#!/bin/bash

# Server Configuration Script
# This script provides a menu-driven interface to perform various server configuration tasks.
# It allows users to install essential apps, set up a web server, configure NVM, enable passwordless sudo,
# set up SSH key-based authentication and more.

# Author: Decaded (https://github.com/Decaded)

# Script version
SCRIPT_VERSION="2.0.1"
SCRIPT_URL="https://raw.githubusercontent.com/Decaded/install-script/refs/heads/main/install.sh"

# Function to display a menu and get user's choice
show_menu() {
  clear
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║   Server Configuration Script v$SCRIPT_VERSION"
  echo "║   Running as: $USER"
  echo "╚════════════════════════════════════════════════════════╝"
  echo
  echo "1) Install Essential Apps"
  echo "2) Install Web Server (LEMP/NGINX)"
  echo "3) Install Node Version Manager (NVM)"
  echo "4) Enable Passwordless sudo access"
  echo "5) Set up SSH key-based authentication"
  echo "6) Configure Static IP Address"
  echo "7) Configure Fail2ban"
  echo
  echo "r) Revert Static IP to DHCP"
  echo "u) Check for script updates"
  echo

  if [ -f "/etc/ssh/sshd_config_decoscript.backup" ]; then
    echo "9) Restore SSH Configuration"
  fi

  echo "0) Exit"
  echo
  read -rp "Enter your choice: " choice
  case $choice in
  1) install_essential_apps ;;
  2) install_web_server_menu ;;
  3) install_nvm ;;
  4) enable_passwordless_sudo "$USER" ;;
  5) setup_ssh_key_authentication ;;
  6) configure_static_ip ;;
  7) configure_fail2ban ;;
  r|R) revert_static_ip ;;
  u|U) check_for_updates ;;
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

# Bash-native CIDR to netmask conversion
cidr_to_netmask() {
  local bits=$1
  local mask=$((0xffffffff ^ ((1 << (32 - bits)) - 1)))
  printf "%d.%d.%d.%d\n" \
    $(((mask >> 24) & 0xff)) \
    $(((mask >> 16) & 0xff)) \
    $(((mask >> 8) & 0xff)) \
    $((mask & 0xff))
}

# Function to check for script updates
check_for_updates() {
  clear
  echo "Checking for script updates..."
  echo
  
  # Check if curl is available
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is not installed. Cannot check for updates."
    echo "Install curl to enable update checking: sudo apt install curl"
    return 0
  fi
  
  # Try to fetch remote version (allow failure)
  local remote_version=""
  remote_version=$(curl -fsSL --max-time 5 "$SCRIPT_URL" 2>/dev/null | grep -m1 "^SCRIPT_VERSION=" | cut -d'"' -f2 || true)
  
  # If we couldn't get the remote version, fail gracefully
  if [ -z "$remote_version" ]; then
    echo "Could not check for updates (network issue or GitHub unavailable)."
    echo "Current version: $SCRIPT_VERSION"
    return 0
  fi
  
  # Compare versions
  if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
    echo "================================"
    echo "  UPDATE AVAILABLE!"
    echo "================================"
    echo "Current version:  $SCRIPT_VERSION"
    echo "Latest version:   $remote_version"
    echo
    read -rp "Would you like to update now? (y/N): " update_choice
    
    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
      update_script
    else
      echo "Update skipped. You can update later by selecting option 'u' from the menu."
    fi
  else
    echo "You are running the latest version ($SCRIPT_VERSION)"
    echo "No update needed."
  fi
  
  echo
  read -rp "Press Enter to return to menu..."
  return 0
}

# Function to update the script
update_script() {
  echo
  echo "Downloading latest version..."
  local temp_script="/tmp/install_sh_update_$"
  
  if curl -fsSL --max-time 10 -o "$temp_script" "$SCRIPT_URL" 2>/dev/null; then
    # Verify the download
    if [ -f "$temp_script" ] && [ -s "$temp_script" ]; then
      chmod +x "$temp_script"
      
      # Backup current script
      cp "$0" "${0}.backup" 2>/dev/null || true
      
      # Replace with new version
      mv "$temp_script" "$0"
      
      echo "✓ Script updated successfully!"
      echo "  Backup saved as: ${0}.backup"
      echo
      echo "Please run the script again to use the new version."
      echo "Exiting..."
      exit 0
    else
      echo "Error: Downloaded file is empty or invalid."
      rm -f "$temp_script" 2>/dev/null
      return 1
    fi
  else
    echo "Error: Failed to download update."
    rm -f "$temp_script" 2>/dev/null
    return 1
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

  # Strip quotes from dialog output
  choices=$(echo "$choices" | tr -d '"')

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
  
  # Backup with max 5 kept
  local max_backups=5
  local backup_name="/etc/ssh/sshd_config_decoscript.backup.$(date +%Y%m%d%H%M%S)"
  
  # Create a backup of the sshd_config file
  sudo cp /etc/ssh/sshd_config "$backup_name"
  echo "Backup created: $backup_name"
  
  # Clean old backups, keep only the most recent $max_backups
  local backup_count=$(ls -1t /etc/ssh/sshd_config_decoscript.backup.* 2>/dev/null | wc -l)
  if [ "$backup_count" -gt "$max_backups" ]; then
    echo "Cleaning old backups (keeping $max_backups most recent)..."
    ls -1t /etc/ssh/sshd_config_decoscript.backup.* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs -r sudo rm -f
  fi

  echo "#######################################################"
  echo "SSH configuration"
  echo "Backup was made to '$backup_name'."
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

  local nginx_installed=false
  
  # Check if NGINX is already installed
  if dpkg -l | grep -q "nginx"; then
    echo "NGINX is already installed. Skipping NGINX installation."
    nginx_installed=true
  else
    # Install NGINX
    sudo apt install nginx -y
    nginx_installed=true
  fi

  # Detect latest available PHP version
  echo "Detecting latest available PHP version..."
  local php_versions=(8.4 8.3 8.2 8.1 8.0)
  local php_version=""
  
  for ver in "${php_versions[@]}"; do
    if apt-cache policy "php$ver" 2>/dev/null | grep -q 'Candidate:'; then
      php_version="$ver"
      break
    fi
  done
  
  if [ -z "$php_version" ]; then
    echo "No specific PHP version found, using default 'php' package."
    if $nginx_installed; then
      sudo apt install php php-fpm -y
    else
      sudo apt install php -y
    fi
  else
    echo "Found PHP $php_version available."
    if $nginx_installed; then
      sudo apt install "php$php_version" "php$php_version-fpm" -y
    else
      sudo apt install "php$php_version" -y
    fi
  fi

  # Remove apache2 if it exists
  if dpkg -l | awk '/apache2/ {print }' | grep -q .; then
    echo "Apache2 is installed. Removing."
    sudo service apache2 stop
    sudo apt remove apache2 -y
    sudo apt purge apache2 -y
    sudo apt autoremove -y
    sudo systemctl start nginx || true
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
  if [ ! -d "/etc/nginx/cert" ]; then
    echo "Creating directory /etc/nginx/cert"
    sudo mkdir -p /etc/nginx/cert
    sudo chmod 700 /etc/nginx/cert
  fi

  echo
  echo "Finished setting up NGINX and PHP."
  echo "You can upload SSL certificates into /etc/nginx/cert"
  echo
}

# Function to show web server installation menu
install_web_server_menu() {
  clear
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║          Web Server Installation Menu                  ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo
  echo "Choose what to install:"
  echo
  echo "1) LEMP Stack (Linux + NGINX + MySQL + PHP)"
  echo "2) NGINX + PHP"
  echo "3) NGINX only"
  echo "0) Back to main menu"
  echo
  read -rp "Enter your choice: " web_choice
  
  case $web_choice in
    1) install_lemp_stack ;;
    2) install_nginx_php ;;
    3) install_nginx_only ;;
    0) return ;;
    *)
      echo "Invalid choice."
      sleep 2
      install_web_server_menu
      ;;
  esac
}

# Function to install LEMP stack
install_lemp_stack() {
  clear
  echo "Installing LEMP Stack (NGINX + MySQL + PHP)..."
  echo
  
  # Install NGINX
  install_nginx_base
  
  # Install MySQL
  echo
  echo "Installing MySQL Server..."
  sudo apt install mysql-server -y
  
  # Secure MySQL installation prompt
  echo
  echo "MySQL installed. It's recommended to run mysql_secure_installation."
  read -rp "Do you want to run mysql_secure_installation now? (Y/n): " run_secure
  
  if [[ "$run_secure" =~ ^[Nn]$ ]]; then
    echo "You can run 'sudo mysql_secure_installation' manually later."
  else
    sudo mysql_secure_installation
  fi
  
  # Install PHP
  echo
  install_php_with_extensions
  
  # Configure NGINX for PHP
  configure_nginx_php
  
  # Final setup
  finalize_web_server_install
  
  echo
  echo "═══════════════════════════════════════════════════════"
  echo "LEMP Stack installation completed!"
  echo "═══════════════════════════════════════════════════════"
  echo "Services installed:"
  echo "  - NGINX web server"
  echo "  - MySQL database server"
  echo "  - PHP with PHP-FPM"
  echo
  echo "Next steps:"
  echo "  1. Place your website files in /var/www/html/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in /etc/nginx/cert/"
  echo "  4. MySQL: sudo mysql -u root -p"
  echo "═══════════════════════════════════════════════════════"
  read -rp "Press Enter to continue..."
}

# Function to install NGINX + PHP
install_nginx_php() {
  clear
  echo "Installing NGINX + PHP..."
  echo
  
  install_nginx_base
  echo
  install_php_with_extensions
  configure_nginx_php
  finalize_web_server_install
  
  echo
  echo "═══════════════════════════════════════════════════════"
  echo "NGINX + PHP installation completed!"
  echo "═══════════════════════════════════════════════════════"
  echo "Services installed:"
  echo "  - NGINX web server"
  echo "  - PHP with PHP-FPM"
  echo
  echo "Next steps:"
  echo "  1. Place your website files in /var/www/html/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in /etc/nginx/cert/"
  echo "═══════════════════════════════════════════════════════"
  read -rp "Press Enter to continue..."
}

# Function to install NGINX only
install_nginx_only() {
  clear
  echo "Installing NGINX only..."
  echo
  
  install_nginx_base
  configure_nginx_static
  finalize_web_server_install
  
  echo
  echo "═══════════════════════════════════════════════════════"
  echo "NGINX installation completed!"
  echo "═══════════════════════════════════════════════════════"
  echo "Service installed:"
  echo "  - NGINX web server"
  echo
  echo "Next steps:"
  echo "  1. Place your static files in /var/www/html/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in /etc/nginx/cert/"
  echo "═══════════════════════════════════════════════════════"
  read -rp "Press Enter to continue..."
}

# Helper: Install NGINX base
install_nginx_base() {
  if dpkg -l | grep -q "^ii.*nginx"; then
    echo "NGINX is already installed."
  else
    echo "Installing NGINX..."
    sudo apt install nginx -y
  fi
  
  # Remove apache2 if it exists
  if dpkg -l | grep -q "^ii.*apache2"; then
    echo "Apache2 detected. Removing to avoid conflicts..."
    sudo systemctl stop apache2 2>/dev/null || true
    sudo apt remove --purge apache2 apache2-utils apache2-bin apache2.2-common -y
    sudo apt autoremove -y
  fi
  
  # Ensure NGINX is enabled and started
  sudo systemctl enable nginx
  sudo systemctl start nginx
}

# Helper: Install PHP with common extensions
install_php_with_extensions() {
  echo "Detecting latest available PHP version..."
  local php_versions=(8.4 8.3 8.2 8.1 8.0)
  local php_version=""
  
  for ver in "${php_versions[@]}"; do
    if apt-cache policy "php$ver" 2>/dev/null | grep -q 'Candidate:'; then
      php_version="$ver"
      break
    fi
  done
  
  if [ -z "$php_version" ]; then
    echo "Using default PHP packages..."
    sudo apt install php php-fpm php-mysql php-cli php-common php-curl php-gd php-mbstring php-xml php-zip -y
  else
    echo "Installing PHP $php_version with extensions..."
    sudo apt install "php$php_version" "php$php_version-fpm" "php$php_version-mysql" \
      "php$php_version-cli" "php$php_version-common" "php$php_version-curl" \
      "php$php_version-gd" "php$php_version-mbstring" "php$php_version-xml" \
      "php$php_version-zip" -y
  fi
  
  # Enable and start PHP-FPM
  sudo systemctl enable php*-fpm
  sudo systemctl start php*-fpm
}

# Helper: Configure NGINX for PHP
configure_nginx_php() {
  echo
  echo "Configuring NGINX for PHP..."
  
  # Backup default config
  if [ -f /etc/nginx/sites-available/default ]; then
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
  fi
  
  # Detect PHP-FPM socket
  local php_socket=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)
  
  if [ -z "$php_socket" ]; then
    echo "Warning: Could not detect PHP-FPM socket. Using default."
    php_socket="/run/php/php-fpm.sock"
  fi
  
  # Create a working default config
  sudo tee /etc/nginx/sites-available/default >/dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_socket;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  # Test and reload NGINX
  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx
    echo "NGINX configured for PHP successfully."
  else
    echo "Warning: NGINX configuration test failed. Please check manually."
  fi
  
  # Create a test PHP file
  echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php >/dev/null
  echo
  echo "Test PHP installation: http://your-server-ip/info.php"
  echo "Remember to delete /var/www/html/info.php after testing!"
}

# Helper: Configure NGINX for static files only
configure_nginx_static() {
  echo
  echo "Configuring NGINX for static content..."
  
  # Backup default config
  if [ -f /etc/nginx/sites-available/default ]; then
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
  fi
  
  # Create a clean static config
  sudo tee /etc/nginx/sites-available/default >/dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  # Test and reload NGINX
  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx
    echo "NGINX configured successfully."
  else
    echo "Warning: NGINX configuration test failed. Please check manually."
  fi
}

# Helper: Finalize web server installation
finalize_web_server_install() {
  echo
  echo "Finalizing installation..."
  
  # Create cert directory
  if [ ! -d "/etc/nginx/cert" ]; then
    sudo mkdir -p /etc/nginx/cert
    sudo chmod 700 /etc/nginx/cert
    echo "Created /etc/nginx/cert for SSL certificates."
  fi
  
  # Ensure web root exists with correct permissions
  if [ ! -d "/var/www/html" ]; then
    sudo mkdir -p /var/www/html
  fi
  sudo chown -R www-data:www-data /var/www/html
  
  # Create a simple index.html if none exists
  if [ ! -f "/var/www/html/index.html" ] && [ ! -f "/var/www/html/index.php" ]; then
    sudo tee /var/www/html/index.html >/dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to NGINX</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #009639; }
    </style>
</head>
<body>
    <h1>NGINX is working!</h1>
    <p>If you see this page, the web server is successfully installed and working.</p>
</body>
</html>
EOF
    sudo chown www-data:www-data /var/www/html/index.html
  fi
  
  # Configure firewall if available
  if command -v firewall-cmd &>/dev/null; then
    echo
    echo "Configuring firewall..."
    
    if ! sudo firewall-cmd --list-ports | grep -q "80/tcp"; then
      sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
      echo "Opened port 80 (HTTP)."
    fi
    
    if ! sudo firewall-cmd --list-ports | grep -q "443/tcp"; then
      sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
      echo "Opened port 443 (HTTPS)."
    fi
    
    sudo firewall-cmd --reload
  fi
  
  echo "Setup complete!"
}

# Function to install Node Version Manager (NVM)
install_nvm() {
  clear
  # Using master branch to always get latest NVM
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  
  echo "Fetching available NodeJS versions (showing latest 20)..."
  nvm ls-remote | tail -20
  echo
  echo "Above you can see a list of the latest available NodeJS versions."
  echo "Choose NodeJS version to install (e.g., 18.17.0):"
  read -r versionToInstall
  
  if [ -n "$versionToInstall" ]; then
    nvm install "$versionToInstall"
  else
    echo "No version specified, skipping Node installation."
  fi
  echo
}

# Function to restore SSH configuration
restore_ssh_config() {
  clear
  
  # Find the most recent backup
  local backup
  backup=$(ls -1t /etc/ssh/sshd_config_decoscript.backup.* 2>/dev/null | head -n1)
  
  if [ -z "$backup" ]; then
    echo "Error: No backup files found matching /etc/ssh/sshd_config_decoscript.backup.*"
    return
  fi
  
  echo "Found backup: $backup"
  read -rp "Do you want to restore SSH configuration from this backup? (y/N): " confirm_restore
  
  if [[ ! "$confirm_restore" =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    return
  fi
  
  echo "Restoring SSH configuration..."
  sudo cp "$backup" /etc/ssh/sshd_config
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
  
  read -rp "Do you want to keep the backup file? (Y/n): " keep_backup
  if [[ "$keep_backup" =~ ^[Nn]$ ]]; then
    sudo rm "$backup"
    echo "Backup file deleted."
  else
    echo "Backup file kept at: $backup"
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
    current_git_name=$(git config --global user.name 2>/dev/null)

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
    sudo apt update && sudo apt install netplan.io -y
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
  read -rp "Enter the CIDR prefix (e.g., 24): " net_mask
  read -rp "Enter the gateway (e.g., 192.168.1.1): " gateway
  read -rp "Enter DNS server 1 (e.g., 8.8.8.8): " dns_server_1
  read -rp "Enter DNS server 2 (optional, press Enter to skip): " dns_server_2

  # Check if any of the mandatory fields are empty
  if [ -z "$static_ip_address" ] || [ -z "$net_mask" ] || [ -z "$gateway" ] || [ -z "$dns_server_1" ]; then
    echo "Error: All mandatory fields must be filled. Aborting static IP configuration."
    return
  fi

  # Backup existing netplan configs before making changes
  local backup_dir="/etc/netplan/backups_decoscript"
  if [ ! -d "$backup_dir" ]; then
    sudo mkdir -p "$backup_dir"
  fi
  
  local backup_timestamp=$(date +%Y%m%d%H%M%S)
  if [ -f "/etc/netplan/01-network-manager-all.yaml" ]; then
    sudo cp "/etc/netplan/01-network-manager-all.yaml" "$backup_dir/01-network-manager-all.yaml.$backup_timestamp"
    echo "Backup created: $backup_dir/01-network-manager-all.yaml.$backup_timestamp"
  fi

  # Determine renderer based on what's actually being used
  local renderer="networkd"
  if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "NetworkManager is active, using NetworkManager renderer."
    renderer="NetworkManager"
  else
    echo "Using networkd renderer (systemd-networkd)."
  fi

  # Create a Netplan configuration file for the static IP address
  cat <<EOL | sudo tee "/etc/netplan/01-network-manager-all.yaml" >/dev/null
network:
  version: 2
  renderer: $renderer
  ethernets:
    $network_device:
      addresses: [$static_ip_address/$net_mask]
      routes:
        - to: default
          via: $gateway
      nameservers:
        addresses: [$dns_server_1${dns_server_2:+, $dns_server_2}]
EOL

  # Set correct permissions (netplan requires 600 or 640)
  sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
  echo "Set netplan file permissions to 600 (owner read/write only)."

  # Apply the Netplan configuration
  sudo netplan apply

  echo "Static IP address configuration completed for $network_device."
}

# Function to revert static IP configuration to DHCP
revert_static_ip() {
  clear
  echo "Revert Static IP to DHCP"
  echo "========================================"
  
  # Check if the netplan file exists
  if [ ! -f "/etc/netplan/01-network-manager-all.yaml" ]; then
    echo "No static IP configuration found at /etc/netplan/01-network-manager-all.yaml"
    echo "Nothing to revert."
    return
  fi
  
  echo "This will remove the static IP configuration and revert to DHCP."
  echo "Current configuration file: /etc/netplan/01-network-manager-all.yaml"
  echo
  read -rp "Do you want to proceed? (y/N): " confirm_revert
  
  if [[ ! "$confirm_revert" =~ ^[Yy]$ ]]; then
    echo "Revert cancelled."
    return
  fi
  
  # Get network device information
  if [ -x "$(command -v ifconfig)" ]; then
    device_info=$(sudo ifconfig -a)
    echo "Available network devices:"
    echo "$device_info"
  else
    echo "Available network devices:"
    ip -brief link show
  fi
  
  read -rp "Enter the network device name to configure DHCP (e.g., enp5s0): " network_device
  
  if [ -z "$network_device" ]; then
    echo "Error: Network device name is required."
    return
  fi
  
  # Create backup before reverting
  local backup_dir="/etc/netplan/backups_decoscript"
  if [ ! -d "$backup_dir" ]; then
    sudo mkdir -p "$backup_dir"
  fi
  
  local backup_timestamp=$(date +%Y%m%d%H%M%S)
  sudo cp "/etc/netplan/01-network-manager-all.yaml" "$backup_dir/01-network-manager-all.yaml.$backup_timestamp"
  echo "Backup created: $backup_dir/01-network-manager-all.yaml.$backup_timestamp"
  
  # Determine renderer
  local renderer="networkd"
  if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "NetworkManager is active, using NetworkManager renderer."
    renderer="NetworkManager"
  else
    echo "Using networkd renderer (systemd-networkd)."
  fi
  
  # Create DHCP configuration
  cat <<EOL | sudo tee "/etc/netplan/01-network-manager-all.yaml" >/dev/null
network:
  version: 2
  renderer: $renderer
  ethernets:
    $network_device:
      dhcp4: true
      dhcp6: false
EOL

  # Set correct permissions
  sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
  
  # Apply the configuration
  echo "Applying DHCP configuration..."
  sudo netplan apply
  
  if [ $? -eq 0 ]; then
    echo
    echo "Successfully reverted to DHCP configuration."
    echo "Your network device '$network_device' will now obtain IP address automatically."
  else
    echo
    echo "Error: Failed to apply netplan configuration."
    echo "You can restore from backup: $backup_dir/01-network-manager-all.yaml.$backup_timestamp"
  fi
}

# Main script
check_sudo_privileges

while true; do
  show_menu
  read -rp "Press Enter to continue..."
done
