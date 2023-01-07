#!/bin/sh
sudo -n true
test $? -eq 0 || exit 1 "You need sudo privilege to run this script"

APPS="htop screen nload nano firewalld fail2ban"

echo "\n"
echo "#######################################################"
echo "Installation of essential apps will start in 5 seconds"
echo "Hit Ctrl+C now to abort"
echo "#######################################################"
sleep 6

echo "Updating package lists"
sudo apt update # get the latest package lists

sudo apt install $APPS -y       # do the magic
sudo systemctl enable firewalld # enable firewall on boot
# download customized fail2ban config
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
echo "Please provide your current SSH port (defalut is 22):"
read sshPort
echo "Openning port $sshPort TCP..."
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

echo -n "Install NGINX and PHP? (y/n) "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
  sudo apt install nginx php7.4 php7.4-fpm -y

  # remove apache2 if exist
  # why?
  # because I hate it
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
  echo "Oppening ports for 80 and 443 [TCP and UDP]"
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

  if [ -d "/etc/nginx/cert" ]; then
    echo "Directory /etc/nginx/cert exists, skipping."
  else
    echo "Creating directory /etc/nginx/cert"
    sudo mkdir /etc/nginx/cert # make folder for SSL certs so it's easier for me to just dump them there later
  fi

  echo "\n"
  echo "Finished setting up default web server."
  echo "You can upload ssl certificates into /etc/nginx/cert"
  echo "\n"

else
  echo "Skipped."
  echo "\n"
fi

echo -n "Install Node Version Manager? (y/n) "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm ls-remote
  echo "\n"
  echo "Above you can see list of all availble NodeJS versions."
  echo "Choose NodeJS version to install (eg: 16.19.0):"
  read versionToInstall
  nvm install $versionToInstall
  echo "\n"

else
  echo "Skipped."
  echo "\n"
fi

echo "Done."
echo "You can now remove this script."
