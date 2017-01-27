# :whale: caddy-script [![Code Climate](https://codeclimate.com/github/vintagesucks/caddy-script/badges/gpa.svg)](https://codeclimate.com/github/vintagesucks/caddy-script) [![Issue Count](https://img.shields.io/codeclimate/issues/github/vintagesucks/caddy-script.svg)](https://codeclimate.com/github/vintagesucks/caddy-script) [![Travis CI](https://api.travis-ci.org/vintagesucks/caddy-script.svg?branch=master)](https://travis-ci.org/vintagesucks/caddy-script)  

Caddy installation script for DigitalOcean (fully automated)

#### Features
- [x] Install Caddy
- [x] Install PHP7
- [x] Install MariaDB
- [x] Register Caddy as a service with systemd
- [x] Configure Caddyfile with gzip, fast-cgi, logs & redirects
- [x] Install WordPress [optional]
- [x] Install Shopware [optional]

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
- [Random Password Generator](https://stackoverflow.com/questions/26665389/random-password-generator-bash/26665585#26665585) by John1024/StackOverflow
- [Validating an IP Address in a Bash Script](https://www.linuxjournal.com/content/validating-ip-address-bash-script) by Mitch Frazier

---

\* Referral link to [https://digitalocean.com/](https://digitalocean.com/).
