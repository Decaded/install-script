#!/bin/sh
sudo -n true
test $? -eq 0 || exit 1 "You need sudo privilege to run this script"

APPS="htop screen nload nano firewalld"

echo "Updating package lists"
sudo apt update # get the latest package lists

echo "\n"
echo "Installation of essential apps will start in 5 seconds"
echo "Hit Ctrl+C now to abort"
sleep 6

sudo apt install $APPS -y       # do the magic
sudo systemctl enable firewalld # enable firewall on boot

echo "Essential programs installed successfully."
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
  sudo firewall-cmd --reload # I always forget to reload lol
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

echo -n "Install latest LTS version of NodeJS and NPM? (y/n) "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt-get install -y nodejs
  echo "\n"
  echo "NPM version:"
  npm --version
  echo "NodeJS version:"
  node --version
  echo "\n"

else
  echo "Skipped."
  echo "\n"
fi

echo "Done."
echo "You can now remove this script."
