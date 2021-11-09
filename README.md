# Script I use to install essential apps on new ubuntu systems


## Functions
- Install essentials:
  - [htop](https://htop.dev/)
  - [screen](https://www.gnu.org/software/screen/) 
  - [nload](https://github.com/rolandriegel/nload) 
  - [nano](https://www.nano-editor.org/) 
  - [firewalld](https://firewalld.org/)
- Option to install basic web server ([nginx](https://www.nginx.com/) & [php7.4](https://www.php.net/releases/7_4_0.php)-fpm)
  - opens 80 and 443 TCP/UDP ports in firewall 
  - removes [Apache2](https://httpd.apache.org/) if exist
- Option to install latest LTS version of [NodeJS](https://nodejs.org/en/) and [NPM](https://www.npmjs.com/)


## Disclaimer
> I am by no means an expert in this field.
> You use this script at your own risk.