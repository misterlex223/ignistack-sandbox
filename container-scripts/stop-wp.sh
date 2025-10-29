#!/bin/bash

# Script to stop WordPress server
pkill -f "php -S 0.0.0.0:80"
echo "WordPress server stopped"