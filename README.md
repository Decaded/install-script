## Script I use to configure new Ubuntu systems

[![Code Size](https://img.shields.io/github/languages/code-size/Decaded/install-script)](https://github.com/Decaded/install-script)
[![Open Issues](https://img.shields.io/github/issues/Decaded/install-script)](https://github.com/Decaded/install-script/issues)
[![Open PRs](https://img.shields.io/github/issues-pr/Decaded/install-script)](https://github.com/Decaded/install-script/pulls)
[![Last Commit](https://img.shields.io/github/last-commit/Decaded/install-script)](https://github.com/Decaded/install-script/commits)


### Functions

- Install essentials:
  - [htop](https://htop.dev/)
  - [screen](https://www.gnu.org/software/screen/)
  - [nload](https://github.com/rolandriegel/nload)
  - [nano](https://www.nano-editor.org/)
  - [firewalld](https://firewalld.org/)
    - After installation will open provided SSH port
  - [fail2ban](https://github.com/fail2ban/fail2ban)
    - After installation will ask for configuration file;
      - default one
      - custom one (downloadable via url)
      - [modified by me](https://gist.github.com/Decaded/4a2b37853afb82ecd91da2971726234a)
  - [git](https://git-scm.com/)
    - After installation prompts for first-time configuration
  - [unattended-upgrades](https://help.ubuntu.com/community/AutomaticSecurityUpdates)

- Option to disable password authentication and leave key-based only (as requested in [issue #1](https://github.com/Decaded/install-script/issues/1))
  - Asks for a public key that will be inserted into `$HOME/.ssh/authorized_keys`
    - if the key already exist in the file, new entry will not be made
  - `sshd_config` will be backed up to `/etc/ssh/sshd_config_decoscript.backup`
    - this will enable option `6` in the menu: `Restore SSH Configuration`
- Option to enable passwordless sudo access for the user running this script
  - Won't do anything if the user already has this enabled
- Option to install a basic web server ([nginx](https://www.nginx.com/) & [php8.1](https://www.php.net/releases/8_1_0.php)-fpm)
  - Opens ports 80 and 443 TCP/UDP in the firewall
  - Removes [Apache2](https://httpd.apache.org/) if it exists
- Option to install [Node Version Manager](https://github.com/nvm-sh/nvm)

___
### Usage

Download:
```bash
wget https://raw.githubusercontent.com/Decaded/install-script/main/install.sh
```
Add permissions to run:
```bash
sudo chmod +x install.sh
```
Run script:
```bash
./install.sh
```
And just pick what you need from the menu:

![Script in Action](images/main_menu.png)

___
### Contributing
Contributions are welcome! If you find any issues or have suggestions for improvements, feel free to submit a [issue](https://github.com/Decaded/install-script/issues).

___
### Disclaimer

> I am by no means an expert in this field. You use this script at your own risk.

___
