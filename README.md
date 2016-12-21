# :whale: caddy-script
Caddy installation script for DigitalOcean (fully automated)

#### Features
- [x] Install Caddy
- [x] Install PHP7
- [x] Install MariaDB
- [x] Register Caddy as a service with systemd
- [x] Configure Caddyfile with gzip, fast-cgi, logs & redirects
- [x] Install WordPress [optional]

#### Requirements

- Clean Ubuntu 16.04. Droplet on [DigitalOcean](https://m.do.co/c/5585c0623c5d)*

#### Usage

`bash <(curl -s https://raw.githubusercontent.com/vintagesucks/caddy-script/master/main.sh)`

You'll be asked for your timezone, an email, the domain/ip to use and additional features you want.

#### Help

You can read the [Caddy Documentation](https://caddyserver.com/docs) if you need more information about Caddy's features and extensions.

#### Credits

- [getcaddy.com](https://getcaddy.com/)
- [caddy.service](https://denbeke.be/blog/servers/running-caddy-server-as-a-service-with-systemd/) file by Mathias Beke
- [Random Password Generator](http://stackoverflow.com/a/26665585) by John1024/StackOverflow

---

\* Referral link to [https://digitalocean.com/](https://digitalocean.com/).
