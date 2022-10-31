#!/bin/bash

# partially lifted from https://medium.com/@adamneilson/automating-lets-encrypt-certificate-renewal-baed06493d3f
# thank you, kind internet stranger!
# modified from this earlier project https://raw.githubusercontent.com/adamphetamine/letsencrypt-security-onion/main/le-renew.sh

# debug - comment out this when working
# set -x 

# our variables are in this file
source /usr/local/sbin/lego/custom.env

TIMESTAMP=$(date +"%F %T")
UPDATED=0

# debugging time- uncomment these if you want to check your variables are correct
# echo $CLOUDFLARE_EMAIL
# echo $CLOUDFLARE_API_TOKEN
# echo $DOMAIN_NAME

# UTIL FUNCTION TO LOG ACTIVITY
function log_msg {
    echo "["$TIMESTAMP"] $1" >> $LOG_FILE
}

# set log file location
LOG_FILE="/var/log/letsencrypt/ssl-renewals.log"

# Let's get the certs
echo "Renewing SSL Certificates with Let's Encrypt CA"
# lego binary is in /usr/sbin/lego
cd /usr/sbin/

# set token  variable
CLOUDFLARE_DNS_API_TOKEN=$CLOUDFLARE_API_TOKEN \
lego --email $CLOUDFLARE_EMAIL \
 --dns cloudflare \
--domains $DOMAIN_NAME run \ 
--run-hook "./move-certs.sh"

echo "all done. exiting"
