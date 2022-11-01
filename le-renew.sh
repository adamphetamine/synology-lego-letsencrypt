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

# but here's how the Pros do it-

#!/usr/bin/env sh

# Here is a script to deploy cert to Synology DSM
#
# It requires following environment variables:
#
# SYNO_Username - Synology Username to login (must be an administrator)
# SYNO_Password - Synology Password to login
# SYNO_Certificate - Certificate description to target for replacement
#
# The following environmental variables may be set if you don't like their
# default values:
#
# SYNO_Scheme - defaults to http
# SYNO_Hostname - defaults to localhost
# SYNO_Port - defaults to 5000
# SYNO_DID - device ID to skip OTP - defaults to empty
# SYNO_TOTP_SECRET - TOTP secret to generate OTP - defaults to empty
#
# Dependencies:
# -------------
# - jq and curl
# - oathtool (When using 2 Factor Authentication and SYNO_TOTP_SECRET is set)
#
#returns 0 means success, otherwise error.

########  Public functions #####################

#domain keyfile certfile cafile fullchain
synology_dsm_deploy() {

  _cdomain="$1"
  _ckey="$2"
  _ccert="$3"
  _cca="$4"

  _debug _cdomain "$_cdomain"

  # Get Username and Password, but don't save until we successfully authenticate
  _getdeployconf SYNO_Username
  _getdeployconf SYNO_Password
  _getdeployconf SYNO_Create
  _getdeployconf SYNO_DID
  _getdeployconf SYNO_TOTP_SECRET
  if [ -z "${SYNO_Username:-}" ] || [ -z "${SYNO_Password:-}" ]; then
    _err "SYNO_Username & SYNO_Password must be set"
    return 1
  fi
  _debug2 SYNO_Username "$SYNO_Username"
  _secure_debug2 SYNO_Password "$SYNO_Password"

  # Optional scheme, hostname, and port for Synology DSM
  _getdeployconf SYNO_Scheme
  _getdeployconf SYNO_Hostname
  _getdeployconf SYNO_Port

  # default vaules for scheme, hostname, and port
  # defaulting to localhost and http because it's localhost...
  [ -n "${SYNO_Scheme}" ] || SYNO_Scheme="http"
  [ -n "${SYNO_Hostname}" ] || SYNO_Hostname="localhost"
  [ -n "${SYNO_Port}" ] || SYNO_Port="5000"

  _savedeployconf SYNO_Scheme "$SYNO_Scheme"
  _savedeployconf SYNO_Hostname "$SYNO_Hostname"
  _savedeployconf SYNO_Port "$SYNO_Port"

  _debug2 SYNO_Scheme "$SYNO_Scheme"
  _debug2 SYNO_Hostname "$SYNO_Hostname"
  _debug2 SYNO_Port "$SYNO_Port"

  # Get the certificate description, but don't save it until we verfiy it's real
  _getdeployconf SYNO_Certificate
  _debug SYNO_Certificate "${SYNO_Certificate:-}"

  # shellcheck disable=SC1003 # We are not trying to escape a single quote
  if printf "%s" "$SYNO_Certificate" | grep '\\'; then
    _err "Do not use a backslash (\) in your certificate description"
    return 1
  fi

  _base_url="$SYNO_Scheme://$SYNO_Hostname:$SYNO_Port"
  _debug _base_url "$_base_url"

  _debug "Getting API version"
  response=$(_get "$_base_url/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=SYNO.API.Auth")
  api_version=$(echo "$response" | grep "SYNO.API.Auth" | sed -n 's/.*"maxVersion" *: *\([0-9]*\).*/\1/p')
  _debug3 response "$response"
  _debug3 api_version "$api_version"

  # Login, get the token from JSON and session id from cookie
  _info "Logging into $SYNO_Hostname:$SYNO_Port"
  encoded_username="$(printf "%s" "$SYNO_Username" | _url_encode)"
  encoded_password="$(printf "%s" "$SYNO_Password" | _url_encode)"

  otp_code=""
  if [ -n "$SYNO_TOTP_SECRET" ]; then
    if _exists oathtool; then
      otp_code="$(oathtool --base32 --totp "${SYNO_TOTP_SECRET}" 2>/dev/null)"
    else
      _err "oathtool could not be found, install oathtool to use SYNO_TOTP_SECRET"
      return 1
    fi
  fi

  if [ -n "$SYNO_DID" ]; then
    _H1="Cookie: did=$SYNO_DID"
    export _H1
    _debug3 H1 "${_H1}"
  fi

  response=$(_post "method=login&account=$encoded_username&passwd=$encoded_password&api=SYNO.API.Auth&version=$api_version&enable_syno_token=yes&otp_code=$otp_code&device_name=certrenewal&device_id=$SYNO_DID" "$_base_url/webapi/auth.cgi?enable_syno_token=yes")
  token=$(echo "$response" | grep "synotoken" | sed -n 's/.*"synotoken" *: *"\([^"]*\).*/\1/p')
  _debug3 response "$response"
  _debug token "$token"

  if [ -z "$token" ]; then
    _err "Unable to authenticate to $SYNO_Hostname:$SYNO_Port using $SYNO_Scheme."
    _err "Check your username and password."
    _err "If two-factor authentication is enabled for the user, set SYNO_TOTP_SECRET."
    return 1
  fi
  sid=$(echo "$response" | grep "sid" | sed -n 's/.*"sid" *: *"\([^"]*\).*/\1/p')

  _H1="X-SYNO-TOKEN: $token"
  export _H1
  _debug2 H1 "${_H1}"

  # Now that we know the username and password are good, save them
  _savedeployconf SYNO_Username "$SYNO_Username"
  _savedeployconf SYNO_Password "$SYNO_Password"
  _savedeployconf SYNO_DID "$SYNO_DID"
  _savedeployconf SYNO_TOTP_SECRET "$SYNO_TOTP_SECRET"

  _info "Getting certificates in Synology DSM"
  response=$(_post "api=SYNO.Core.Certificate.CRT&method=list&version=1&_sid=$sid" "$_base_url/webapi/entry.cgi")
  _debug3 response "$response"
  escaped_certificate="$(printf "%s" "$SYNO_Certificate" | sed 's/\([].*^$[]\)/\\\1/g;s/"/\\\\"/g')"
  _debug escaped_certificate "$escaped_certificate"
  id=$(echo "$response" | sed -n "s/.*\"desc\":\"$escaped_certificate\",\"id\":\"\([^\"]*\).*/\1/p")
  _debug2 id "$id"

  if [ -z "$id" ] && [ -z "${SYNO_Create:-}" ]; then
    _err "Unable to find certificate: $SYNO_Certificate and \$SYNO_Create is not set"
    return 1
  fi

  # we've verified this certificate description is a thing, so save it
  _savedeployconf SYNO_Certificate "$SYNO_Certificate" "base64"

  _info "Generate form POST request"
  nl="\0015\0012"
  delim="--------------------------$(_utc_date | tr -d -- '-: ')"
  content="--$delim${nl}Content-Disposition: form-data; name=\"key\"; filename=\"$(basename "$_ckey")\"${nl}Content-Type: application/octet-stream${nl}${nl}$(cat "$_ckey")\0012"
  content="$content${nl}--$delim${nl}Content-Disposition: form-data; name=\"cert\"; filename=\"$(basename "$_ccert")\"${nl}Content-Type: application/octet-stream${nl}${nl}$(cat "$_ccert")\0012"
  content="$content${nl}--$delim${nl}Content-Disposition: form-data; name=\"inter_cert\"; filename=\"$(basename "$_cca")\"${nl}Content-Type: application/octet-stream${nl}${nl}$(cat "$_cca")\0012"
  content="$content${nl}--$delim${nl}Content-Disposition: form-data; name=\"id\"${nl}${nl}$id"
  content="$content${nl}--$delim${nl}Content-Disposition: form-data; name=\"desc\"${nl}${nl}${SYNO_Certificate}"
  if echo "$response" | sed -n "s/.*\"desc\":\"$escaped_certificate\",\([^{]*\).*/\1/p" | grep -- 'is_default":true' >/dev/null; then
    _debug2 default "this is the default certificate"
    content="$content${nl}--$delim${nl}Content-Disposition: form-data; name=\"as_default\"${nl}${nl}true"
  else
    _debug2 default "this is NOT the default certificate"
  fi
  content="$content${nl}--$delim--${nl}"
  content="$(printf "%b_" "$content")"
  content="${content%_}" # protect trailing \n

  _info "Upload certificate to the Synology DSM"
  response=$(_post "$content" "$_base_url/webapi/entry.cgi?api=SYNO.Core.Certificate&method=import&version=1&SynoToken=$token&_sid=$sid" "" "POST" "multipart/form-data; boundary=${delim}")
  _debug3 response "$response"

  if ! echo "$response" | grep '"error":' >/dev/null; then
    if echo "$response" | grep '"restart_httpd":true' >/dev/null; then
      _info "http services were restarted"
    else
      _info "http services were NOT restarted"
    fi
    return 0
  else
    _err "Unable to update certificate, error code $response"
    return 1
  fi
}

#!/bin/sh
#
# *** For DSM v6.x ***
#
# How to use this script:
#  1. Get your 3 PEM files ready to copy over from your local machine/update server (privkey.pem, fullchain.pem, cert.pem)
#     and put into a directory (this will be $CERT_DIRECTORY).
#  2. Ensure you have a user setup on synology that has ssh access (and ssh access is setup).
#     This user will need to be able to sudo as root (i.e. add this line to sudoers, <USER> is the user you create):
#       <USER> ALL=(ALL) NOPASSWD: /var/services/homes/<USER>/replace_certs.sh
#  3. Call this script as follows:
#     sudo scp ${CERT_DIRECTORY}/{privkey,fullchain,cert}.pem $USER@$SYNOLOGY_SERVER:/tmp/ \
#     && sudo scp replace_synology_ssl_certs.sh $USER@$SYNOLOGY_SERVER:~/ \
#     && ssh $USER@$SYNOLOGY_SERVER 'sudo ./replace_synology_ssl_certs.sh'

# Script start.

REVERSE_PROXY=/usr/syno/etc/certificate/ReverseProxy
FQDN_DIR=/usr/syno/etc/certificate/system/FQDN
DEFAULT_DIR=
DEFAULT_DIR_NAME=$(cat /usr/syno/etc/certificate/_archive/DEFAULT)
if [ "DEFAULT_DIR_NAME" != "" ]; then
	DEFAULT_DIR="/usr/syno/etc/certificate/_archive/${DEFAULT_DIR_NAME}"
fi

# Move certs from /tmp to install directory
mv /tmp/{privkey,fullchain,cert}.pem /usr/syno/etc/certificate/system/default/
if [ "$?" != 0 ]; then
	echo "Halting because of error moving files"
	exit 1
fi

# Ensure correct permissions
chown root:root /usr/syno/etc/certificate/system/default/{privkey,fullchain,cert}.pem
if [ "$?" != 0 ]; then
	echo "Halting because of error chowning files"
	exit 1
fi
echo "Certs moved from /tmp & chowned."

# If you're using a custom domain name, replace the FQDN certs too
if [ -d "${FQDN_DIR}/" ]; then
    echo "Found FQDN directory, copying certificates to 'certificate/system/FQDN' as well..."
    cp /usr/syno/etc/certificate/system/default/{privkey,fullchain,cert}.pem "${FQDN_DIR}/"
    chown root:root "${FQDN_DIR}/"{privkey,fullchain,cert}.pem
fi

# Replace certs for default Application Portal (if found)
if [ -d "$DEFAULT_DIR" ]; then
	echo "Found upload dir (used for Application Portal): $DEFAULT_DIR_NAME, copying certs to: $DEFAULT_DIR"
    cp /usr/syno/etc/certificate/system/default/{privkey,fullchain,cert}.pem "$DEFAULT_DIR/"
    chown root:root "$DEFAULT_DIR/"{privkey,fullchain,cert}.pem
else
	echo "Did not find upload dir (Application Portal): $DEFAULT_DIR_NAME"
fi

# Replace certs for all reverse proxy servers (if exists)
if [ -d "$REVERSE_PROXY" ]; then
	echo "Found reverse proxy certs, replacing those:"
	for proxy in $(ls "$REVERSE_PROXY"); do
		echo "Replacing $REVERSE_PROXY/$proxy"
		cp /usr/syno/etc/certificate/system/default/{privkey,fullchain,cert}.pem "$REVERSE_PROXY/$proxy"
		chown root:root "$REVERSE_PROXY/$proxy/"{privkey,fullchain,cert}.pem
	done
else
	echo "No reverse proxy directory found"
fi

# Reboot synology services
echo -n "Rebooting all the things..."
/usr/syno/sbin/synoservice --restart nginx
/usr/syno/sbin/synoservice --restart nmbd
/usr/syno/sbin/synoservice --restart avahi
/usr/syno/sbin/synoservice --reload ldap-server
echo " done"
