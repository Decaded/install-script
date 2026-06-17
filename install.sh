#!/bin/bash

# Server Configuration Script
# This script provides a menu-driven interface to perform various server configuration tasks.
# It allows users to install essential apps, set up a web server, configure NVM, enable passwordless sudo,
# set up SSH key-based authentication and more.

# Author: Decaded (https://github.com/Decaded | https://decaded.dev)

# Sections:
# - Metadata and Constants
# - Common Helpers
# - Menu and Routing
# - Update System
# - Essential Apps
# - Firewalld
# - SSH
# - Passwordless Sudo
# - Web Server
# - NVM
# - Git
# - Fail2ban
# - Static IP / Netplan
# - Main

# ==============================================================================
# Metadata and Constants
# ==============================================================================

SCRIPT_VERSION="3.0.0"
SCRIPT_URL="https://raw.githubusercontent.com/Decaded/install-script/refs/heads/main/install.sh"

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_BACKUP_PATTERN="/etc/ssh/sshd_config_decoscript.backup.*"
FIREWALLD_CONF="/etc/firewalld/firewalld.conf"
NETPLAN_CONFIG="/etc/netplan/01-network-manager-all.yaml"
NGINX_DEFAULT_SITE="/etc/nginx/sites-available/default"
NGINX_CERT_DIR="/etc/nginx/cert"
WEB_ROOT="/var/www/html"

# ==============================================================================
# Common Helpers
# ==============================================================================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

apt_install() {
  if [ "$#" -eq 0 ]; then
    return 0
  fi

  sudo apt update && sudo apt install "$@" -y
}

check_sudo_privileges() {
  sudo -n true
  if [ $? -ne 0 ]; then
    echo "You need sudo privilege to run this script."
    exit 1
  fi
}

validate_port() {
  local port="$1"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo "Error: Invalid port number. Please enter a valid numeric port between 1 and 65535."
    return 1
  fi
  return 0
}

has_ssh_config_backup() {
  compgen -G "$SSH_BACKUP_PATTERN" >/dev/null
}

latest_ssh_config_backup() {
  ls -1t $SSH_BACKUP_PATTERN 2>/dev/null | head -n1
}

# ==============================================================================
# Menu and Routing
# ==============================================================================

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

  if has_ssh_config_backup; then
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
    if has_ssh_config_backup; then
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

# ==============================================================================
# Update System
# ==============================================================================

check_for_updates() {
  clear
  echo "Checking for script updates..."
  echo
  
  # Check if curl is available
  if ! command_exists curl; then
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
      
      # Backup current script and remove execute permissions from backup
      cp "$0" "${0}.backup" 2>/dev/null && chmod -x "${0}.backup" 2>/dev/null || true
      
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

# ==============================================================================
# Essential Apps
# ==============================================================================

install_essential_apps() {
  clear

  if ! command_exists dialog; then
    echo "Dialog is not installed. Installing dialog..."
    if ! apt_install dialog; then
      echo "Error: Failed to install dialog. Exiting."
      return
    fi
  fi

  if ! command_exists curl; then
    echo "Curl is not installed. Installing curl..."
    if ! apt_install curl; then
      echo "Error: Failed to install curl. Exiting."
      return
    fi
  fi

  local app_options=(
    "htop" "Process monitor - htop" off
    "btop" "Process monitor - btop" off
    "screen" "Terminal multiplexer - screen" off
    "tmux" "Terminal multiplexer - tmux" off
    "nload" "Network traffic monitor" off
    "nano" "Text editor - nano" off
    "neovim" "Text editor - Neovim" off
    "firewalld" "Firewall management" off
    "fail2ban" "Intrusion prevention system" off
    "unattended-upgrades" "Automatic updates" off
    "git" "Version control system" off
    "pi-hole" "Ad blocker and DHCP server" off
  )
  local selected_packages=()
  local choices
  local choice
  local install_pihole=false
  local configure_firewalld=false
  local configure_fail2ban_after_install=false
  local configure_unattended_upgrades=false
  local configure_git_after_install=false

  choices=$(dialog --clear --title "Essential Apps Installer" --checklist "Choose which apps to install:" 0 0 0 "${app_options[@]}" 2>&1 >/dev/tty)

  if [ $? -ne 0 ]; then
    clear
    echo "Canceled. Returning to the main menu."
    return
  fi

  choices=$(echo "$choices" | tr -d '"')

  for choice in $choices; do
    case $choice in
    htop|btop|screen|tmux|nload|nano|neovim)
      selected_packages+=("$choice")
      ;;
    firewalld)
      selected_packages+=("firewalld")
      configure_firewalld=true
      ;;
    fail2ban)
      selected_packages+=("fail2ban")
      configure_fail2ban_after_install=true
      ;;
    unattended-upgrades)
      selected_packages+=("unattended-upgrades")
      configure_unattended_upgrades=true
      ;;
    git)
      selected_packages+=("git")
      configure_git_after_install=true
      ;;
    pi-hole)
      install_pihole=true
      ;;
    esac
  done

  if [ ${#selected_packages[@]} -eq 0 ] && ! $install_pihole; then
    echo "No apps selected. Returning to the main menu."
    return
  fi

  if $install_pihole; then
    echo "Installing Pi-hole..."
    curl -sSL https://install.pi-hole.net | bash
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install Pi-hole. Please check your internet connection and try again."
      return
    fi
  fi

  if [ ${#selected_packages[@]} -gt 0 ]; then
    echo "Installing selected apps: ${selected_packages[*]}"
    if ! apt_install "${selected_packages[@]}"; then
      echo "Error: Failed to install some or all of the selected apps. Please check your internet connection and try again."
      return
    fi
  fi

  if $configure_firewalld; then
    configure_firewall
  fi

  if $configure_fail2ban_after_install; then
    configure_fail2ban
  fi

  if $configure_unattended_upgrades; then
    sudo dpkg-reconfigure -plow unattended-upgrades
  fi

  if $configure_git_after_install; then
    configure_git
  fi

  echo "Installation complete."
}

# ==============================================================================
# Firewalld
# ==============================================================================

ensure_firewalld_installed() {
  command_exists firewall-cmd
}

is_firewalld_running() {
  sudo firewall-cmd --state >/dev/null 2>&1
}

is_armbian_system() {
  if [ -f "/etc/armbian-release" ]; then
    return 0
  fi

  if [ -f "/etc/os-release" ]; then
    grep -qiE '^(ID|ID_LIKE|NAME|PRETTY_NAME)=.*armbian' /etc/os-release
    return $?
  fi

  return 1
}

ensure_firewalld_iptables_dependencies() {
  local missing_packages=()

  if ! package_installed iptables; then
    missing_packages+=("iptables")
  fi

  if ! package_installed ipset; then
    missing_packages+=("ipset")
  fi

  if [ ${#missing_packages[@]} -eq 0 ]; then
    return 0
  fi

  echo "Installing firewalld iptables backend dependencies: ${missing_packages[*]}"
  apt_install "${missing_packages[@]}"
}

set_firewalld_iptables_backend() {
  local backup_name="${FIREWALLD_CONF}.decoscript.backup.$(date +%Y%m%d%H%M%S)"
  local vendor_conf=""

  echo "Trying firewalld iptables backend fallback..."

  if ! ensure_firewalld_iptables_dependencies; then
    echo "Error: Failed to install firewalld iptables backend dependencies."
    return 1
  fi

  if [ -f "/usr/lib/firewalld/firewalld.conf" ]; then
    vendor_conf="/usr/lib/firewalld/firewalld.conf"
  elif [ -f "/lib/firewalld/firewalld.conf" ]; then
    vendor_conf="/lib/firewalld/firewalld.conf"
  fi

  if [ ! -f "$FIREWALLD_CONF" ]; then
    if ! sudo mkdir -p "$(dirname "$FIREWALLD_CONF")"; then
      echo "Error: Failed to create /etc/firewalld."
      return 1
    fi

    if [ -n "$vendor_conf" ]; then
      if ! sudo cp "$vendor_conf" "$FIREWALLD_CONF"; then
        echo "Error: Failed to copy default firewalld config from $vendor_conf."
        return 1
      fi
    else
      if ! echo "FirewallBackend=nftables" | sudo tee "$FIREWALLD_CONF" >/dev/null; then
        echo "Error: Failed to create $FIREWALLD_CONF."
        return 1
      fi
    fi
  elif [ -n "$vendor_conf" ] && ! sudo grep -q "^DefaultZone=" "$FIREWALLD_CONF"; then
    if ! sudo cp "$FIREWALLD_CONF" "$backup_name"; then
      echo "Error: Failed to back up incomplete $FIREWALLD_CONF."
      return 1
    fi

    if ! sudo cp "$vendor_conf" "$FIREWALLD_CONF"; then
      echo "Error: Failed to restore default firewalld config from $vendor_conf."
      return 1
    fi

    echo "Replaced incomplete $FIREWALLD_CONF. Backup saved as: $backup_name"
  fi

  if sudo grep -q "^FirewallBackend=iptables$" "$FIREWALLD_CONF"; then
    echo "Firewalld already uses the iptables backend."
    return 0
  fi

  if [ ! -f "$backup_name" ]; then
    if ! sudo cp "$FIREWALLD_CONF" "$backup_name"; then
      echo "Error: Failed to back up $FIREWALLD_CONF."
      return 1
    fi
  fi

  if sudo grep -q "^#\\?FirewallBackend=" "$FIREWALLD_CONF"; then
    sudo sed -i "s/^#\\?FirewallBackend=.*/FirewallBackend=iptables/" "$FIREWALLD_CONF"
  else
    echo "FirewallBackend=iptables" | sudo tee -a "$FIREWALLD_CONF" >/dev/null
  fi

  if [ $? -ne 0 ]; then
    echo "Error: Failed to set FirewallBackend=iptables."
    return 1
  fi

  echo "Updated $FIREWALLD_CONF. Backup saved as: $backup_name"
}

start_firewalld() {
  local backend_fallback_applied=false

  echo "Enabling and starting firewalld..."

  if ! sudo systemctl enable firewalld >/dev/null 2>&1; then
    echo "Error: Failed to enable firewalld."
    return 1
  fi

  if is_armbian_system; then
    echo "Armbian detected. Using firewalld iptables backend for compatibility."
    if ! set_firewalld_iptables_backend; then
      echo "Error: Failed to configure firewalld backend fallback."
      return 1
    fi
    backend_fallback_applied=true
  fi

  if ! sudo systemctl start firewalld >/dev/null 2>&1; then
    if $backend_fallback_applied; then
      echo "Error: Failed to start firewalld with the iptables backend."
      echo "Please check details with: sudo systemctl status firewalld"
      return 1
    fi

    echo "Warning: Failed to start firewalld with the default backend."

    if ! set_firewalld_iptables_backend; then
      echo "Error: Failed to configure firewalld backend fallback."
      return 1
    fi

    sudo systemctl reset-failed firewalld >/dev/null 2>&1 || true

    if ! sudo systemctl start firewalld >/dev/null 2>&1; then
      echo "Error: Failed to start firewalld with both nftables and iptables backends."
      echo "Please check details with: sudo systemctl status firewalld"
      return 1
    fi
  fi

  if ! sudo firewall-cmd --state >/dev/null 2>&1; then
    echo "Error: Firewalld is not running."
    return 1
  fi
}

add_firewalld_tcp_port() {
  local port="$1"

  if is_firewalld_running; then
    if sudo firewall-cmd --permanent --query-port="$port"/tcp >/dev/null 2>&1; then
      echo "Port $port [TCP] is already open. Skipping."
      return 0
    fi

    echo "Opening port $port [TCP]..."
    sudo firewall-cmd --permanent --zone=public --add-port="$port"/tcp
    return $?
  fi

  if ! command_exists firewall-offline-cmd; then
    echo "Error: firewalld is not running and firewall-offline-cmd is not available."
    return 1
  fi

  if sudo firewall-offline-cmd --zone=public --query-port="$port"/tcp >/dev/null 2>&1; then
    echo "Port $port [TCP] is already open. Skipping."
    return 0
  fi

  echo "Firewalld is not running. Opening port $port [TCP] in the offline configuration..."
  sudo firewall-offline-cmd --zone=public --add-port="$port"/tcp
}

configure_firewalld_ports() {
  local firewalld_was_running=false
  local port

  if ! ensure_firewalld_installed; then
    echo "Firewalld is not installed. Skipping."
    return 0
  fi

  if is_firewalld_running; then
    firewalld_was_running=true
  fi

  for port in "$@"; do
    if ! add_firewalld_tcp_port "$port"; then
      echo "Warning: Failed to open port $port [TCP]."
    fi
  done

  if $firewalld_was_running; then
    echo "Reload configuration..."
    sudo firewall-cmd --reload
  else
    echo "Firewalld is not running. Rules were saved and will apply when it starts."
  fi
}

configure_firewall() {
  clear

  if ! ensure_firewalld_installed; then
    echo "Firewalld is not installed. Please install it before configuring firewall rules."
    return
  fi

  echo "#######################################################"
  echo "Firewall configuration"
  echo "## WARNING ##"
  echo "## THIS CAN CUT YOU OUT OF THE SERVER ##"
  echo "## CHECK TWICE BEFORE PROCEEDING ##"
  echo "## YOU HAVE BEEN WARNED ##"
  echo "#######################################################"

  read -rp "Please provide your current SSH port (default is 22): " sshPort
  sshPort=${sshPort:-22}

  validate_port "$sshPort"
  if [ $? -ne 0 ]; then
    echo "Invalid port input. Exiting."
    exit 1
  fi

  firewalld_was_running=false
  if is_firewalld_running; then
    firewalld_was_running=true
  fi

  add_firewalld_tcp_port "$sshPort"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to open firewall port."
    exit 1
  fi

  if $firewalld_was_running; then
    echo "Reload configuration..."
    sudo firewall-cmd --reload
    if [ $? -ne 0 ]; then
      echo "Error: Failed to reload firewall configuration."
      exit 1
    fi
  else
    start_firewalld
    if [ $? -ne 0 ]; then
      exit 1
    fi
  fi

  echo
}

# ==============================================================================
# SSH
# ==============================================================================

setup_ssh_key_authentication() {
  clear

  # Check if SSH service is installed
  if ! package_installed openssh-server; then
    echo "SSH service (openssh-server) is not installed."

    # Ask the user if they want to install SSH service
    read -rp "Do you want to install SSH service? (Y/n): " install_ssh_service

    if [[ "$install_ssh_service" =~ ^[Yy]$ || "$install_ssh_service" == "" ]]; then
      if ! apt_install openssh-server; then
        echo "Error: Failed to install openssh-server."
        return
      fi
    else
      echo "SSH service will not be installed. Returning to the main menu."
      return
    fi
  fi

  clear
  
  # Backup with max 5 kept
  local max_backups=5
  local backup_name="${SSH_CONFIG}_decoscript.backup.$(date +%Y%m%d%H%M%S)"
  
  # Create a backup of the sshd_config file
  sudo cp "$SSH_CONFIG" "$backup_name"
  echo "Backup created: $backup_name"
  
  # Clean old backups, keep only the most recent $max_backups
  local backup_count=$(ls -1t $SSH_BACKUP_PATTERN 2>/dev/null | wc -l)
  if [ "$backup_count" -gt "$max_backups" ]; then
    echo "Cleaning old backups (keeping $max_backups most recent)..."
    ls -1t $SSH_BACKUP_PATTERN 2>/dev/null | tail -n +$((max_backups + 1)) | xargs -r sudo rm -f
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
  sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
  sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
  sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' "$SSH_CONFIG"
  sudo sed -i 's/^#PubkeyAuthentication no/PubkeyAuthentication yes/' "$SSH_CONFIG"
  sudo sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' "$SSH_CONFIG"

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

restore_ssh_config() {
  clear

  local backup
  backup=$(latest_ssh_config_backup)

  if [ -z "$backup" ]; then
    echo "Error: No backup files found matching $SSH_BACKUP_PATTERN"
    return
  fi

  echo "Found backup: $backup"
  read -rp "Do you want to restore SSH configuration from this backup? (y/N): " confirm_restore

  if [[ ! "$confirm_restore" =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    return
  fi

  echo "Restoring SSH configuration..."
  sudo cp "$backup" "$SSH_CONFIG"
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

# ==============================================================================
# Passwordless Sudo
# ==============================================================================

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

# ==============================================================================
# Web Server
# ==============================================================================

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
  configure_firewalld_ports 80 443
  echo

  # Create a directory for SSL certs if it doesn't exist
  if [ ! -d "$NGINX_CERT_DIR" ]; then
    echo "Creating directory $NGINX_CERT_DIR"
    sudo mkdir -p "$NGINX_CERT_DIR"
    sudo chmod 700 "$NGINX_CERT_DIR"
  fi

  echo
  echo "Finished setting up NGINX and PHP."
  echo "You can upload SSL certificates into $NGINX_CERT_DIR"
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
  echo "  1. Place your website files in $WEB_ROOT/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in $NGINX_CERT_DIR/"
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
  echo "  1. Place your website files in $WEB_ROOT/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in $NGINX_CERT_DIR/"
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
  echo "  1. Place your static files in $WEB_ROOT/"
  echo "  2. Configure NGINX sites in /etc/nginx/sites-available/"
  echo "  3. SSL certificates go in $NGINX_CERT_DIR/"
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
  if [ -f "$NGINX_DEFAULT_SITE" ]; then
    sudo cp "$NGINX_DEFAULT_SITE" "${NGINX_DEFAULT_SITE}.backup"
  fi
  
  # Detect PHP-FPM socket
  local php_socket=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)
  
  if [ -z "$php_socket" ]; then
    echo "Warning: Could not detect PHP-FPM socket. Using default."
    php_socket="/run/php/php-fpm.sock"
  fi
  
  # Create a working default config
  sudo tee "$NGINX_DEFAULT_SITE" >/dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $WEB_ROOT;
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
  echo "<?php phpinfo(); ?>" | sudo tee "$WEB_ROOT/info.php" >/dev/null
  echo
  echo "Test PHP installation: http://your-server-ip/info.php"
  echo "Remember to delete $WEB_ROOT/info.php after testing!"
}

# Helper: Configure NGINX for static files only
configure_nginx_static() {
  echo
  echo "Configuring NGINX for static content..."
  
  # Backup default config
  if [ -f "$NGINX_DEFAULT_SITE" ]; then
    sudo cp "$NGINX_DEFAULT_SITE" "${NGINX_DEFAULT_SITE}.backup"
  fi
  
  # Create a clean static config
  sudo tee "$NGINX_DEFAULT_SITE" >/dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $WEB_ROOT;
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
  if [ ! -d "$NGINX_CERT_DIR" ]; then
    sudo mkdir -p "$NGINX_CERT_DIR"
    sudo chmod 700 "$NGINX_CERT_DIR"
    echo "Created $NGINX_CERT_DIR for SSL certificates."
  fi
  
  # Ensure web root exists with correct permissions
  if [ ! -d "$WEB_ROOT" ]; then
    sudo mkdir -p "$WEB_ROOT"
  fi
  sudo chown -R www-data:www-data "$WEB_ROOT"
  
  # Create a simple index.html if none exists
  if [ ! -f "$WEB_ROOT/index.html" ] && [ ! -f "$WEB_ROOT/index.php" ]; then
    sudo tee "$WEB_ROOT/index.html" >/dev/null <<EOF
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
    sudo chown www-data:www-data "$WEB_ROOT/index.html"
  fi
  
  # Configure firewall if available
  echo
  echo "Configuring firewall..."
  configure_firewalld_ports 80 443
  
  echo "Setup complete!"
}

# ==============================================================================
# NVM
# ==============================================================================

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

# ==============================================================================
# Git
# ==============================================================================

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

# ==============================================================================
# Fail2ban
# ==============================================================================

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

# ==============================================================================
# Static IP / Netplan
# ==============================================================================

cidr_to_netmask() {
  local bits=$1
  local mask=$((0xffffffff ^ ((1 << (32 - bits)) - 1)))
  printf "%d.%d.%d.%d\n" \
    $(((mask >> 24) & 0xff)) \
    $(((mask >> 16) & 0xff)) \
    $(((mask >> 8) & 0xff)) \
    $((mask & 0xff))
}

configure_static_ip() {
  clear
  echo "Configuring a static IP address using Netplan."

  # Check if Netplan is installed, and if not, install it
  if ! command_exists netplan; then
    echo "Netplan is not installed. Installing..."
    apt_install netplan.io
  fi

  # Check if ifconfig is installed, and if not, install it
  if ! command_exists ifconfig; then
    echo "Ifconfig (net-tools) is not installed. Installing..."
    apt_install net-tools
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
  if [ -f "$NETPLAN_CONFIG" ]; then
    sudo cp "$NETPLAN_CONFIG" "$backup_dir/01-network-manager-all.yaml.$backup_timestamp"
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
  cat <<EOL | sudo tee "$NETPLAN_CONFIG" >/dev/null
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
  sudo chmod 600 "$NETPLAN_CONFIG"
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
  if [ ! -f "$NETPLAN_CONFIG" ]; then
    echo "No static IP configuration found at $NETPLAN_CONFIG"
    echo "Nothing to revert."
    return
  fi
  
  echo "This will remove the static IP configuration and revert to DHCP."
  echo "Current configuration file: $NETPLAN_CONFIG"
  echo
  read -rp "Do you want to proceed? (y/N): " confirm_revert
  
  if [[ ! "$confirm_revert" =~ ^[Yy]$ ]]; then
    echo "Revert cancelled."
    return
  fi
  
  # Get network device information
  if command_exists ifconfig; then
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
  sudo cp "$NETPLAN_CONFIG" "$backup_dir/01-network-manager-all.yaml.$backup_timestamp"
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
  cat <<EOL | sudo tee "$NETPLAN_CONFIG" >/dev/null
network:
  version: 2
  renderer: $renderer
  ethernets:
    $network_device:
      dhcp4: true
      dhcp6: false
EOL

  # Set correct permissions
  sudo chmod 600 "$NETPLAN_CONFIG"
  
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

# ==============================================================================
# Main
# ==============================================================================

check_sudo_privileges

while true; do
  show_menu
  read -rp "Press Enter to continue..."
done
