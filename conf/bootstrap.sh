#!/bin/bash

##############################################
######### SETUP
##############################################


DBPASSWD=root@2016
WP_DBNAME=testdb
WP_AD_NAME=admin
WP_AD_PASSWD=admin@2016
WP_AD_EMAIL=test1@gmail.com
WP_URL=testurl.local:8080

# check service exists
if sudo service --status-all | grep -Fq apache2; then
	echo -e "APACHE service exists"
else
	echo -e "\n--- Installing Apache2 service ---\n"
	sudo apt-get install apache2 -y
	sudo service apache2 start

	echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	echo -e "                         Installed Apache2 service                   "
	echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
fi

if ! command -v curl >/dev/null 2>&1; then
	sudo apt-get install -y curl
	sudo apt-get install -y python-software-properties --force-yes
fi

# check command exists
if ! command -v php >/dev/null 2>&1; then
	echo -e "\n--- Updating packages list ---\n"
	sudo add-apt-repository -y ppa:ondrej/php5
	sudo apt-get update

	echo -e "\n--- Installing PHP ---\n"
	sudo apt-get install php5 -y
	sudo apt-get install libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-readline php5-mysql git-core php5-xdebug

	echo -e "\n--- Enabling mod-rewrite ---\n"
	sudo a2enmod rewrite

	echo -e "\n--- Allowing Apache override to all ---\n"
	sudo sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

	echo -e "\n--- Allowing Apache is run by the Vagrant user/group ---\n"
	sudo sed -i "s/User .*/User vagrant/" /etc/apache2/apache2.conf
	sudo sed -i "s/Group .*/Group vagrant/" /etc/apache2/apache2.conf

	echo -e "\n--- Turning on PHP errors ---\n"
	sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
	sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
	sed -i "s/disable_functions = .*/disable_functions = /" /etc/php5/cli/php.ini

	echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	echo -e "                         Installed PHP service                     "
	echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
fi

if command -v mysql >/dev/null 2>&1; then
	echo -e "\n---  MYSQL service exists  ---\n"
else
	echo -e "\n--- Installing MYSQL 5.5 service  ---\n"
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DBPASSWD"
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DBPASSWD"
	sudo apt-get install mysql-server-5.5 -y

	echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	echo -e "                         Installed mysql service                   "
	echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

fi

if [ ! -d "/usr/share/phpmyadmin" ]; then
	echo -e "\n--- Installing phpMyAdmin ---\n"
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
	sudo apt-get install phpmyadmin -y

	echo -e "\n--- Configure Apache to use phpmyadmin ---\n"
	echo -e "\n\nListen 81\n" >> /etc/apache2/ports.conf
	sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
	cat > /etc/apache2/conf-available/phpmyadmin.conf <<-EOF
		<VirtualHost *:81>
			ServerAdmin webmaster@localhost
			DocumentRoot /var/www/html/phpmyadmin
			DirectoryIndex index.php
			ErrorLog ${APACHE_LOG_DIR}/phpmyadmin-error.log
			CustomLog ${APACHE_LOG_DIR}/phpmyadmin-access.log combined
		</VirtualHost>
	EOF
	a2enconf phpmyadmin

	echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	echo -e "                         Installed phpMyAdmin                      "
	echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
fi

if [ ! -e "/var/www/html/info.php" ]; then
	echo "\n--- Setup PHP info page ---\n"
	sudo echo "<?php phpinfo(); ?>" > /var/www/html/info.php
fi

if [[ ! -n "$(composer --version --no-ansi | grep 'Composer version')" ]]; then
	echo "Installing Composer..."
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer

	echo -e "\n--- Restarting Apache ---\n"
	sudo service apache2 restart > /dev/null 2>&1
fi

# Setup wordpress
if ! command -v wp >/dev/null 2>&1; then
	echo -e "\n---  Installing Wordpress-cli  ---\n"
	curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	sudo chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp
fi

if [ ! -d "/var/www/html/wp-content/themes" ]; then
	echo -e "\n---  Installing Wordpress Core  ---\n"
	sudo chown -R vagrant:vagrant /var/www/html/
	sudo -u vagrant bash <<-EOF
		cd /var/www/html/ && pwd;
		wp core download
		wp core config --dbuser=root --dbpass="$DBPASSWD" --dbname="$WP_DBNAME"
		wp db create
		wp core install --url="$WP_URL" --title=Internship --admin_user="$WP_AD_NAME" --admin_password="$WP_AD_PASSWD" --admin_email="$WP_AD_EMAIL"
	EOF

	cd -
	echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
	echo -e "                        Installed Wordpress Core                   "
	echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
fi

# start services
echo -e "\n--- Restarting Apache ---\n"
ps -ef | grep apache2 | grep -v grep
if [ $?  -eq "0" ]; then
	sudo service apache2 restart
else
	sudo service apache2 start
fi