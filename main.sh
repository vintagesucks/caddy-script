#!/bin/bash
#
#       Name: caddy-script
#     Author: Nikolas Evers
#   Homepage: https://github.com/vintagesucks/caddy-script
#

checkLogfile() {
  if [ ! -f /home/caddy/caddy-script.log ]; then
    sleep 0
  else
    clear
    echo " >> You already installed Caddy with caddy-script!"
    echo " >> Please view /home/caddy/caddy-script.log for your details."
    exit
fi
}

readEmail() {
  read -e -p "Enter an email address (e.g. admin@example.org) " -r email
  if [[ ${#email} -gt 2 ]]; then
    sleep 0
  else
    echo " >> Please enter a valid email address!"
    readEmail
  fi
}

readDomain() {
  read -e -p "Enter a domain (e.g. example.org) " -r domain
  if [[ "${#domain}" -lt 1 ]]; then
    echo " >> Please enter a valid domain!"
    readDomain
  fi
}

readCaddyExtensions() {
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

readWordPress() {
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

readStartSetup() {
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

prepare()
{
  checkLogfile
  sudo dpkg-reconfigure tzdata
  readEmail
  readDomain
  readCaddyExtensions
  readWordPress
  echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "Caddy Features: ${caddy_extensions}"
  echo "        Domain: ${domain}"
  echo "         Email: ${email}"
  echo "     WordPress: ${wordpress}"
  echo ""
  readStartSetup
}

check_root()
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

create_user()
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

install_caddy() {
  echo "Installing Caddy."
  sudo -u caddy curl -fsSL https://getcaddy.com | bash -s "${caddy_extensions}"
  echo "Setting permissions for Caddy."
  sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy
  echo "Creating Caddyfile."
  if [ "$wordpress" = 1 ]; then
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
www.${domain} {
  redir https://${domain}{uri}
}

${domain} {
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
  fastcgi / 127.0.0.1:9000 php {
    env PATH /bin
  }
  rewrite {
    if {path} not_match ^\/wp-admin
    to {path} {path}/ /index.php?_url={uri}
  }
}
EOT
  else
    sudo -u caddy cat <<EOT >> /home/caddy/Caddyfile
www.${domain} {
  redir https://${domain}{uri}
}

${domain} {
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
  fastcgi / 127.0.0.1:9000 php {
    env PATH /bin
  }
}
EOT
  fi
  echo "Setting up directorys for ${domain}"
  runuser -l caddy -c "mkdir ${domain}"
  runuser -l caddy -c "mkdir ${domain}/log"
  if [ "$wordpress" = 0 ]; then
    runuser -l caddy -c "mkdir ${domain}/www"
    runuser -l caddy -c "echo 'Hello World' > ${domain}/www/index.html"
  fi
}

install_php()
{
  echo "Adding PHP7 repository"
  sudo add-apt-repository ppa:ondrej/php -y
  echo "Check Packages for updates"
  sudo apt-get update
  echo "Installing PHP7 and extensions"
  sudo apt-get install php7.0-fpm php7.0-mysql php7.0-curl php7.0-intl php7.0-mcrypt -y
  echo "Configuring PHP Settings for Caddy"
  OLDPHPCONF="listen \= \/run\/php\/php7\.0\-fpm\.sock"
  NEWPHPCONF="listen \= 127\.0\.0\.1\:9000"
  sudo sed -i "s/${OLDPHPCONF}/${NEWPHPCONF}/g" /etc/php/7.0/fpm/pool.d/www.conf
  echo "Restarting PHP"
  sudo service php7.0-fpm restart
}

install_caddy_service()
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

install_mariadb() {
  choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
  MARIADB_ROOT_PASS="$({ choose '!@#%^\&'
    choose '0123456789'
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

install_wordpress() {
  if [[ "$wordpress" = 1 ]]; then
    echo "Installing WordPress"
    choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
    wpdbpass="$({ choose '!@#%^\&'
      choose '0123456789'
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
    runuser -l caddy -c "wget -P /home/caddy/${domain} http://wordpress.org/latest.tar.gz"
    runuser -l caddy -c "tar -xzf /home/caddy/${domain}/latest.tar.gz -C /home/caddy/${domain}"
    runuser -l caddy -c "mv /home/caddy/${domain}/wordpress /home/caddy/${domain}/www"
    runuser -l caddy -c "rm /home/caddy/${domain}/latest.tar.gz"
    cp /home/caddy/${domain}/www/wp-config-sample.php /home/caddy/${domain}/www/wp-config.php
    sudo sed -i "s/database_name_here/wordpress/g" /home/caddy/${domain}/www/wp-config.php
    sudo sed -i "s/username_here/wordpress/g" /home/caddy/${domain}/www/wp-config.php
    sudo sed -i "s/password_here/${wpdbpass}/g" /home/caddy/${domain}/www/wp-config.php
  fi
}

finish()
{
  echo "Granting www-data permission for /www directory"
  sudo chown -R www-data /home/caddy/${domain}/www
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
finish
