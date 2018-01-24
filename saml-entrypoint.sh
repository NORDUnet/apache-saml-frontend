#!/bin/sh
set -e

# Pre-flight

if [ -z "$SP_HOSTNAME" ]; then
  echo "No SP_HOSTNAME environment variable set"
  exit 1
elif [ -z "$APPSERVERS" ]; then
  echo "No APPSERVERS environment variable set"
  exit 1
fi


# fallback to snakeoil
CERT_DIR=/opt/data/certs
if [ -z "$SSL_KEY"] || [ -z "$SSL_CERT" ]; then
  if [ -f ${CERT_DIR}/${SP_HOSTNAME}.crt ] && [ -f ${CERT_DIR}/${SP_HOSTNAME}.key ]; then
    SSL_CERT="${CERT_DIR}/${SP_HOSTNAME}.crt"
    SSL_KEY="${CERT_DIR}/${SP_HOSTNAME}.key"
  else
    SSL_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
    SSL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"
  fi
fi

# Check for sp cert
if [ -z "$SP_KEY" ] || [ -z "$SP_CERT" ]; then
  SP_CERT="${CERT_DIR}/sp.crt"
  SP_KEY="${CERT_DIR}/sp.key"
  if [ ! -f ${CERT_DIR}/sp.crt ] || [ ! -f ${CERT_DIR}/sp.key ]; then
    mkdir -p ${CERT_DIR}
    # gennerate new ssl certs
    openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:4096 -keyout ${CERT_DIR}/sp.key -out ${CERT_DIR}/sp.crt -subj "/C=DK/ST=/L=/O=/CN=${SP_HOSTNAME}"
  fi
fi

# config magic
SAML_CONF=/etc/apache2/sites-available/saml.conf
SP_LOCATION=${SP_LOCATION:-/}  # Default location /
# Remove trailing slash. Even if it is default
SP_LOCATION=$(echo "$SP_LOCATION" | sed 's|/$||') 
sed -e "s/__SERVER_NAME__/$SP_HOSTNAME/" \
    -e "s|__SSL_KEY__|$SSL_KEY|" \
    -e "s|__SSL_CERT__|$SSL_CERT|" \
    -e "s|__SP_KEY__|$SP_KEY|" \
    -e "s|__SP_CERT__|$SP_CERT|" \
    -e "s|__LOCATION__|$SP_LOCATION|" \
    /opt/templates/saml.conf.tmpl > $SAML_CONF

sed -i -e "/<Proxy balancer:/a BalancerMember http://$APPSERVERS" $SAML_CONF


if [ -n "$DISABLE_SUBJECT_CONFIRMATION" ]; then
  sed -i -e "/MellonSPCertFile/a MellonSubjectConfirmationDataAddressCheck Off" $SAML_CONF
fi

# Handle idp metadata
if [ -d /opt/data/metadata ]; then
  for sp_file in /opt/data/metadata/*.xml; do
    if [ -f ${sp_file}.crt ]; then
      sp_valid=${sp_file}.crt
    else
      sp_valid=""
    fi
    sed -i -e "/# Metadata conf/a MellonIdPMetadataFile $sp_file $sp_valid" $SAML_CONF
  done
else
  # default to ndn idp
  idp_metadata=${IDP_METADATA_URL:-https://idp.nordu.net/idp/shibboleth}
  wget -O "/opt/idp.nordu.net.xml" "$idp_metadata"
  sed -i -e "/# Metadata conf/a MellonIdPMetadataFile /opt/idp.nordu.net.xml" $SAML_CONF
fi

if [ -n "$SP_DISCOVERY_URL" ]; then
  sed -i -e "/# Metadata conf/a MellonDiscoveryURL \"$SP_DISCOVERY_URL\"" $SAML_CONF
fi

# Remote user name
if [ -z "$REMOTE_USER_VAR" ]; then
  REMOTE_USER_VAR="EPPN"
fi
if [ -z "$REMOTE_USER_NAME" ]; then
  REMOTE_USER_NAME="REMOTE_USER"
fi
sed -i -e "s/__REMOTE_USER_NAME__/$REMOTE_USER_NAME/g" -e "s/__REMOTE_USER_VAR__/$REMOTE_USER_VAR/g" $SAML_CONF

# Header prefix
sed -i -e "s/__HEADER_PREFIX__/$HEADER_PREFIX/g" $SAML_CONF

# Add custom mellon.conf 
if [ -f /opt/data/mellon.conf ]; then
  sed -i -e '/# Mellon conf/r /opt/data/mellon.conf' $SAML_CONF
fi

# enable saml config
a2ensite saml

# Fix logging
if [ -z "$ACCESS_LOG_OFF" ]; then
  sed -ri -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' "/etc/apache2/apache2.conf"
fi

sed -ri -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' "/etc/apache2/apache2.conf"

# Remove pid file
rm -f /var/run/apache2/apache2.pid

/usr/sbin/apache2ctl -D FOREGROUND
