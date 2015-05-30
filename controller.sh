#!/bin/bash -ex
# OpenStack Juno Controller installation script

# Import config file
source config.cfg

############################################################
################## PART 1: CONFIG HOST NAME ################
############################################################
echo "Configuring hostname in CONTROLLER node"
sleep 3
# echo "controller" > /etc/hostname
# hostname -F /etc/hostname

echo "Configuring for file /etc/hosts"
sleep 3
iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost
127.0.1.1       controller
$CON_MGNT_IP    controller
$COM1_MGNT_IP  	compute1
$COM2_MGNT_IP	compute2
$NET_MGNT_IP     network
EOF

# Update repos
apt-get install ubuntu-cloud-keyring -y
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
"trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list

sleep 5
echo "UPDATE PACKAGE FOR JUNO"
apt-get -y update && apt-get -y dist-upgrade

echo "Install and config NTP"
sleep 3 
apt-get install ntp -y
cp /etc/ntp.conf /etc/ntp.conf.bka
rm /etc/ntp.conf
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf


## Config NTP in JUNO
sed -i 's/server ntp.ubuntu.com/ \
server 0.vn.pool.ntp.org iburst \
server 1.asia.pool.ntp.org iburst \
server 2.asia.pool.ntp.org iburst/g' /etc/ntp.conf

sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery/ \
#restrict -4 default kod notrap nomodify nopeer noquery/g' /etc/ntp.conf

sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery/ \
restrict -4 default kod notrap nomodify \
restrict -6 default kod notrap nomodify/g' /etc/ntp.conf

# sed -i 's/server/#server/' /etc/ntp.conf
# echo "server $CON_MGNT_IP" >> /etc/ntp.conf

############################################################
################## PART 2: INSTALL RABBITMQ ################
############################################################


##############################################
echo "Install and Config RabbitMQ"
sleep 3
apt-get install rabbitmq-server -y
rabbitmqctl change_password guest $RABBIT_PASS
sleep 3

service rabbitmq-server restart
echo "Finish setup pre-install package !!!"



############################################################
################## PART 3: CONFIG DATABASE ################
############################################################

echo "##### Install MYSQL #####"
sleep 3

echo mysql-server mysql-server/root_password password $MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_PASS | debconf-set-selections
apt-get -y install mariadb-server python-mysqldb curl 

echo "##### Configuring MYSQL #####"
sleep 3


echo "########## CONFIGURING FOR MYSQL ##########"
sleep 5
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
#
sed -i "/bind-address/a\default-storage-engine = innodb\n\
innodb_file_per_table\n\
collation-server = utf8_general_ci\n\
init-connect = 'SET NAMES utf8'\n\
character-set-server = utf8" /etc/mysql/my.cnf

#
service mysql restart


echo "##### Create OPS DATABASE #####"
sleep 3

cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;
DROP DATABASE IF EXISTS glance;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS cinder;
DROP DATABASE IF EXISTS neutron;
#
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'$CON_MGNT_IP' IDENTIFIED BY '$NOVA_DBPASS';
CREATE DATABASE glance;
#
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'$CON_MGNT_IP' IDENTIFIED BY '$GLANCE_DBPASS';
#
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'$CON_MGNT_IP' IDENTIFIED BY '$KEYSTONE_DBPASS';
#
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$CON_MGNT_IP' IDENTIFIED BY '$CINDER_DBPASS';
#
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'$CON_MGNT_IP' IDENTIFIED BY '$NEUTRON_DBPASS';
#
FLUSH PRIVILEGES;
EOF
#
echo "##### Finish setup and config OPS DB !! #####"
# exit;


############################################################
################## PART 4: INSTALL KEYSTONE ################
############################################################

# TOKEN_PASS=a
# MYSQL_PASS=a
# ADMIN_PASS=a


echo "##### Install keystone #####"
apt-get -y install keystone python-keystoneclient 

#/* Back-up file nova.conf
filekeystone=/etc/keystone/keystone.conf
test -f $filekeystone.orig || cp $filekeystone $filekeystone.orig

#Config file /etc/keystone/keystone.conf
cat << EOF > $filekeystone
[DEFAULT]
verbose = True
log_dir=/var/log/keystone
admin_token = $TOKEN_PASS

[assignment]
[auth]
[cache]
[catalog]
[credential]

[database]
connection = mysql://keystone:$KEYSTONE_DBPASS@$CON_MGNT_IP/keystone

[ec2]
[endpoint_filter]
[endpoint_policy]
[federation]
[identity]
[identity_mapping]
[kvs]
[ldap]
[matchmaker_redis]
[matchmaker_ring]
[memcache]
[oauth1]
[os_inherit]
[paste_deploy]
[policy]
[revoke]
[saml]
[signing]
[ssl]
[stats]
[token]
provider = keystone.token.providers.uuid.Provider
driver = keystone.token.persistence.backends.sql.Token

[trust]
[extra_headers]
Distribution = Ubuntu

EOF

#
echo "##### Remove keystone default db #####"
rm  /var/lib/keystone/keystone.db

echo "##### Restarting keystone service #####"
service keystone restart
sleep 3
service keystone restart

echo "##### Syncing keystone DB #####"
sleep 3
keystone-manage db_sync

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone



############################################################
################## PART 5: CREATE DEFAULT TENANT ################
############################################################

export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$CON_MGNT_IP:35357/v2.0"
export SERVICE_ENDPOINT="http://$CON_MGNT_IP:35357/v2.0"

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

echo "########## Begin configuring tenants, users and roles in Keystone ##########"
# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=$ADMIN_TENANT_NAME)
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)
DEMO_TENANT=$(get_id keystone tenant-create --name=$DEMO_TENANT_NAME)
INVIS_TENANT=$(get_id keystone tenant-create --name=$INVIS_TENANT_NAME)

# Users
ADMIN_USER=$(get_id keystone user-create --name="$ADMIN_USER_NAME" --pass="$ADMIN_PASS" --email=congtt@teststack.com)
DEMO_USER=$(get_id keystone user-create --name="$DEMO_USER_NAME" --pass="$ADMIN_PASS" --email=congtt@teststack.com)

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name="$ADMIN_ROLE_NAME")
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name="$KEYSTONEADMIN_ROLE_NAME")
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name="$KEYSTONESERVICE_ROLE_NAME")

# Add Roles to Users in Tenants
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONEADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONESERVICE_ROLE --tenant-id $ADMIN_TENANT

# The Member role is used by Horizon and Swift
MEMBER_ROLE=$(get_id keystone role-create --name="$MEMBER_ROLE_NAME")
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $DEMO_TENANT
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $INVIS_TENANT

# Configure service users/roles
NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=nova@teststack.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE

GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=glance@teststack.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE

SWIFT_USER=$(get_id keystone user-create --name=swift --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=swift@teststack.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $SWIFT_USER --role-id $ADMIN_ROLE

RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $RESELLER_ROLE

NEUTRON_USER=$(get_id keystone user-create --name=neutron --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=neutron@teststack.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NEUTRON_USER --role-id $ADMIN_ROLE

CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=cinder@teststack.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE

echo "########## Begin create ENDPOINT for OPS service ########## "
sleep 5 

#API Endpoint
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://$CON_MGNT_IP:5000/v2.0 \
--internalurl=http://$CON_MGNT_IP:5000/v2.0 \
--adminurl=http://$CON_MGNT_IP:35357/v2.0

keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://$CON_MGNT_IP:9292 \
--internalurl=http://$CON_MGNT_IP:9292 \
--adminurl=http://$CON_MGNT_IP:9292

keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://$CON_MGNT_IP:8774/v2/%\(tenant_id\)s \
--internalurl=http://$CON_MGNT_IP:8774/v2/%\(tenant_id\)s \
--adminurl=http://$CON_MGNT_IP:8774/v2/%\(tenant_id\)s

keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create \
--service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://$CON_MGNT_IP:9696 \
--adminurl http://$CON_MGNT_IP:9696 \
--internalurl http://$CON_MGNT_IP:9696

keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s \
--internalurl=http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s \
--adminurl=http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s

keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
--publicurl=http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s \
--internalurl=http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s \
--adminurl=http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s

echo "########## Creating environment script ##########"
sleep 5
echo "export OS_USERNAME=admin" > admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$CON_MGNT_IP:35357/v2.0" >> admin-openrc.sh

echo "########## Unset previous environment variable ##########"
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
chmod +x admin-openrc.sh


sleep 5
echo "########## Execute environment script ##########"
# source admin-openrc.sh
cat  admin-openrc.sh >> /etc/profile
cp  admin-openrc.sh /root/admin-openrc.sh

# export OS_USERNAME=admin
# export OS_PASSWORD=$ADMIN_PASS
# export OS_TENANT_NAME=admin
# export OS_AUTH_URL=http://$CON_MGNT_IP:35357/v2.0

echo "########## Finish setup keystone ##########"

# echo "#################### Testing ##################"
# sleep 5
# keystone user-list



############################################################
################## PART 6: INSTALL GLANCE ################
############################################################

echo "########## Install GLANCE ##########"
apt-get -y install glance python-glanceclient
sleep 10
echo "########## Configuring GLANCE API ##########"
sleep 5 
#/* Back-up file nova.conf
fileglanceapicontrol=/etc/glance/glance-api.conf
test -f $fileglanceapicontrol.orig || cp $fileglanceapicontrol $fileglanceapicontrol.orig
rm $fileglanceapicontrol
touch $fileglanceapicontrol

#Configuring glance config file /etc/glance/glance-api.conf

cat << EOF > $fileglanceapicontrol
[DEFAULT]
verbose = True
default_store = file
bind_host = 0.0.0.0
bind_port = 9292
log_file = /var/log/glance/api.log
backlog = 4096
registry_host = 0.0.0.0
registry_port = 9191
registry_client_protocol = http
rabbit_host = $CON_MGNT_IP
rabbit_port = 5672
rabbit_use_ssl = false
rabbit_userid = guest
rabbit_password = guest
rabbit_virtual_host = /
rabbit_notification_exchange = glance
rabbit_notification_topic = notifications
rabbit_durable_queues = False
qpid_notification_exchange = glance
qpid_notification_topic = notifications
qpid_hostname = localhost
qpid_port = 5672
qpid_username =
qpid_password =
qpid_sasl_mechanisms =
qpid_reconnect_timeout = 0
qpid_reconnect_limit = 0
qpid_reconnect_interval_min = 0
qpid_reconnect_interval_max = 0
qpid_reconnect_interval = 0
qpid_heartbeat = 5
qpid_protocol = tcp
qpid_tcp_nodelay = True
delayed_delete = False
scrub_time = 43200
scrubber_datadir = /var/lib/glance/scrubber
image_cache_dir = /var/lib/glance/image-cache/

[database]
connection = mysql://glance:$GLANCE_DBPASS@$CON_MGNT_IP/glance
backend = sqlalchemy

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = glance
admin_password = $GLANCE_PASS
 
[paste_deploy]
flavor = keystone

[store_type_location_strategy]
[profiler]
[task]
[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

swift_store_auth_version = 2
swift_store_auth_address = 127.0.0.1:5000/v2.0/
swift_store_user = jdoe:jdoe
swift_store_key = a86850deb2742ec3cb41518e26aa2d89
swift_store_container = glance
swift_store_create_container_on_put = False
swift_store_large_object_size = 5120
swift_store_large_object_chunk_size = 200
swift_enable_snet = False
s3_store_host = 127.0.0.1:8080/v1.0/
s3_store_access_key = <20-char AWS access key>
s3_store_secret_key = <40-char AWS secret key>
s3_store_bucket = <lowercased 20-char aws access key>glance
s3_store_create_bucket_on_put = False
sheepdog_store_address = localhost
sheepdog_store_port = 7000
sheepdog_store_chunk_size = 64

EOF

#
sleep 10
echo "########## Configuring GLANCE REGISTER ##########"
#/* Backup file file glance-registry.conf
fileglanceregcontrol=/etc/glance/glance-registry.conf
test -f $fileglanceregcontrol.orig || cp $fileglanceregcontrol $fileglanceregcontrol.orig
rm $fileglanceregcontrol
touch $fileglanceregcontrol
#Config file /etc/glance/glance-registry.conf

cat << EOF > $fileglanceregcontrol
[DEFAULT]
bind_host = 0.0.0.0
bind_port = 9191
log_file = /var/log/glance/registry.log
backlog = 4096
api_limit_max = 1000
limit_param_default = 25
rabbit_host = $CON_MGNT_IP
rabbit_port = 5672
rabbit_use_ssl = false
rabbit_userid = guest
rabbit_password = guest
rabbit_virtual_host = /
rabbit_notification_exchange = glance
rabbit_notification_topic = notifications
rabbit_durable_queues = False
qpid_notification_exchange = glance
qpid_notification_topic = notifications
qpid_hostname = $CON_MGNT_IP
qpid_port = 5672
qpid_username =
qpid_password =
qpid_sasl_mechanisms =
qpid_reconnect_timeout = 0
qpid_reconnect_limit = 0
qpid_reconnect_interval_min = 0
qpid_reconnect_interval_max = 0
qpid_reconnect_interval = 0
qpid_heartbeat = 5
qpid_protocol = tcp
qpid_tcp_nodelay = True

[database]
connection = mysql://glance:$GLANCE_DBPASS@$CON_MGNT_IP/glance
backend = sqlalchemy

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = glance
admin_password = $GLANCE_PASS

[paste_deploy]
flavor = keystone
[profiler]
EOF

sleep 7
echo "########## Remove Glance default DB ##########"
# rm /var/lib/glance/glance.sqlite

sleep 7
echo "########## Syncing DB for Glance ##########"
glance-manage db_sync

sleep 5
echo "########## Restarting GLANCE service ... ##########"
service glance-registry restart
service glance-api restart
sleep 3
service glance-registry restart
service glance-api restart

#
sleep 3
echo "########## Registering Cirros IMAGE for GLANCE ... ##########"
mkdir images
cd images/
# wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
# glance image-create --name "cirros-0.3.3-x86_64" --disk-format qcow2 \
# --container-format bare --is-public True --progress < cirros-0.3.3-x86_64-disk.img
# cd /root/
# # rm -r /tmp/images

# Get the images
# First check host
CIRROS="cirros-0.3.0-x86_64-disk.img"
UBUNTU="trusty-server-cloudimg-amd64-disk1.img"

if [[ ! -f /home/ubuntu/openstack_juno_ubuntu/images/${CIRROS} ]]
then
        # Download then store on local host for next time
	wget --quiet https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img -O /home/ubuntu/openstack_juno_ubuntu/images/${CIRROS}
fi

if [[ ! -f /home/ubuntu/openstack_juno_ubuntu/images/${UBUNTU} ]]
then
        # Download then store on local host for next time
	wget --quiet http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img -O /home/ubuntu/openstack_juno_ubuntu/images/${UBUNTU}
fi

glance image-create --name='trusty-image' --disk-format=qcow2 --container-format=bare --public < /home/ubuntu/openstack_juno_ubuntu/images/${UBUNTU}
glance image-create --name='cirros-image' --disk-format=qcow2 --container-format=bare --public < /home/ubuntu/openstack_juno_ubuntu/images/${CIRROS}


sleep 5
echo "########## Testing Glance ##########"
glance image-list


############################################################
################## PART 7: INSTALL NOVA ####################
############################################################

echo "########## Install NOVA in $CON_MGNT_IP ##########"
sleep 5 
apt-get -y install nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
apt-get install libguestfs-tools -y

######## Backup configurations for NOVA ##########"
sleep 7

# Qemu or KVM (VT-x/AMD-v)
KVM=$(egrep '(vmx|svm)' /proc/cpuinfo)
if [[ ${KVM} ]]
then
	LIBVIRT=kvm
else
	LIBVIRT=qemu
fi

#
controlnova=/etc/nova/nova.conf
test -f $controlnova.orig || cp $controlnova $controlnova.orig
rm $controlnova
touch $controlnova
cat << EOF >> $controlnova
[DEFAULT]
verbose = True

dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
libvirt_type=${LIBVIRT}
verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

# Register with RabbitMQ
rpc_backend = rabbit
rabbit_host = $CON_MGNT_IP
rabbit_password = $RABBIT_PASS

auth_strategy = keystone

my_ip = $CON_MGNT_IP

vncserver_listen = $CON_MGNT_IP
vncserver_proxyclient_address = $CON_MGNT_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[neutron]
url = http://$CON_MGNT_IP:9696
auth_strategy = keystone
admin_auth_url = http://$CON_MGNT_IP:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $NEUTRON_PASS
service_metadata_proxy = True
metadata_proxy_shared_secret = $METADATA_SECRET


[glance]
host = $CON_MGNT_IP



[database]
connection = mysql://nova:$NOVA_DBPASS@$CON_MGNT_IP/nova

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = nova
admin_password = $NOVA_PASS

EOF

echo "########## Remove Nova default db ##########"
sleep 7
rm /var/lib/nova/nova.sqlite

echo "########## Syncing Nova DB ##########"
sleep 7 
nova-manage db sync

# fix bug libvirtError: internal error: no supported architecture for os type 'hvm'
echo 'kvm_intel' >> /etc/modules

echo "########## Restarting NOVA ... ##########"
sleep 7 
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
sleep 7 
echo "########## Restarting NOVA ... ##########"
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo "########## Testing NOVA service ##########"
nova-manage service list

sleep 30

############################################################
################## PART 8: INSTALL NEUTRON ####################
############################################################

# RABBIT_PASS=a
# ADMIN_PASS=a


SERVICE_TENANT_ID=`keystone tenant-get service | awk '$2~/^id/{print $4}'`


echo "########## Install NEUTRON in $CON_MGNT_IP or NETWORK node ################"
sleep 5
apt-get -y install neutron-server neutron-plugin-ml2 python-neutronclient

######## Backup configuration NEUTRON.CONF in $CON_MGNT_IP##################"
echo "########## Config NEUTRON in $CON_MGNT_IP/NETWORK node ##########"
sleep 7

#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig
rm $controlneutron
touch $controlneutron
cat << EOF >> $controlneutron
[DEFAULT]
verbose = True
lock_path = \$state_path/lock

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

rpc_backend = rabbit
rabbit_host = $CON_MGNT_IP
rabbit_password = $RABBIT_PASS

auth_strategy = keystone

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://$CON_MGNT_IP:8774/v2
nova_admin_auth_url = http://$CON_MGNT_IP:35357/v2.0
nova_region_name = regionOne
nova_admin_username = nova
nova_admin_tenant_id = $SERVICE_TENANT_ID
nova_admin_password = $NOVA_PASS

[matchmaker_redis]
[matchmaker_ring]

[quotas]
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = neutron
admin_password = $NEUTRON_PASS

[database]
connection = mysql://neutron:$NEUTRON_DBPASS@$CON_MGNT_IP/neutron

[service_providers]
service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default

EOF


######## Backup configuration of ML2 in $CON_MGNT_IP##################"
echo "########## Configuring ML2 in $CON_MGNT_IP/NETWORK node ##########"
sleep 7

controlML2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $controlML2.orig || cp $controlML2 $controlML2.orig
rm $controlML2
touch $controlML2

cat << EOF >> $controlML2
[ml2]
type_drivers = flat,gre
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_flat]
[ml2_type_vlan]
[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
--config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron
  
echo "########## Restarting NOVA service ##########"
sleep 7 
service nova-api restart
service nova-scheduler restart
service nova-conductor restart

echo "########## Restarting NEUTRON service ##########"
sleep 7 
service neutron-server restart


############################################################
################## PART 9: INSTALL CINDER ####################
###########################################################

apt-get install lvm2 -y

echo "########## Create Physical Volume and Volume Group (in sdb disk ) ##########"
fdisk -l
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

#
echo "########## Install CINDER ##########"
sleep 3
apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-cinderclient


echo "########## Configuring for cinder.conf ##########"

filecinder=/etc/cinder/cinder.conf
test -f $filecinder.orig || cp $filecinder $filecinder.orig
rm $filecinder
cat << EOF > $filecinder
[DEFAULT]
verbose = True

rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes

auth_strategy = keystone

rpc_backend = rabbit
rabbit_host = $CON_MGNT_IP
rabbit_password = $RABBIT_PASS

my_ip = $CON_MGNT_IP

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = cinder
admin_password = $CINDER_PASS

[database]
connection = mysql://cinder:$CINDER_DBPASS@$CON_MGNT_IP/cinder

EOF

sed  -r -e 's#(filter = )(\[ "a/\.\*/" \])#\1[ "a\/sda1\/", "a\/sdb\/", "r/\.\*\/"]#g' /etc/lvm/lvm.conf

# Grant permission for cinder
chown cinder:cinder $filecinder

echo "########## Syncing Cinder DB ##########"
sleep 3
cinder-manage db sync

echo "########## Restarting CINDER service ##########"
sleep 3
service cinder-api restart
service cinder-scheduler restart
service cinder-volume restart

echo "########## Finish setting up CINDER !!! ##########"


############################################################
################## PART 10: INSTALL HORIZON/DASHBOARD ####################
###########################################################

###################
echo "########## START INSTALLING OPS DASHBOARD ##########"
###################
sleep 5

echo "########## Installing Dashboard package ##########"
apt-get -y install openstack-dashboard memcached && dpkg --purge openstack-dashboard-ubuntu-theme

echo "########## Fix bug in apache2 ##########"
sleep 5
# Fix bug apache in ubuntu 14.04
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
sudo a2enconf servername 

echo "########## Creating redirect page ##########"

filehtml=/var/www/html/index.html
test -f $filehtml.orig || cp $filehtml $filehtml.orig
rm $filehtml
touch $filehtml
cat << EOF >> $filehtml
<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$CON_MGNT_IP/horizon">
</head>
<body>
<center> <h1>Redirecting to OpenStack Dashboard</h1> </center>
</body>
</html>
EOF
# Allowing insert password in dashboard ( only apply in image )
sed -i "s/'can_set_password': False/'can_set_password': True/g" /etc/openstack-dashboard/local_settings.py

## /* Restarting apache2 and memcached
service apache2 restart
service memcached restart
echo "########## Finish setting up Horizon ##########"

echo "########## LOGIN INFORMATION IN HORIZON ##########"
echo "URL: http://$CON_EXT_IP/horizon"
echo "User: admin or demo"
echo "Password:" $ADMIN_PASS