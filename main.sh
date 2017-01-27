#!/bin/bash
#
#       Name: caddy-script
#     Author: Nikolas Evers
#   Homepage: https://github.com/vintagesucks/caddy-script
#

function checkLogfile()
{
  if [ ! -f /home/caddy/caddy-script.log ]; then
    sleep 0
  else
    clear
    echo " >> You already installed Caddy with caddy-script!"
    echo " >> Please view /home/caddy/caddy-script.log for your details."
    exit
  fi
}

function readEmail()
{
  read -e -p "Enter an email address (e.g. admin@example.org) " -r email
  if [[ ${#email} -gt 2 ]]; then
    sleep 0
  else
    echo " >> Please enter a valid email address!"
    readEmail
  fi
}

function readDomain()
{
  read -e -p "Enter a domain (e.g. example.org) " -r domain
  if [[ "${#domain}" -lt 1 ]]; then
    echo " >> Please enter a valid domain!"
    readDomain
  fi
}

function valid_ip()
{
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
      && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

function readCaddyExtensions()
{
  read -e -p "Enter the Caddy extensions you want (e.g. git,upload) " -r caddy_extensions
  if [[ "${#caddy_extensions}" = 0 ]]; then
    read -p "Are you sure you want to continue without additional Caddy features? (Y/N)" -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      sleep 0
    elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
      readCaddyExtensions;
    else
      echo " >> Please enter either Y or N."
      readCaddyExtensions
    fi
  fi
}

function readWordPress()
{
  read -p "Install WordPress? (Y/N)" -n 1 -r
  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    wordpress=1
  elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
    wordpress=0
  else
    echo " >> Please enter either Y or N."
    readWordPress
  fi
}

function readShopware()
{
  if [ "$wordpress" = 1 ]; then
    shopware=0
  else
    read -p "Install Shopware? (Y/N)" -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      shopware=1
    elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
      shopware=0
    else
      echo " >> Please enter either Y or N."
      readShopware
    fi
  fi
}

function readStartSetup()
{
  read -p "Continue with setup? (Y/N)" -n 1 -r
  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    sleep 0
  elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo " >> Setup cancelled."
    exit
  else
    echo " >> Please enter either Y or N."
    readStartSetup
  fi
}

function prepare()
{
  checkLogfile
  sudo dpkg-reconfigure tzdata
  readEmail
  readDomain
  readCaddyExtensions
  readWordPress
  readShopware
  echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "Caddy Features: ${caddy_extensions}"
  echo "        Domain: ${domain}"
  echo "         Email: ${email}"
  echo "     WordPress: ${wordpress}"
  echo "      Shopware: ${shopware}"
  echo ""
  readStartSetup
}

function check_root()
{
  echo "Checking if logged in user is root."
  _uid="$(id -u)"
  if [ "$_uid" != 0 ]; then
    echo " >>> You have to run caddy-script as root."
    exit
  else
    echo "User is root."
  fi
}

function create_user()
{
  echo "Checking if user caddy already exists."
  if [ "$(getent passwd caddy)" ] ; then
    echo " >>> User caddy already exists. Please start with a clean system."
    exit
  else
    echo "Adding user caddy."
    adduser caddy --disabled-password --gecos GECOS
    adduser caddy www-data
    echo "Adding user caddy to sudoers."
    echo 'caddy ALL=(ALL) ALL' >> /etc/sudoers
    echo "Successfully set up user caddy and needed permissions."
  fi
}

function install_caddy()
{
  echo "Installing Caddy."
  sudo -u caddy curl -fsSL https://getcaddy.com | bash -s "${caddy_extensions}"
  echo "Setting permissions for Caddy."
  sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy
  echo "Creating Caddyfile."
  create_caddyfile
  echo "Setting up directorys for ${domain}"
  runuser -l caddy -c "mkdir ${domain}"
  runuser -l caddy -c "mkdir ${domain}/log"
  runuser -l caddy -c "mkdir ${domain}/www"
  if [ "$wordpress" = 0 && "$shopware" = 0 ]; then
    runuser -l caddy -c "echo 'Hello World' > ${domain}/www/index.html"
  fi
}

function create_caddyfile()
{
  # Redirect www. if domain is not an ip address
  if valid_ip ${domain}; then
    sleep 0
  else
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
www.${domain} {
  redir https://${domain}{uri}
}

EOT
  fi

  # Open Caddyfile
  if valid_ip ${domain}; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
${domain}:80 {
EOT
  else
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
${domain} {
EOT
  fi

  # Add basic configuration
  sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
  root /home/caddy/${domain}/www
  log $domain/log/access.log {
    rotate {
      size 50
      age  30
      keep 10
    }
  }
  errors {
    log ${domain}/log/error.log {
      size 50
      age  30
      keep 10
    }
  }
  gzip
EOT

  # fastcgi
  if [ "$shopware" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
  fastcgi / 127.0.0.1:9000 php {
    index shopware.php
    env PATH /bin
  }
EOT
  else
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
  fastcgi / 127.0.0.1:9000 php {
    env PATH /bin
  }
EOT
  fi

  # Add rewrites for WordPress (if selected)
  if [ "$wordpress" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
  rewrite {
    if {path} not_match ^\/wp-admin
    to {path} {path}/ /index.php?_url={uri}
  }
EOT
  fi

  # Add rewrites for Shopware (if selected)
  if [ "$shopware" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
  rewrite {
    to {path} {path}/ /shopware.php?{query}
  }
EOT
  fi

  # Close basic Caddyfile
  sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
}
EOT
}

function install_php()
{
  echo "Adding PHP7 repository"
  sudo add-apt-repository ppa:ondrej/php -y
  echo "Check Packages for updates"
  sudo apt-get update
  echo "Installing PHP7 and extensions"
  sudo apt-get install php7.0-fpm php7.0-mysql php7.0-curl php7.0-intl php7.0-mcrypt php7.0-mbstring php7.0-soap php7.0-xml -y
  echo "Configuring PHP Settings for Caddy"
  OLDPHPCONF="listen \= \/run\/php\/php7\.0\-fpm\.sock"
  NEWPHPCONF="listen \= 127\.0\.0\.1\:9000"
  sudo sed -i "s/${OLDPHPCONF}/${NEWPHPCONF}/g" /etc/php/7.0/fpm/pool.d/www.conf
  echo "Restarting PHP"
  sudo service php7.0-fpm restart
}

function install_caddy_service()
{
  echo "Registering Caddy as a Service"
  sudo cat <<EOT >> /etc/systemd/system/caddy.service
[Unit]
Description=Caddy - The HTTP/2 web server with automatic HTTPS
Documentation=https://caddyserver.com/docs
After=network.target

[Service]
User=caddy
WorkingDirectory=/home/caddy
LimitNOFILE=8192
PIDFile=/var/run/caddy/caddy.pid
ExecStart=/usr/local/bin/caddy -agree -email ${email} -pidfile=/var/run/caddy/caddy.pid
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOT
  sudo systemctl enable caddy
  systemctl daemon-reload
  echo "Successfully registered Caddy as a Service."
}

function install_mariadb()
{
  choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
  MARIADB_ROOT_PASS="$({ choose '0123456789'
    choose 'abcdefghijklmnopqrstuvwxyz'
    choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    for i in $( seq 1 $(( 4 + RANDOM % 8 )) )
      do
        choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
      done
    } | sort -R | awk '{printf "%s",$1}')"
  sudo apt-get install mariadb-server -y
  apt install expect -y
	SECURE_MYSQL=$(expect -c "
  	set timeout 5
  	spawn mysql_secure_installation
  	expect \"Enter current password for root (enter for none):\"
  	send \"\r\"
  	expect \"Set root password? \[Y/n\]\"
  	send \"y\r\"
  	expect \"New password:\"
  	send \"${MARIADB_ROOT_PASS}\r\"
  	expect \"Re-enter new password:\"
  	send \"${MARIADB_ROOT_PASS}\r\"
  	expect \"Remove anonymous users? \[Y/n\]\"
  	send \"y\r\"
  	expect \"Disallow root login remotely? \[Y/n\]\"
  	send \"n\r\"
  	expect \"Remove test database and access to it? \[Y/n\]\"
  	send \"y\r\"
  	expect \"Reload privilege tables now? \[Y/n\]\"
  	send \"y\r\"
  	expect eof
  	")
  echo "${SECURE_MYSQL}"
  apt remove expect -y
  apt autoremove -y
}

function install_wordpress()
{
  if [[ "$wordpress" = 1 ]]; then
    echo "Installing WordPress"
    choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
    wpdbpass="$({ choose '0123456789'
      choose 'abcdefghijklmnopqrstuvwxyz'
      choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      for i in $( seq 1 $(( 4 + RANDOM % 8 )) )
        do
          choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        done
      } | sort -R | awk '{printf "%s",$1}')"
    mysql -uroot -e "create database wordpress;"
    mysql -uroot -e "grant usage on *.* to wordpress@localhost identified by '${wpdbpass}';"
    mysql -uroot -e "grant all privileges on wordpress.* to wordpress@localhost;"
    mysql -uroot -e "FLUSH PRIVILEGES;"

    choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
    wpadminpass="$({ choose '0123456789'
      choose 'abcdefghijklmnopqrstuvwxyz'
      choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      for i in $( seq 1 $(( 4 + RANDOM % 8 )) )
        do
          choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        done
      } | sort -R | awk '{printf "%s",$1}')"

    # Protocol
    if valid_ip ${domain}; then
      protocol="http://"
    else
      protocol="https://"
    fi

    # Download and install wp-cli
    curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /usr/local/bin/wp
    # Download latest WordPress version
    runuser -l caddy -c "wp core download --path=/home/caddy/${domain}/www"
    # create wp-config.php
    runuser -l caddy -c "wp core config --path=/home/caddy/${domain}/www --dbname=wordpress --dbuser=wordpress --dbpass=${wpdbpass} --dbhost=localhost"
    #install WordPress
    runuser -l caddy -c "wp core install --path=/home/caddy/${domain}/www --url=${protocol}${domain} --title=${domain} --admin_user=admin --admin_password=${wpadminpass} --admin_email=${email} --skip-email"
  fi
}

function install_shopware()
{
  if [[ "$shopware" = 1 ]]; then
    echo "Installing Shopware"
    choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
    swdbpass="$({ choose '0123456789'
      choose 'abcdefghijklmnopqrstuvwxyz'
      choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      for i in $( seq 1 $(( 4 + RANDOM % 8 )) )
        do
          choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        done
      } | sort -R | awk '{printf "%s",$1}')"

    mysql -uroot -e "create database shopware;"
    mysql -uroot -e "grant usage on *.* to shopware@localhost identified by '${swdbpass}';"
    mysql -uroot -e "grant all privileges on shopware.* to shopware@localhost;"
    mysql -uroot -e "FLUSH PRIVILEGES;"

    choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
    swadminpass="$({ choose '0123456789'
      choose 'abcdefghijklmnopqrstuvwxyz'
      choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      for i in $( seq 1 $(( 4 + RANDOM % 8 )) )
        do
          choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        done
      } | sort -R | awk '{printf "%s",$1}')"

    echo "Installing required packages"
    apt install openjdk-9-jre-headless ant unzip -y
    echo "Getting sw.phar"
    curl -o /usr/local/bin/sw http://shopwarelabs.github.io/sw-cli-tools/sw.phar
    chmod +x /usr/local/bin/sw

    echo "Installing Shopware via Shopware CLI Tools"
    sw install:release --release=5.2.15 --install-dir=/home/caddy/${domain}/www --db-user=shopware --db-password=${swdbpass} --admin-username=admin --admin-password=${swadminpass} --db-name=shopware --shop-path=CS_SW_PATH_PLACEHOLDER --shop-host=${domain}
    mysql -uroot -e "UPDATE shopware.s_core_shops SET base_path = NULL WHERE s_core_shops.id = 1;"
  fi
}

function finish()
{
  echo "Granting permissions for"
  if [ "$wordpress" = 1 ]; then
    sudo chown -R www-data:www-data /home/caddy/
    sudo chown -R caddy /home/caddy/
  elif [ "$shopware" = 1 ]; then
    sudo chown -R www-data:www-data /home/caddy/
    sudo chown -R caddy /home/caddy/
    sudo chown -R caddy /home/caddy/${domain}/www
    sudo chown -R www-data:www-data /home/caddy/${domain}/www/var/cache
  else
    sudo chown -R www-data:www-data /home/caddy/
    sudo chown -R caddy /home/caddy/
  fi
  echo "Creating setup logfile"
  if [ "$wordpress" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/caddy-script.log
Thanks for using caddy-script!
If you run into any issues related to this setup, please open an issue at
https://github.com/vintagesucks/caddy-script.

Domain:                       https://${domain}
MariaDB root password:        ${MARIADB_ROOT_PASS}
WordPress database name:      wordpress
WordPress database username:  wordpress
WordPress database password:  ${wpdbpass}
WordPress admin user:         admin
WordPress admin password:     ${wpadminpass}

Please keep this information somewhere safe (preferably not here!)
EOT
  elif [ "$shopware" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/caddy-script.log
Thanks for using caddy-script!
If you run into any issues related to this setup, please open an issue at
https://github.com/vintagesucks/caddy-script.

Domain:                       https://${domain}
MariaDB root password:        ${MARIADB_ROOT_PASS}
Shopware database name:       shopware
Shopware database username:   shopware
Shopware database password:   ${swdbpass}
Shopware admin user:          admin
Shopware admin password:      ${swadminpass}

Please keep this information somewhere safe (preferably not here!)
EOT
  else
    sudo -u caddy cat <<EOT >> /home/caddy/caddy-script.log
Thanks for using caddy-script!
If you run into any issues related to this setup, please open an issue at
https://github.com/vintagesucks/caddy-script.

Domain:                       https://${domain}
MariaDB root password:        ${MARIADB_ROOT_PASS}

Please keep this information somewhere safe (preferably not here!)
EOT
  fi
  service caddy start
  clear
  echo "Successfully installed Caddy!"
  echo "Please view /home/caddy/caddy-script.log for details."
}

set -e
prepare
check_root
create_user
install_caddy
install_php
install_caddy_service
install_mariadb
install_wordpress
install_shopware
finish
