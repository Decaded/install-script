#!/bin/bash

# Function to check if the script has sudo privileges
check_sudo_privileges() {
  if sudo -n true; then
    echo "Sudo privilege verified."
  else
    echo "You need sudo privilege to run this script. Exiting..."
    exit 1
  fi
}

# Function to update package lists and install essential apps
install_essential_apps() {
  echo "#######################################################"
  echo "Installation of essential apps will start in 5 seconds"
  echo "Hit Ctrl+C now to abort"
  echo "#######################################################"
  sleep 5

  echo "Updating package lists"
  sudo apt update

  local APPS="htop screen nload nano firewalld fail2ban"
  sudo apt install $APPS -y
  sudo systemctl enable firewalld

  echo "Downloading customized fail2ban config"
  sudo wget -O /etc/fail2ban/jail.local https://gist.githubusercontent.com/Decaded/4a2b37853afb82ecd91da2971726234a/raw/be9aa897e0fa7ed267b75bd5110c837f7a39000c/jail.local
  sudo service fail2ban restart

  echo "Essential programs installed successfully."
  echo "fail2ban config is located in /etc/fail2ban/jail.local"
  echo "#######################################################"
  echo
}

# Function to configure the firewall
configure_firewall() {
  echo "#######################################################"
  echo "Firewall configuration"
  echo "## WARNING ##"
  echo "## THIS CAN CUT YOU OUT OF THE SERVER ##"
  echo "## CHECK TWICE BEFORE PROCEEDING ##"
  echo "## YOU HAVE BEEN WARNED ##"
  echo "#######################################################"

  echo "Please provide your current SSH port (default is 22):"
  read -r sshPort

  echo "Opening port $sshPort TCP..."
  sudo firewall-cmd --permanent --zone=public --add-port="$sshPort"/tcp
  echo "Reload configuration..."
  sudo firewall-cmd --reload
  echo "#######################################################"
  echo
}

# Function to set up SSH key-based authentication
setup_ssh_key_authentication() {
  echo -n "Do you want to set up SSH key-based authentication? (y/n) "
  read -r ssh_option

  if [[ "$ssh_option" =~ ^[Yy]$ ]]; then
    echo "#######################################################"
    echo "SSH configuration"
    echo "Please provide your public key below."
    echo "#######################################################"

    # Read the user-provided public key and save it to a variable
    read -r user_public_key

    # Create the ~/.ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"

    # Save the public key to the authorized_keys file
    echo "$user_public_key" >>"$HOME/.ssh/authorized_keys"

    # Enable key-based authentication and disable password-based authentication for SSH
    sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    # Restart the SSH service for changes to take effect
    sudo service ssh restart

    echo "#######################################################"
    echo "SSH key-based authentication has been enabled, and password-based authentication has been disabled."
    echo "#######################################################"
    echo
  else
    echo "SSH key-based authentication will not be set up."
    echo "#######################################################"
    echo
  fi
}

# Function to enable passwordless sudo access
enable_passwordless_sudo() {
  if grep -qE "^\s*$USER\s+ALL=\(ALL\) NOPASSWD:ALL\s*$" /etc/sudoers; then
    echo "Passwordless sudo access is already enabled for your user."
  else
    echo -n "Do you want to enable passwordless sudo access for your user? (y/n): "
    read -r enable_sudo_option

    if [[ "$enable_sudo_option" =~ ^[Yy]$ ]]; then
      echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
      echo "Passwordless sudo access has been enabled for your user."
      echo "Please log out and log back in for the changes to take effect."
    else
      echo "Passwordless sudo access will not be enabled."
    fi
  fi
  echo "#######################################################"
  echo
}

# Function to install NGINX and PHP
install_nginx_and_php() {
  echo -n "Install NGINX and PHP? (y/n) "
  read -r answer

  if [[ "$answer" =~ ^[Yy]$ ]]; then
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
  else
    echo "Skipped."
    echo
  fi
}

# Function to install Node Version Manager (NVM)
install_nvm() {
  echo -n "Install Node Version Manager? (y/n) "
  read -r answer

  if [[ "$answer" =~ ^[Yy]$ ]]; then
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm ls-remote
    echo "Above you can see a list of all available NodeJS versions."
    echo "Choose NodeJS version to install (e.g., 16.19.0):"
    read -r versionToInstall
    nvm install "$versionToInstall"
    echo

  else
    echo "Skipped."
    echo
  fi
}

# Main script
check_sudo_privileges
install_essential_apps
configure_firewall
setup_ssh_key_authentication
enable_passwordless_sudo
install_nginx_and_php
install_nvm

echo "Done."
echo "You can now remove this script."
