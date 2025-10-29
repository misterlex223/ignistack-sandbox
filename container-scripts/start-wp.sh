#!/bin/bash

# Script to start WordPress server
cd /home/flexy/wordpress
php -S 0.0.0.0:80 > /home/flexy/wordpress.log 2>&1 &
echo "WordPress server started on port 80"