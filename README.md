# :whale: caddy-script
Caddy installation script for DigitalOcean

#### Usage

`bash <(curl -s https://raw.githubusercontent.com/vintagesucks/caddy-script/master/main.sh)`

#### Requirements

- Clean Ubuntu 16.04. Droplet on [DigitalOcean](https://m.do.co/c/5585c0623c5d)*
- Domain pointed to Droplet

#### Features
- [x] Set server timezone, email address, domain, caddy extensions
- [x] Install Caddy (fully automated)
- [x] Install PHP7 (fully automated)
- [x] Install MariaDB (fully automated)
- [x] Register Caddy as a service with systemd (fully automated)
- [x] Install WordPress (fully automated) [optional]

#### Todo
- [ ] Replace 'Hello World' page with something nice

#### Credits

- [getcaddy.com](https://getcaddy.com/)
- [caddy.service](https://denbeke.be/blog/servers/running-caddy-server-as-a-service-with-systemd/) file by Mathias Beke
- [Random Password Generator](http://stackoverflow.com/a/26665585) by John1024/StackOverflow

---

\* Referral link to [https://digitalocean.com/](https://digitalocean.com/).
