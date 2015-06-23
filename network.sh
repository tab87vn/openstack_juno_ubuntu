#!/bin/bash

# network.sh

# Exporting environment variables
echo "########## PREPARING... ##########"

export CONTROLLER_HOST=130.104.230.109
export CONTROLLER_EXT_HOST=10.0.100.6

export NETWORK_HOST=130.104.230.110
export NETWORK_VMN_HOST=192.168.100.7
export NETWORK_EXT_HOST=10.0.100.7

export COMPUTE1_HOST=130.104.230.106
export COMPUTE1_VMN_HOST=192.168.100.3
export COMPUTE1_EXT_HOST=10.0.100.3

export COMPUTE2_HOST=130.104.230.107
export COMPUTE2_VMN_HOST=192.168.100.4
export COMPUTE2_EXT_HOST=10.0.100.4

export INSTALL_DIR=/home/ubuntu/junoscript
export HOME_DIR=/home/ubuntu
# export INSTALL_DIR=/vagrant
# export HOME_DIR=/home/vagrant

# interfaces and bridges
export MNG_IP=130.104.230.110
export VMN_IP=192.168.100.7
export VMN_BR=br-em1
export VMN_IF=em1
export EXT_IP=10.0.100.7
export EXT_BR=br-ex
export EXT_IF=em3

export PUBLIC_IP=${MNG_IP} #EXT_IP
export INT_IP=${MNG_IP}
export ADMIN_IP=${MNG_IP} #EXT_IP

export GLANCE_HOST=${CONTROLLER_HOST}
export MYSQL_HOST=${CONTROLLER_HOST}
export KEYSTONE_ADMIN_ENDPOINT=${CONTROLLER_HOST} # CONTROLLER_EXT_HOST
export KEYSTONE_ENDPOINT=${KEYSTONE_ADMIN_ENDPOINT}
#export CONTROLLER_EXTERNAL_HOST=${KEYSTONE_ADMIN_ENDPOINT}
export MYSQL_NEUTRON_PASS=openstack
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${KEYSTONE_ADMIN_ENDPOINT}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=https://${KEYSTONE_ADMIN_ENDPOINT}:35357/v2.0
export MONGO_KEY=MongoFoo
export OS_CACERT=${INSTALL_DIR}/ca.pem
export OS_KEY=${INSTALL_DIR}/cakey.pem

# configure host resolution
echo "
# OpenStack hosts
${CONTROLLER_HOST} controller.ostest controller
${NETWORK_HOST} network.ostest network
${COMPUTE1_HOST} compute-01.ostest compute-01
${COMPUTE2_HOST} compute-02.ostest compute-02" | sudo tee -a /etc/hosts

# UPGRADE
sudo apt-get install -y software-properties-common ubuntu-cloud-keyring
sudo add-apt-repository -y cloud-archive:juno
sudo apt-get update && sudo apt-get upgrade -y


# ssh-keyscan controller >> ~/.ssh/known_hosts
# cat ${INSTALL_DIR}/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys
# cp ${INSTALL_DIR}/id_rsa* ~/.ssh/
sudo scp ubuntu@controller:/etc/ssl/certs/ca.pem /etc/ssl/certs/ca.pem
sudo c_rehash /etc/ssl/certs/ca.pem

##########################
# Chapter 3 - Networking #
##########################

echo "net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0" | tee -a /etc/sysctl.conf
sysctl -p

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install linux-headers-`uname -r`
sudo apt-get -y install vlan bridge-utils dnsmasq-base dnsmasq-utils
sudo apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent openvswitch-switch neutron-l3-agent neutron-dhcp-agent ipset python-mysqldb neutron-lbaas-agent haproxy

sudo /etc/init.d/openvswitch-switch start


# OpenVSwitch Configuration
#br-int will be used for VM integration
#sudo ovs-vsctl add-br br-int

# Neutron Tenant Tunnel Network
sudo ovs-vsctl add-br ${VMN_BR}
sudo ovs-vsctl add-port ${VMN_BR} ${VMN_IF}

# In reality you would edit the /etc/network/interfaces file for eth3?
sudo ifconfig ${VMN_IF} 0.0.0.0 up
sudo ip link set ${VMN_IF} promisc on
# Assign IP to br-eth2 so it is accessible
sudo ifconfig ${VMN_BR} ${VMN_IP} netmask 255.255.255.0

# Neutron External Router Network
sudo ovs-vsctl add-br ${EXT_BR}
sudo ovs-vsctl add-port ${EXT_BR} ${EXT_IF}

# In reality you would edit the /etc/network/interfaces file for eth3
sudo ifconfig ${EXT_IF} 0.0.0.0 up
sudo ip link set ${EXT_IF} promisc on
# Assign IP to br-ex so it is accessible
sudo ifconfig ${EXT_BR} ${EXT_IP} netmask 255.255.255.0


# Configuration

# Config Files
NEUTRON_CONF=/etc/neutron/neutron.conf
NEUTRON_PLUGIN_ML2_CONF_INI=/etc/neutron/plugins/ml2/ml2_conf.ini
NEUTRON_L3_AGENT_INI=/etc/neutron/l3_agent.ini
NEUTRON_DHCP_AGENT_INI=/etc/neutron/dhcp_agent.ini
NEUTRON_DNSMASQ_CONF=/etc/neutron/dnsmasq-neutron.conf
NEUTRON_METADATA_AGENT_INI=/etc/neutron/metadata_agent.ini
NEUTRON_FWAAS_DRIVER_INI=/etc/neutron/fwaas_driver.ini
NEUTRON_VPNAAS_AGENT_INI=/etc/neutron/vpn_agent.ini
NEUTRON_LBAAS_AGENT_INI=/etc/neutron/lbaas_agent.ini

SERVICE_TENANT=service
NEUTRON_SERVICE_USER=neutron
NEUTRON_SERVICE_PASS=neutron

# Configure Neutron
cat > ${NEUTRON_CONF} << EOF
[DEFAULT]
verbose = True
debug = False
state_path = /var/lib/neutron
lock_path = \$state_path/lock
log_dir = /var/log/neutron
use_syslog = True
syslog_log_facility = LOG_LOCAL0

bind_host = 0.0.0.0
bind_port = 9696

# Plugin
core_plugin = ml2
# service_plugins: router firewall lbaas vpn
#service_plugins = router,firewall
service_plugins = router, lbaas
allow_overlapping_ips = True
#router_distributed = True

# auth
auth_strategy = keystone

# RPC configuration options. Defined in rpc __init__
# The messaging module to use, defaults to kombu.
rpc_backend = neutron.openstack.common.rpc.impl_kombu

rabbit_host = ${CONTROLLER_HOST}
rabbit_password = guest
rabbit_port = 5672
rabbit_userid = guest
rabbit_virtual_host = /
rabbit_ha_queues = false

# ============ Notification System Options =====================
notification_driver = neutron.openstack.common.notifier.rpc_notifier

[agent]
root_helper = sudo

[keystone_authtoken]
auth_host = ${KEYSTONE_ADMIN_ENDPOINT}
auth_port = 35357
auth_protocol = https
admin_tenant_name = ${SERVICE_TENANT}
admin_user = ${NEUTRON_SERVICE_USER}
admin_password = ${NEUTRON_SERVICE_PASS}
signing_dir = \$state_path/keystone-signing
insecure = True

[database]
connection = mysql://neutron:${MYSQL_NEUTRON_PASS}@${CONTROLLER_HOST}/neutron

[service_providers]
service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
#service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default
#service_provider=FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default

EOF

cat > ${NEUTRON_L3_AGENT_INI} << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
use_namespaces = True
#agent_mode = dvr_snat
external_network_bridge = br-ex
verbose = True
EOF

cat > ${NEUTRON_DHCP_AGENT_INI} << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
use_namespaces = True
dnsmasq_config_file=${NEUTRON_DNSMASQ_CONF}
EOF

cat > ${NEUTRON_DNSMASQ_CONF} << EOF
# To allow tunneling bytes to be appended
dhcp-option-force=26,1400
EOF

cat > ${NEUTRON_METADATA_AGENT_INI} << EOF
[DEFAULT]
auth_url = https://${KEYSTONE_ENDPOINT}:5000/v2.0
auth_region = regionOne
admin_tenant_name = service
admin_user = ${NEUTRON_SERVICE_USER}
admin_password = ${NEUTRON_SERVICE_PASS}
nova_metadata_ip = ${CONTROLLER_HOST}
metadata_proxy_shared_secret = foo
auth_insecure = True
EOF

cat > ${NEUTRON_PLUGIN_ML2_CONF_INI} << EOF
[ml2]
type_drivers = gre,vxlan,vlan,flat
tenant_network_types = vxlan
mechanism_drivers = openvswitch,l2population

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]
#vxlan_group =
vni_ranges = 1:1000

#[vxlan]
#enable_vxlan = True
#vxlan_group =
#local_ip = ${ETH2_IP}
#l2_population = True

[agent]
tunnel_types = vxlan
l2_population = True
#enable_distributed_routing = True
#arp_responder = True

[ovs]
local_ip = ${MNG_IP}
tunnel_type = vxlan
enable_tunneling = True
l2_population = True
#enable_distributed_routing = True
tunnel_bridge = br-tun

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True
EOF

cat > ${NEUTRON_FWAAS_DRIVER_INI} <<EOF
[fwaas]
driver = neutron.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver
enabled = True
EOF

cat > ${NEUTRON_VPNAAS_AGENT_INI} <<EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver

[vpnagent]
vpn_device_driver=neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver

[ipsec]
ipsec_status_check_interval=60
EOF

cat > ${NEUTRON_LBAAS_AGENT_INI} <<EOF
[DEFAULT]
debug = False
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
device_driver = neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver

[haproxy]
loadbalancer_state_path = \$state_path/lbaas
user_group = nogroup
EOF

echo "
Defaults !requiretty
neutron ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers


# Restart Neutron Services
sudo service neutron-plugin-openvswitch-agent restart
sudo service neutron-dhcp-agent restart
sudo service neutron-l3-agent stop # DVR SO DONT RUN
sudo service neutron-l3-agent start # NON-DVR
sudo service neutron-lbaas-agent stop
sudo service neutron-lbaas-agent start
sudo service neutron-metadata-agent restart
#sudo service neutron-vpn-agent stop
#sudo service neutron-vpn-agent start

cat  ${INSTALL_DIR}/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys

# Logging
sudo stop rsyslog
sudo cp ${INSTALL_DIR}/rsyslog.conf /etc/rsyslog.conf
sudo echo "*.*         @@controller:5140" >> /etc/rsyslog.d/50-default.conf
sudo service rsyslog restart

# Copy openrc file to local instance vagrant root folder in case of loss of file share
sudo cp ${INSTALL_DIR}/openrc ${HOME_DIR} 
