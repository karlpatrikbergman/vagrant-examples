#!/bin/bash - 

set -e

#!/usr/bin/env bash

sudo yum clean all
sudo yum -y update
sudo yum -y install httpd

#sudo firewall-cmd --permanent --add-port=80/tcp
#sudo firewall-cmd --permanent --add-port=443/tcp
#sudo firewall-cmd --reload

sudo systemctl start httpd

# Fix problem with lost fixed ip address
# https://github.com/mitchellh/vagrant/issues/6235
sudo nmcli connection reload
sudo systemctl restart network.service

