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
    exit 0
  fi
}

function readEmail()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    email="travis@example.org"
  else
    read -e -p "Enter an email address (e.g. admin@example.org) " -r email
    if [[ ${#email} -gt 2 ]]; then
      sleep 0
    else
      echo " >> Please enter a valid email address!"
      readEmail
    fi
  fi
}

function readDomain()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    domain="127.0.0.1"
  else
    read -e -p "Enter a domain (e.g. example.org) " -r domain
    if [[ "${#domain}" -lt 1 ]]; then
      echo " >> Please enter a valid domain!"
      readDomain
    fi
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
  if [[ $TRAVIS_CI == 1 ]]; then
    caddy_extensions="git"
  else
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
  fi
}

function readWordPress()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    wordpress=0
  else
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
  fi
}

function readShopware()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    shopware=0
  else
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
  fi
}

function readPhpMyAdmin()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    phpmyadmin=0
  else
    read -p "Install phpMyAdmin? (Y/N)" -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      phpmyadmin=1
    elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
      phpmyadmin=0
    else
      echo " >> Please enter either Y or N."
      readPhpMyAdmin
    fi
  fi
}

function readStartSetup()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    sleep 0
  else
    read -p "Continue with setup? (Y/N)" -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      sleep 0
    elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
      echo " >> Setup cancelled."
      exit 1
    else
      echo " >> Please enter either Y or N."
      readStartSetup
    fi
  fi
}

function prepare()
{
  checkLogfile
  if [[ $TRAVIS_CI == 1 ]]; then
    sleep 0
  else
    sudo dpkg-reconfigure tzdata
  fi
  readEmail
  readDomain
  readCaddyExtensions
  readWordPress
  readShopware
  readPhpMyAdmin
  echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "Caddy Features: ${caddy_extensions}"
  echo "        Domain: ${domain}"
  echo "         Email: ${email}"
  echo "     WordPress: ${wordpress}"
  echo "      Shopware: ${shopware}"
  echo "    phpMyAdmin: ${phpmyadmin}"
  echo ""
  readStartSetup
}

function check_root()
{
  if [[ $TRAVIS_CI == 1 ]]; then
    sleep 0
  else
    echo "Checking if logged in user is root."
    _uid="$(id -u)"
    if [ "$_uid" != 0 ]; then
      echo " >>> You have to run caddy-script as root."
      exit 1
    else
      echo "User is root."
    fi
  fi
}

function create_user()
{
  echo "Checking if user caddy already exists."
  if [ "$(getent passwd caddy)" ] ; then
    echo " >>> User caddy already exists. Please start with a clean system."
    exit 1
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
  if [ "$wordpress" = 0 ] && [ "$shopware" = 0 ]; then
    runuser -l caddy -c "echo 'Hello World' > ${domain}/www/index.html"
  fi
}

function create_caddyfile()
{
  # Redirect www. if domain is not an ip address
  if valid_ip "${domain}"; then
    sleep 0
  else
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
www.${domain} {
  redir https://${domain}{uri}
}

EOT
  fi

  # Open Caddyfile
  if valid_ip "${domain}"; then
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
    index shopware.php index.php
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
  if [[ $TRAVIS_CI == 1 ]]; then
    LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
  else
    sudo add-apt-repository ppa:ondrej/php -y
  fi
  echo "Check Packages for updates"
  sudo apt-get update
  echo "Installing PHP7 and extensions"
  sudo apt-get install php7.0-fpm php7.0-mysql php7.0-curl php7.0-intl php7.0-mcrypt php7.0-mbstring php7.0-soap php7.0-xml php7.0-zip -y
  echo "Configuring PHP Settings for Caddy"
  OLDPHPCONF="listen \= \/run\/php\/php7\.0\-fpm\.sock"
  NEWPHPCONF="listen \= 127\.0\.0\.1\:9000"
  sudo sed -i "s/${OLDPHPCONF}/${NEWPHPCONF}/g" /etc/php/7.0/fpm/pool.d/www.conf
  echo "Restarting PHP"
  sudo service php7.0-fpm restart
}

function install_phpmyadmin()
{
  if [[ ${phpmyadmin} == 1 ]]; then
    mkdir /home/caddy/"${domain}"/www/phpmyadmin
    echo "Installing phpMyAdmin via Git";
    cd /home/caddy/"${domain}"/www/phpmyadmin/
    git clone https://github.com/phpmyadmin/phpmyadmin.git .
    git checkout STABLE
    echo "Installing Composer"
    apt install composer -y
    composer update --no-dev
  fi
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
  if [[ $TRAVIS_CI == 1 ]]; then
    sleep 0
  else
    sudo systemctl enable caddy
    systemctl daemon-reload
  fi
  echo "Successfully registered Caddy as a Service."
}

function install_mariadb()
{
  MARIADB_ROOT_PASS=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')
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
    wpdbpass=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')
    mysql -uroot -e "create database wordpress;"
    mysql -uroot -e "grant usage on *.* to wordpress@localhost identified by '${wpdbpass}';"
    mysql -uroot -e "grant all privileges on wordpress.* to wordpress@localhost;"
    mysql -uroot -e "FLUSH PRIVILEGES;"

    wpadminpass=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')

    # Protocol
    if valid_ip "${domain}"; then
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
    swdbpass=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')

    mysql -uroot -e "create database shopware;"
    mysql -uroot -e "grant usage on *.* to shopware@localhost identified by '${swdbpass}';"
    mysql -uroot -e "grant all privileges on shopware.* to shopware@localhost;"
    mysql -uroot -e "FLUSH PRIVILEGES;"

    swadminpass=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')

    echo "Installing required packages"
    apt install openjdk-9-jre-headless ant unzip -y
    echo "Getting sw.phar"
    curl -o /usr/local/bin/sw http://shopwarelabs.github.io/sw-cli-tools/sw.phar
    chmod +x /usr/local/bin/sw

    echo "Installing Shopware specific PHP extensions"
    apt-get install php7.0-gd -y
    wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
    tar xvfz ioncube_loaders_lin_x86-64.tar.gz
    sudo cp ioncube/ioncube_loader_lin_7.0.so /usr/lib/php/20151012/
    sudo rm ioncube_loaders_lin_x86-64.tar.gz
    sudo rm -rf ioncube_loaders_lin_x86-64

    echo "Making Shopware specific php.ini changes"
    sudo cat <<EOT >> /etc/php/7.0/fpm/php.ini
zend_extension = "/usr/lib/php/20151012/ioncube_loader_lin_7.0.so"
EOT
    OLDMEMORYLIMIT="memory_limit \= 128M"
    NEWMEMORYLIMIT="memory_limit \= 256M"
    sudo sed -i "s/${OLDMEMORYLIMIT}/${NEWMEMORYLIMIT}/g" /etc/php/7.0/fpm/php.ini
    OLDMAXFILESIZE="upload_max_filesize \= 2M"
    NEWMAXFILESIZE="upload_max_filesize \= 6M"
    sudo sed -i "s/${OLDMEMORYLIMIT}/${NEWMEMORYLIMIT}/g" /etc/php/7.0/fpm/php.ini

    echo "Installing Shopware specific packages"
    apt-get install libfreetype6 -y

    echo "Restarting PHP"
    sudo service php7.0-fpm restart

    echo "Installing Shopware via Shopware CLI Tools"
    sw install:release --release=5.2.15 --install-dir=/home/caddy/"${domain}"/www --db-user=shopware --db-password="${swdbpass}" --admin-username=admin --admin-password="${swadminpass}" --db-name=shopware --shop-path=CS_SW_PATH_PLACEHOLDER --shop-host="${domain}"
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
    sudo chown -R caddy /home/caddy/"${domain}"/www
    sudo chown -R www-data:www-data /home/caddy/"${domain}"/www/var/cache
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

Domain:                       ${protocol}${domain}
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
  if [[ $TRAVIS_CI == 1 ]]; then
    sleep 0
  else
    service caddy start
    clear
  fi
  echo "Successfully installed Caddy!"
  echo "Please view /home/caddy/caddy-script.log for details."
}

set -e
prepare
check_root
create_user
install_caddy
install_php
install_phpmyadmin
install_caddy_service
install_mariadb
install_wordpress
install_shopware
finish
