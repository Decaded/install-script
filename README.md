# Hello There, internet traveler

### Overview

This script is a modular server utility tool for Debian-based and Ubuntu-based systems. It helps automate common setup tasks without forcing a specific stack. You choose exactly
what gets installed: essential tools, Nginx, PHP, NVM, static IP profiles, and more.

Ubuntu is the primary target environment. Other Debian derivatives should work, but if you encounter issues, feel free to open an
[issue](https://github.com/Decaded/install-script/issues) and describe your setup.

<div align="center">
  <a href="https://github.com/Decaded/install-script">
    <img src="https://img.shields.io/github/languages/code-size/Decaded/install-script" alt="Code Size">
  </a>
  <a href="https://github.com/Decaded/install-script/issues">
    <img src="https://img.shields.io/github/issues/Decaded/install-script" alt="Open Issues">
  </a>
  <a href="https://github.com/Decaded/install-script/pulls">
    <img src="https://img.shields.io/github/issues-pr/Decaded/install-script" alt="Open PRs">
  </a>
  <a href="https://github.com/Decaded/install-script/commits">
    <img src="https://img.shields.io/github/last-commit/Decaded/install-script" alt="Last Commit">
  </a>
</div>

---

## Installation and Usage

1. Download the script:

   ```bash
   wget https://raw.githubusercontent.com/Decaded/install-script/main/install.sh
   ```

2. Make it executable:

   ```bash
   sudo chmod +x install.sh
   ```

3. Run it:

   ```bash
   ./install.sh
   ```

A menu will appear with all available options.

<div align="center">
  <img src="images/main_menu.png" alt="Script Menu Preview">
</div>

---

## Features

### Essential Tools

Install a curated pack of common system utilities:

1. **[htop](https://htop.dev/)** – process viewer
2. **[screen](https://www.gnu.org/software/screen/)** – terminal multiplexer
3. **[nload](https://github.com/rolandriegel/nload)** – network traffic monitor
4. **[nano](https://www.nano-editor.org/)** – simple text editor
5. **[firewalld](https://firewalld.org/)** – firewall management

   - Automatically opens SSH
   - Migrates from UFW if needed

6. **[fail2ban](https://github.com/fail2ban/fail2ban)** – intrusion prevention

   - Default configuration or custom rules

7. **[git](https://git-scm.com/)** – version control

   - Optional first-time setup

8. **[unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades)** – automatic security updates

### SSH Configuration

Switch to secure, key-only SSH authentication. The script:

- Disables password-based logins
- Creates a backup of your SSH config
- Provides a restore option

Backup file location:

```
/etc/ssh/sshd_config_decoscript.backup
```

Re-running the script replaces the old backup, so rename it if you want to keep multiple versions.

### Passwordless Sudo

Enables password-free sudo access if desired. If your system already uses this configuration, the script leaves it unchanged.

### Web Server Setup

- Automatic cleanup of Apache2 if present
- Firewall rules for HTTP(S) when using firewalld

Installs the full **LEMP** stack:

- **[Nginx](https://nginx.org/)** installation and configuration
- **[MySQL](https://www.mysql.com/)** installation and secure setup
- **[PHP](https://www.php.net/)** installation with commonly used modules

  - Configures **php-fpm** to work with Nginx
  - Installs modules:
    - **php-cli**
    - **php-fpm**
    - **php-mbstring**
    - **php-curl**
    - **php-xml**
    - **php-zip**
    - **php-gd**
    - **php-mysql**

- **OR** install Nginx and PHP only,
- **OR** install only Nginx.

### Node.js via NVM

Installs the latest **[NVM](https://github.com/nvm-sh/nvm)** version and lets you manage Node.js installations cleanly:

- Install or remove Node.js versions
- Switch between versions

### Static IP Configuration

Configure a static IP address using **Netplan** when available.

Supports:

- IP address
- Subnet
- Gateway
- DNS servers

If Netplan isn’t present, the script chooses the best available method.

---

## Contributing and Issues

If you notice unexpected behavior or have a suggestion, [open an issue](https://github.com/Decaded/install-script/issues).

Pull requests are welcome.

---

## License

This project is available under the [MIT License](LICENSE).

---

## Disclaimer

This script performs operations that modify system configuration. Use it responsibly, review options before applying them, and keep backups of important files.

> This script comes as is, without any guarantees. It's your adventure, so be mindful.
