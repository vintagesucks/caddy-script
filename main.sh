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
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    email="github@example.org"
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
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    protocol="http://"
    domain="127.0.0.1"
    port=":1337"
  else
    read -e -p "Enter a domain (e.g. example.org) " -r domain
    if [[ "${#domain}" -lt 1 ]]; then
      echo " >> Please enter a valid domain!"
      readDomain
    fi

    # Protocol
    if valid_ip "${domain}"; then
      protocol="http://"
    else
      protocol="https://"
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

function readWordPress()
{
  if [ "$GITHUB_ACTIONS" == 1 ] && [ "$FEATURE" = "wordpress" ]; then
    wordpress=1
  elif [ "$GITHUB_ACTIONS" == 1 ] && [ "$FEATURE" != "wordpress" ]; then
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

function readStartSetup()
{
  if [[ $GITHUB_ACTIONS == 1 ]]; then
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
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    apt-get install -y tzdata
    ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
    dpkg-reconfigure --frontend noninteractive tzdata
  else
    sudo dpkg-reconfigure tzdata
  fi
  readEmail
  readDomain
  readWordPress
  echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "             Domain: ${domain}"
  echo "              Email: ${email}"
  echo "          WordPress: ${wordpress}"
  echo ""
  readStartSetup
}

function check_root()
{
  if [[ $GITHUB_ACTIONS == 1 ]]; then
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
    echo "Adding user caddy to sudoers."
    echo 'caddy ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
    echo "Successfully set up user caddy and needed permissions."
  fi
}

function install_caddy()
{
  echo "Check Packages for updates"
  sudo apt-get update
  echo "Installing Caddy."
  apt-get install libcap2-bin curl sudo -y
  curl -L -o caddy.tar.gz https://github.com/caddyserver/caddy/releases/download/v2.2.1/caddy_2.2.1_linux_amd64.tar.gz
  tar -zxvf caddy.tar.gz caddy
  mv caddy /usr/local/bin/caddy
  rm caddy.tar.gz
  echo "Setting permissions for Caddy."
  chmod +x /usr/local/bin/caddy
  sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy
  echo "Creating Caddyfile."
  create_caddyfile
  echo "Setting up directories"
  mkdir /var/www
  echo "Setting up directories for ${domain}"
  mkdir /var/www/"${domain}"
  if [ "$wordpress" = 0 ]; then
    echo '<html lang="en"><head><title>Hello World</title></head><body>Hello World</body></html>' > /var/www/"${domain}"/index.html
  fi
}

function create_caddyfile()
{
  # Global options block
  sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
{
  email ${email}
}

EOT

  if [[ $GITHUB_ACTIONS == 1 ]]; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
${domain}${port} {
EOT
  elif valid_ip "${domain}"; then
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
  root * /var/www/${domain}
  encode zstd gzip
  file_server
  php_fastcgi 127.0.0.1:9000
EOT

  # Close basic Caddyfile
  sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
}
EOT

  # Add Caddyfile to CI log
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    cat /home/caddy/Caddyfile
  fi
}

function install_php()
{
  PHP="php7.4"
  PHPV="7.4"

  echo "Check Packages for updates"
  sudo apt-get update
  echo "Adding PHP repository"
  apt-get install -y language-pack-en-base software-properties-common
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y
  echo "Check Packages for updates"
  sudo apt-get update
  echo "Installing PHP and extensions"
  sudo apt-get install ${PHP}-fpm ${PHP}-mysql ${PHP}-curl ${PHP}-intl ${PHP}-mbstring ${PHP}-soap ${PHP}-xml ${PHP}-zip php-memcached memcached -y
  echo "Configuring PHP Settings for Caddy"
  OLDPHPCONF="listen \= \/run\/php\/php7\.4\-fpm\.sock"
  NEWPHPCONF="listen \= 127\.0\.0\.1\:9000"
  sudo sed -i "s/${OLDPHPCONF}/${NEWPHPCONF}/g" /etc/php/${PHPV}/fpm/pool.d/www.conf
  echo "Restarting PHP"
  sudo service ${PHP}-fpm restart
  echo "Installing Composer"
  curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
}

function install_caddy_service()
{
  echo "Registering Caddy as a Service"
  cat <<EOT >> /etc/systemd/system/caddy.service
[Unit]
Description=Caddy 2 - The Ultimate Server with Automatic HTTPS
Documentation=https://caddyserver.com/docs/
After=network.target

[Service]
User=caddy
WorkingDirectory=/home/caddy
LimitNOFILE=8192
PIDFile=/var/run/caddy/caddy.pid
ExecStart=/usr/local/bin/caddy start
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOT
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    sleep 0
  else
    sudo systemctl enable caddy
    systemctl daemon-reload
  fi
  echo "Successfully registered Caddy 2 as a Service."
}

function install_mariadb()
{
  MARIADB_ROOT_PASS=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev | tr -dc 'a-zA-Z0-9')
  sudo apt-get install mariadb-server -y
  service mysql restart
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
    send \"y\r\"
    expect \"Remove test database and access to it? \[Y/n\]\"
    send \"y\r\"
    expect \"Reload privilege tables now? \[Y/n\]\"
    send \"y\r\"
    expect eof
    ")
  echo "${SECURE_MYSQL}"
  apt remove expect -y
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

    # Download and install wp-cli
    curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /usr/local/bin/wp
    # Download latest WordPress version
    wp core download --path=/var/www/"${domain}" --allow-root
    # create wp-config.php
    wp core config --path=/var/www/"${domain}" --dbname=wordpress --dbuser=wordpress --dbpass="${wpdbpass}" --dbhost=localhost --allow-root
    #install WordPress
    wp core install --path=/var/www/"${domain}" --url="${protocol}""${domain}${port}" --title="${domain}" --admin_user=admin --admin_password="${wpadminpass}" --admin_email="${email}" --skip-email --allow-root
  fi
}

function finish()
{
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    sleep 0
  else
    echo "Remove packages that are no more needed."
    apt autoremove -y
  fi
  echo "Setting proper directory permissions"
  sudo chown -R caddy /home/caddy/
  sudo chown -R www-data:www-data /var/www/
  echo "Creating setup logfile"
  if [ "$wordpress" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/caddy-script.log
Thanks for using caddy-script!
If you run into any issues related to this setup, please open an issue at
https://github.com/vintagesucks/caddy-script

Domain:                       ${protocol}${domain}
MariaDB root password:        ${MARIADB_ROOT_PASS}
WordPress database name:      wordpress
WordPress database username:  wordpress
WordPress database password:  ${wpdbpass}
WordPress admin user:         admin
WordPress admin password:     ${wpadminpass}

Please keep this information somewhere safe (preferably not here!)
EOT
  else
    sudo -u caddy cat <<EOT >> /home/caddy/caddy-script.log
Thanks for using caddy-script!
If you run into any issues related to this setup, please open an issue at
https://github.com/vintagesucks/caddy-script

Domain:                       ${protocol}${domain}
MariaDB root password:        ${MARIADB_ROOT_PASS}

Please keep this information somewhere safe (preferably not here!)
EOT
  fi
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    ulimit -n 8192
    runuser -l caddy -c "/usr/local/bin/caddy start"
  else
    service caddy start
    clear
  fi
  echo "Successfully installed Caddy!"
  echo "Please view /home/caddy/caddy-script.log for details."
}

function tests()
{
  if [[ $GITHUB_ACTIONS == 1 ]]; then
    echo "Testing installation"
    echo "Installing Node.js"
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    apt-get update
    sudo apt-get install -y nodejs
    echo "Installing Nightwatch"
    npm install -g nightwatch
    echo "Installing Chrome"
    sudo apt-get install -y libgtk-3-0 gconf-service libasound2 libgconf-2-4 libnspr4 libx11-dev fonts-liberation xdg-utils libnss3 libxss1 libappindicator1 libindicator7 unzip wget libappindicator3-1 libgbm1
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo dpkg -i google-chrome*.deb
    sudo apt-get install -f
    echo "Installing ChromeDriver"
    wget -O chromedriver_version.txt https://chromedriver.storage.googleapis.com/LATEST_RELEASE
    CHROMEDRIVER_VERSION=$(cat chromedriver_version.txt)
    wget -N https://chromedriver.storage.googleapis.com/"$CHROMEDRIVER_VERSION"/chromedriver_linux64.zip
    unzip chromedriver_linux64.zip
    chmod +x chromedriver
    sudo mv -f chromedriver /usr/local/share/chromedriver
    sudo ln -s /usr/local/share/chromedriver /usr/local/bin/chromedriver
    sudo ln -s /usr/local/share/chromedriver /usr/bin/chromedriver
    echo "Running ChromeDriver"
    nohup /usr/bin/chromedriver --whitelisted-ips &
    echo "Running Nightwatch Tests"
    cd /
    nightwatch --test /tests/nightwatch/"$FEATURE".js
  fi
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
finish
tests
