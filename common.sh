#!/bin/bash

#  common.sh

export DEBIAN_FRONTEND=noninteractive

# LOCAL_PATH=os.path.dirname(os.path.abspath(__file__))
export INSTALL_DIR=$(pwd)

# dynamic ip retrieval
ETH0_IP=$(ifconfig eth0 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH1_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH2_IP=$(ifconfig eth2 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

export MNG_NET_IP=$ETH0
export VMN_NET_IP=$ETH1
export EXT_NET_IP=$ETH2

export ETH2_NETWORK=192.168.100.0

export CTL_ETH0_IP=172.31.20.200
export CTL_ETH1_IP=172.31.22.200
export CTL_ETH2_IP=172.31.23.200

export NET_ETH0_IP=172.31.20.201
export NET_ETH1_IP=172.31.22.201
export NET_ETH2_IP=172.21.23.201

export CP1_ETH0_IP=172.31.20.202
export CP1_ETH1_IP=172.31.22.202
export CP1_ETH2_IP=172.31.23.202

export CP2_ETH0_IP=172.31.20.203
export CP2_ETH1_IP=172.31.22.203
export CP2_ETH2_IP=172.31.23.203


export COM_MNG_IF=eth0
export COM_MNG_BR=br-int

export COM_VMN_IF=eth1 #em2
export COM_VMN_BR=br-eth1

export COM_EXT_IF=eth2 #em1
export COM_EXT_BR=br-ex

export NET_MNG_IF=eth0
export NET_MNG_BR=br-int

export NET_VMN_IF=eth1 #em2
export NET_VMN_BR=br-eth1

export NET_EXT_IF=eth2 #em1
export NET_EXT_BR=br-ex




# export CONTROLLER_HOST=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}' | sed 's/\.[0-9]*$/.200/')
# export CONTROLLER_HOST
export GLANCE_HOST=${CTL_ETH0_IP}
export MYSQL_HOST=${CTL_ETH0_IP}
# export KEYSTONE_ADMIN_ENDPOINT=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}' | sed 's/\.[0-9]*$/.200/')
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

sudo apt-get install -y software-properties-common ubuntu-cloud-keyring
sudo add-apt-repository -y cloud-archive:juno
sudo apt-get update && sudo apt-get upgrade -y

if [[ "$(egrep CookbookHosts /etc/hosts | awk '{print $2}')" -eq "" ]]
then
	# Add host entries
	echo "
# CookbookHosts
${CTL_ETH0_IP}	controller
${NET_ETH0_IP}	network
${CP1_ETH0_IP}	compute-01
${CP2_ETH0_IP}	compute-02
${CTL_ETH0_IP}	cinder" | sudo tee -a /etc/hosts
fi