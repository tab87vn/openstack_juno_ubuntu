#!/bin/bash

# Source in common env vars
. common.sh

# MySQL
export MYSQL_HOST=${CTL_ETH0_IP}
export MYSQL_ROOT_PASS=openstack
export MYSQL_DB_PASS=openstack

echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections

sudo apt-get -y install mariadb-server python-mysqldb

sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
sudo sed -i "s/^#max_connections.*/max_connections = 512/g" /etc/mysql/my.cnf

# Skip Name Resolve
echo "[mysqld]
skip-name-resolve" > /etc/mysql/conf.d/skip-name-resolve.cnf


# UTF-8 Stuff
echo "[mysqld]
collation-server = utf8_general_ci
init-connect='SET NAMES utf8'
character-set-server = utf8" > /etc/mysql/conf.d/01-utf8.cnf

sudo service mysql restart

# Ensure root can do its job
mysql -u root -p${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"localhost\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root -p${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"${MYSQL_HOST}\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root -p${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"%\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges
