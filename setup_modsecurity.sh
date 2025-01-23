#!/bin/bash

# Define colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${BLUE}Starting ModSecurity and Nginx setup...${NC}"

# Update and install dependencies
echo -e "${YELLOW}Installing required dependencies...${NC}"
apt-get update
apt-get install -y libtool autoconf build-essential libpcre3-dev zlib1g-dev libssl-dev \
libxml2-dev libgeoip-dev liblmdb-dev libyajl-dev libcurl4-openssl-dev pkgconf libxslt1-dev \
libgd-dev automake

# Install ModSecurity
echo -e "${YELLOW}Cloning and building ModSecurity...${NC}"
cd /usr/local/src || exit
git clone --depth 100 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
cd ModSecurity || exit
git submodule init
git submodule update
sh build.sh
./configure
make
make install

# Get the Nginx version
NGINX_VERSION=$(nginx -v 2>&1 | grep -oP "(?<=nginx/)[0-9.]+")
if [ -z "$NGINX_VERSION" ]; then
    echo -e "${RED}Failed to detect Nginx version. Please ensure Nginx is installed.${NC}"
    exit 1
fi
echo -e "${GREEN}Detected Nginx version: $NGINX_VERSION${NC}"

# Set up directories for compilation
echo -e "${YELLOW}Setting up directories for Nginx module compilation...${NC}"
mkdir -p /usr/local/src/cpg
cd /usr/local/src/cpg || exit

# Download and extract Nginx source code
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar -xvzf nginx-$NGINX_VERSION.tar.gz

# Clone ModSecurity-nginx
git clone https://github.com/SpiderLabs/ModSecurity-nginx

# Compile the ModSecurity-nginx module
echo -e "${YELLOW}Compiling ModSecurity-nginx module...${NC}"
cd nginx-$NGINX_VERSION || exit
./configure --with-compat --add-dynamic-module=/usr/local/src/cpg/ModSecurity-nginx
make modules
cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Configure Nginx to load the ModSecurity module
echo -e "${YELLOW}Configuring Nginx to load ModSecurity module...${NC}"
cat <<EOF > /etc/nginx/modules-enabled/50-mod-http-modsecurity.conf
load_module modules/ngx_http_modsecurity_module.so;
EOF

# Configure Nginx to include WAF configurations after "include /etc/nginx/sites-enabled/*.conf"
echo -e "${YELLOW}Adding WAF configuration include to nginx.conf...${NC}"
sed -i '/include \/etc\/nginx\/sites-enabled\/\*\.conf;/a include /etc/nginx/cpguard_waf_load.conf;' /etc/nginx/nginx.conf

# Create WAF configuration files
echo -e "${YELLOW}Creating WAF configuration files...${NC}"
cat <<EOF > /etc/nginx/cpguard_waf_load.conf
modsecurity on;
modsecurity_rules_file /etc/nginx/nginx-modsecurity.conf;
EOF

cat <<EOF > /etc/nginx/nginx-modsecurity.conf
SecRuleEngine On
SecRequestBodyAccess On
SecDefaultAction "phase:2,deny,log,status:406"
SecRequestBodyLimitAction ProcessPartial
SecResponseBodyLimitAction ProcessPartial
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecPcreMatchLimit 250000
SecPcreMatchLimitRecursion 250000
SecCollectionTimeout 600
SecDebugLog /var/log/nginx/modsec_debug.log
SecDebugLogLevel 0
SecAuditEngine RelevantOnly
SecAuditLog /var/log/nginx/modsec_audit.log
SecUploadDir /tmp
SecTmpDir /tmp
SecDataDir /tmp
SecTmpSaveUploadedFiles on
# Include file for cPGuard WAF
Include /etc/nginx/cpguard_waf.conf
EOF

# Create an empty WAF rules file
touch /etc/nginx/cpguard_waf.conf

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}Nginx configuration is valid. Restarting Nginx...${NC}"
    systemctl restart nginx
    echo -e "${GREEN}ModSecurity and Nginx setup completed successfully.${NC}"
else
    echo -e "${RED}Nginx configuration test failed. Please check the configuration files.${NC}"
    exit 1
fi
