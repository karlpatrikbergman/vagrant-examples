#!/bin/bash - 

set -e

#!/usr/bin/env bash

sudo yum clean all
sudo yum -y update


# For local ip network testing. Simple web page on port 80
sudo yum -y install httpd
sudo systemctl start httpd

# Fix problem with lost fixed ip address
# https://github.com/mitchellh/vagrant/issues/6235
sudo nmcli connection reload
sudo systemctl restart network.service

