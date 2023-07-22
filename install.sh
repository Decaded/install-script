#!/bin/sh

# Check if the script has sudo privileges, exit if not
sudo -n true
test $? -eq 0 || exit 1 "You need sudo privilege to run this script"

# List of essential apps to be installed
APPS="htop screen nload nano firewalld fail2ban"

echo "\n"
echo "#######################################################"
echo "Installation of essential apps will start in 5 seconds"
echo "Hit Ctrl+C now to abort"
echo "#######################################################"
sleep 6

# Update package lists
echo "Updating package lists"
sudo apt update # get the latest package lists

# Install essential apps
sudo apt install $APPS -y       # do the magic
sudo systemctl enable firewalld # enable firewall on boot

# Download customized fail2ban config
sudo wget -O /etc/fail2ban/jail.local https://gist.githubusercontent.com/Decaded/4a2b37853afb82ecd91da2971726234a/raw/be9aa897e0fa7ed267b75bd5110c837f7a39000c/jail.local
sudo service fail2ban restart

echo "\n"
echo "#######################################################"
echo "Firewall configuration"
echo "## WARNING ##"
echo "## THIS CAN CUT YOU OUT OF THE SERVER ##"
echo "## CHECK TWICE BEFORE PROCEEDING ##"
echo "## YOU HAVE BEEN WARNED ##"
echo "\n"
echo "Please provide your current SSH port (default is 22):"
read sshPort
echo "Opening port $sshPort TCP..."
sudo firewall-cmd --permanent --zone=public --add-port=$sshPort/tcp
echo "Reload configuration..."
sudo firewall-cmd --reload
echo "#######################################################"

echo "\n"
echo "#######################################################"
echo "Essential programs installed successfully."
echo "fail2ban config is located in /etc/fail2ban/jail.local"
echo "#######################################################"
echo "\n"

echo -n "Do you want to set up SSH key-based authentication? (y/n) "
read ssh_option

if [ "$ssh_option" != "${ssh_option#[Yy]}" ]; then
  echo "#######################################################"
  echo "SSH configuration"
  echo "Please provide your public key below."
  echo "#######################################################"

  # Read the user-provided public key and save it to a variable
  read -r user_public_key

  # Create the ~/.ssh directory if it doesn't exist
  mkdir -p "$HOME/.ssh"

  # Save the public key to the authorized_keys file
  echo "$user_public_key" >> "$HOME/.ssh/authorized_keys"

  # Enable key-based authentication and disable password-based authentication for SSH
  sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

  # Restart the SSH service for changes to take effect
  sudo service ssh restart

  echo "\n"
  echo "#######################################################"
  echo "SSH key-based authentication has been enabled, and password-based authentication has been disabled."
  echo "#######################################################"
  echo "\n"
else
  echo "SSH key-based authentication will not be set up."
  echo "#######################################################"
  echo "\n"
fi

# Function to check if passwordless sudo is already enabled for the user
is_passwordless_sudo_enabled() {
  # Check if the line with NOPASSWD:ALL exists in the sudoers file for the current user
  sudo grep -qE "^\s*$USER\s+ALL=\(ALL\) NOPASSWD:ALL\s*$" /etc/sudoers
}

# Function to enable passwordless sudo access for the user running the script
enable_passwordless_sudo() {
  # Add an entry to the sudoers file for passwordless sudo access for the current user
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
}

# Check if passwordless sudo is already enabled for the user
if is_passwordless_sudo_enabled; then
  echo "Passwordless sudo access is already enabled for your user."
else
  # Prompt the user if they want to enable passwordless sudo access
  echo -n "Do you want to enable passwordless sudo access for your user? (y/n): "
  read enable_sudo_option

  if [ "$enable_sudo_option" != "${enable_sudo_option#[Yy]}" ]; then
    enable_passwordless_sudo
    echo "\n"
    echo "#######################################################"
    echo "\n"
    echo "Passwordless sudo access has been enabled for your user."
    echo "Please log out and log back in for the changes to take effect."
    echo "#######################################################"
    echo "\n"
  else
    echo "Passwordless sudo access will not be enabled."
    echo "#######################################################"
    echo "\n"
  fi
fi

echo -n "Install NGINX and PHP? (y/n) "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
  sudo apt install nginx php8.1 php8.1-fpm -y

  # Remove apache2 if it exists
  # Reason: The script author prefers NGINX over Apache
  if [ "$(dpkg -l | awk '/apache2/ {print }' | wc -l)" -ge 1 ]; then
    echo "Apache2 is installed. Removing."
    sudo service apache2 stop
    sudo apt remove apache2 -y
    sudo apt purge apache2 -y
    sudo apt autoremove -y
    sudo service nginx start # start nginx after removing apache
  fi

  echo "\n"
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
  echo "\n"

  # Create a directory for SSL certs if it doesn't exist
  if [ -d "/etc/nginx/cert" ]; then
    echo "Directory /etc/nginx/cert exists, skipping."
  else
    echo "Creating directory /etc/nginx/cert"
    sudo mkdir /etc/nginx/cert # make folder for SSL certs so it's easier for me to just dump them there later
  fi

  echo "\n"
  echo "Finished setting up the default web server."
  echo "You can upload SSL certificates into /etc/nginx/cert"
  echo "\n"

else
  echo "Skipped."
  echo "\n"
fi

echo -n "Install Node Version Manager? (y/n) "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
  # Install Node Version Manager (NVM)
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm ls-remote
  echo "\n"
  echo "Above you can see a list of all available NodeJS versions."
  echo "Choose NodeJS version to install (e.g., 16.19.0):"
  read versionToInstall
  nvm install $versionToInstall
  echo "\n"

else
  echo "Skipped."
  echo "\n"
fi

echo "Done."
echo "You can now remove this script."
