## Script I use to install essential apps on new ubuntu systems


### Functions
- Install essentials:
  - [htop](https://htop.dev/)
  - [screen](https://www.gnu.org/software/screen/) 
  - [nload](https://github.com/rolandriegel/nload) 
  - [nano](https://www.nano-editor.org/) 
  - [firewalld](https://firewalld.org/)
    - After installation will open provided SSH port
  - [fail2ban](https://github.com/fail2ban/fail2ban)

- Option to install basic web server ([nginx](https://www.nginx.com/) & [php8.1](https://www.php.net/releases/8_1_0.php)-fpm)
  - opens 80 and 443 TCP/UDP ports in firewall 
  - removes [Apache2](https://httpd.apache.org/) if exist
- Option to install [Node Version Manager](https://github.com/nvm-sh/nvm)


### Usage
Download:
```bash
$ wget https://raw.githubusercontent.com/Decaded/install-script/main/install.sh
```
Add permissions to run:
```bash
$ sudo chmod +x install.sh
```
Run script:
```bash
$ ./install.sh
```
You can remove `install.sh` after installation is complete
```bash
$ rm install.sh
```

### Disclaimer
> I am by no means an expert in this field.
> You use this script at your own risk.
