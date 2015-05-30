#!/bin/bash

# install-rabbitmq.sh


# Make ourselves a new rabbit.conf
cat > /etc/rabbitmq/rabbitmq.config <<EOF
[{rabbit, [{loopback_users, []}]}].
EOF

cat > /etc/rabbitmq/rabbitmq-env.conf <<EOF
RABBITMQ_NODE_PORT=5672
EOF

/etc/init.d/rabbitmq-server restart
