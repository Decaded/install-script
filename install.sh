#!/bin/bash

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
  if [ -f "/etc/ssh/sshd_config_decoscript.backup" ]; then
    echo "6) Restore SSH Configuration"
  else
    echo "6) Restore SSH Configuration (Not available)"
  fi
  echo
  echo "0) Exit"
  echo
  read -rp "Enter your choice: " choice
  case $choice in
  1) install_essential_apps ;;
  2) install_nginx_and_php ;;
  3) install_nvm ;;
  4) enable_passwordless_sudo "$USER" ;;
  5) setup_ssh_key_authentication ;;
  6)
    if [ -f "/etc/ssh/sshd_config_decoscript.backup" ]; then
      restore_ssh_config
    else
      echo "SSH configuration backup is not available for restoration."
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

# Function to install essential apps
install_essential_apps() {
  clear
  echo "Choose which essential apps to install:"

  # Array of app options
  declare -A app_options=(
    ["1"]="htop - Interactive process viewer"
    ["2"]="screen - Terminal multiplexer"
    ["3"]="nload - Network traffic monitor"
    ["4"]="nano - Text editor"
    ["5"]="firewalld - Firewall management"
    ["6"]="fail2ban - Intrusion prevention system"
    ["7"]="unattended-upgrades - Automatic updates"
    ["8"]="git - Version control system"
  )

  # Display app options
  for app in "${!app_options[@]}"; do
    echo "$app) ${app_options[$app]}"
  done

  echo "0) Exit"

  # Read user choices
  read -rp "Enter the numbers of the apps to install (e.g., 1 3 5): " choices

  # Convert choices to an array
  choices_array=($choices)

  # Process user choices and install selected apps
  selected_apps=""
  for choice in "${choices_array[@]}"; do
    case $choice in
    0) return ;; # Exit
    [1-9])
      selected_apps+=" ${app_options[$choice]%% -*}" # Extract app name
      ;;
    *)
      echo "Invalid choice: $choice"
      ;;
    esac
  done

  if [ -n "$selected_apps" ]; then
    echo "Installing selected apps: $selected_apps"
    sudo apt update && sudo apt install $selected_apps -y

    # Check if firewalld was selected
    if [[ "$selected_apps" == *"firewalld"* ]]; then
      configure_firewall
    fi

    # Check if Fail2ban was selected
    if [[ "$selected_apps" == *"fail2ban"* ]]; then
      configure_fail2ban
    fi

    # Check if unattended-upgrades was selected
    if [[ "$selected_apps" == *"unattended-upgrades"* ]]; then
      sudo dpkg-reconfigure -plow unattended-upgrades
    fi

    # Check if Git was selected and is installed
    if [[ "$selected_apps" == *"git"* ]] && ! [ -x "$(command -v git)" ]; then
      echo "Git is not installed. Installing Git..."
      sudo apt install git -y
    fi

    # Configure Git only if it was selected
    if [[ "$selected_apps" == *"git"* ]]; then
      configure_git
    fi
    echo
  else
    echo "No apps selected."
  fi
}

# Function to configure the firewall
configure_firewall() {
  clear
  sudo systemctl enable firewalld

  echo "#######################################################"
  echo "Firewall configuration"
  echo "## WARNING ##"
  echo "## THIS CAN CUT YOU OUT OF THE SERVER ##"
  echo "## CHECK TWICE BEFORE PROCEEDING ##"
  echo "## YOU HAVE BEEN WARNED ##"
  echo "#######################################################"

  read -rp "Please provide your current SSH port (default is 22): " sshPort

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
# Function to set up SSH key-based authentication
setup_ssh_key_authentication() {
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
  IFS= read -r user_public_key

  # Create the ~/.ssh directory if it doesn't exist
  mkdir -p "$HOME/.ssh"

  authorized_keys_file="$HOME/.ssh/authorized_keys"

  # Check if the authorized_keys file exists and the key is not already present
  if [ -f "$authorized_keys_file" ] && ! grep -q "$user_public_key" "$authorized_keys_file"; then
    # Save the public key to the authorized_keys file
    echo "$user_public_key" >>"$authorized_keys_file"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to save the public key to authorized_keys file."
      exit 1
    fi
    echo
    echo "Public key added to authorized_keys."
  elif [ ! -f "$authorized_keys_file" ]; then
    echo "Creating authorized_keys file..."
    echo "$user_public_key" >"$authorized_keys_file"
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

# Function to install NGINX and PHP
install_nginx_and_php() {
  clear

  # Install NGINX and PHP
  sudo apt install nginx php8.1 php8.1-fpm -y

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
  echo "Opening ports for 80 and 443 [TCP and UDP]"
  echo "80 UDP..."
  sudo firewall-cmd --permanent --zone=public --add-port=80/udp
  echo "80 TCP..."
  sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
  echo "443 UDP..."
  sudo firewall-cmd --permanent --zone=public --add-port=443/udp
  echo "443 TCP..."
  sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
  echo "Reload configuration..."
  sudo firewall-cmd --reload
  echo

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

# Function to walidate ports
validate_port() {
  local port="$1"
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid port number. Please enter a valid numeric port."
    return 1
  fi

  if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    echo "Error: Port number should be between 1 and 65535."
    return 1
  fi
}

# Function to configure Git
configure_git() {
  clear
  echo "Git Configuration"

  read -rp "Enter your Git name: " git_name
  read -rp "Enter your Git email: " git_email

  # Set Git configurations
  git config --global user.name "$git_name"
  git config --global user.email "$git_email"

  echo "Git has been configured with name: $git_name and email: $git_email:"
  echo "You can always check your configuration by running 'git config --list':"
  git config --list
  echo
}

# Function to configure fail2ban
configure_fail2ban() {
  clear
  echo "Choose the Fail2ban configuration to use:"
  echo "1) Default configuration"
  echo "2) User custom configuration (provide link)"
  echo "3) Custom configuration modified by the script author (recommended)"

  # Read user input
  read -rp "Enter your choice (1/2/3): " fail2ban_config_choice

  case $fail2ban_config_choice in
  1) ;;
  2)
    read -rp "Enter the URL of the user custom configuration: " custom_config_url

    sudo wget -O /etc/fail2ban/jail.local "$custom_config_url"
    ;;
  3)
    echo "Downloading customized fail2ban config..."
    sudo wget -O /etc/fail2ban/jail.local https://gist.githubusercontent.com/Decaded/4a2b37853afb82ecd91da2971726234a/raw/be9aa897e0fa7ed267b75bd5110c837f7a39000c/jail.local
    ;;
  *)
    echo "Invalid choice. Using the custom configuration modified by the script author."
    sudo wget -O /etc/fail2ban/jail.local https://gist.githubusercontent.com/Decaded/4a2b37853afb82ecd91da2971726234a/raw/be9aa897e0fa7ed267b75bd5110c837f7a39000c/jail.local
    ;;
  esac

  echo "Selected essential apps installed successfully."
  echo "fail2ban config is located in /etc/fail2ban/jail.local"
}

# Main script
check_sudo_privileges

while true; do
  show_menu
  read -rp "Press Enter to continue..."
done
