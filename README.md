# ModSecurity Setup Script

This script automates the installation and configuration of ModSecurity with Nginx.

Reference : https://opsshield.com/help/cpguard/install-modsecurity-with-nginx-on-debian-ubuntu/

## Usage

1. Download the script:
   ```bash
   wget https://raw.githubusercontent.com/donnebanget/modsecurity-setup/main/setup_modsecurity.sh

2. Make it executable:
   ```bash
   chmod +x setup_modsecurity.sh
4. Run the script:
   ```bash
   sudo ./setup_modsecurity.sh

**Features**
- Installs ModSecurity from source.
- Configures ModSecurity-nginx connector.
- Sets up Nginx for WAF (Web Application Firewall).
- Validates Nginx configuration before restarting.

**Notes**

Ensure you have Nginx installed before running the script.

