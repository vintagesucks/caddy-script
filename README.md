## :whale: caddy-script  
Caddy installation script for DigitalOcean (fully automated)

[![license](https://img.shields.io/github/license/vintagesucks/caddy-script.svg)](https://github.com/vintagesucks/caddy-script/blob/master/LICENSE) [![GitHub contributors](https://img.shields.io/github/contributors/vintagesucks/caddy-script.svg)](https://github.com/vintagesucks/caddy-script/graphs/contributors) [![GitHub stars](https://img.shields.io/github/stars/vintagesucks/caddy-script.svg?style=flat&label=stars)](https://github.com/vintagesucks/caddy-script/stargazers)  
[![Code Climate](https://codeclimate.com/github/vintagesucks/caddy-script/badges/gpa.svg)](https://codeclimate.com/github/vintagesucks/caddy-script) [![Issue Count](https://img.shields.io/codeclimate/issues/github/vintagesucks/caddy-script.svg)](https://codeclimate.com/github/vintagesucks/caddy-script/issues) [![Travis CI](https://api.travis-ci.org/vintagesucks/caddy-script.svg?branch=master)](https://travis-ci.org/vintagesucks/caddy-script)  
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/a0b0746d7a9f4a9db9fe7ae0d1fd775b)](https://www.codacy.com/app/vintagesucks/caddy-script?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=vintagesucks/caddy-script&amp;utm_campaign=Badge_Grade)

#### Features
- [x] Install Caddy
- [x] Install PHP7
- [x] Install MariaDB
- [x] Register Caddy as a service with systemd
- [x] Configure Caddyfile with gzip, fast-cgi, logs & redirects
- [x] Install WordPress [optional]
- [x] Install Shopware [optional]
- [x] Install phpMyAdmin [optional]  

#### Requirements

- Clean Ubuntu 16.04. Droplet on [DigitalOcean](https://m.do.co/c/3c23791febd7)*

#### Usage

`bash <(curl -s https://raw.githubusercontent.com/vintagesucks/caddy-script/master/main.sh)`

You'll be asked for your timezone, an email, the domain/ip to use and additional features you want.

#### Help

You can read the [Caddy Documentation](https://caddyserver.com/docs) if you need more information about Caddy's features and extensions.

#### Acknowledgements

- [getcaddy.com](https://getcaddy.com/)
- [caddy.service](https://denbeke.be/blog/servers/running-caddy-server-as-a-service-with-systemd/) file by Mathias Beke  
- [Validating an IP Address in a Bash Script](https://www.linuxjournal.com/content/validating-ip-address-bash-script) by Mitch Frazier

---

\* Referral link to [https://digitalocean.com/](https://digitalocean.com/).
