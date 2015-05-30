#!/bin/bash

#  common.sh

source config.cfg

export DEBIAN_FRONTEND=noninteractive

# dynamic ip retrieval
ETH0_IP=$(ifconfig eth0 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH1_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH2_IP=$(ifconfig eth2 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

export MNG_NET_IP=${ETH0}
export VMN_NET_IP=${ETH1}
export EXT_NET_IP=${ETH2}
export INSTALL_DIR=$(pwd)

# echo ${CTL_ETH0_IP}
# echo $CTL_ETH0_IP
# echo ${MNG_NET_IP}
# echo ${NET_VMN_IF}
# echo ${NET_VMN_BR}
# echo ${INSTALL_DIR}



export GLANCE_HOST=${CTL_ETH0_IP}
export MYSQL_HOST=${CTL_ETH0_IP}
export KEYSTONE_ADMIN_ENDPOINT=${CTL_ETH0_IP}
export KEYSTONE_ENDPOINT=${CTL_ETH0_IP}
export CONTROLLER_EXTERNAL_HOST=${CTL_ETH0_IP}
export MYSQL_NEUTRON_PASS=openstack
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${CTL_ETH0_IP}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=https://${CTL_ETH0_IP}:35357/v2.0
export MONGO_KEY=MongoFoo
export OS_CACERT=${INSTALL_DIR}/ca.pem
export OS_KEY=${INSTALL_DIR}/cakey.pem

if [[ "$(egrep OpenStackHosts /etc/hosts | awk '{print $2}')" -eq "" ]]
then
	# Add host entries
	echo "
# OpenStackHosts
${CTL_ETH0_IP}	controller
${NET_ETH0_IP}	network
${CP1_ETH0_IP}	compute-01
${CP2_ETH0_IP}	compute-02
${CTL_ETH0_IP}	cinder" | sudo tee -a /etc/hosts
fi

sudo apt-get install -y software-properties-common ubuntu-cloud-keyring
sudo add-apt-repository -y cloud-archive:juno
sudo apt-get update && sudo apt-get upgrade -y