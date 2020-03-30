#!/usr/bin/env bash

## Enable SSH manual
#mv /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
#sed -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.orig > /etc/ssh/sshd_config
#service sshd restart

echo "Done"
