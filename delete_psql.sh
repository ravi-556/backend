#!/bin/bash

sudo systemctl stop postgresql

sudo systemctl disable postgresql

sudo yum remove postgresql postgresql-server postgresql16 postgresql16-server -y

sudo rm -rf /var/lib/pgsql
sudo rm -rf /var/lib/pgsql15
