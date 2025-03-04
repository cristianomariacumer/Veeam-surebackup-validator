#!/bin/bash
# Installation script for Backup Validator service

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Define variables
INSTALL_DIR="/opt/backup-validator"
SERVICE_NAME="backup-validator"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Backup Validator service..."

# Create installation directory
echo "Creating installation directory at $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/scripts"

# Copy application files
echo "Copying application files..."
cp -R "$CURRENT_DIR/"*.py "$INSTALL_DIR/"
cp -R "$CURRENT_DIR/requirements.txt" "$INSTALL_DIR/"
cp -R "$CURRENT_DIR/scripts/"* "$INSTALL_DIR/scripts/"

# Set proper permissions
echo "Setting permissions..."
chmod -R 755 "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR/scripts/"*

# Check if python3-venv is installed
if ! dpkg -l | grep -q python3-venv && command -v apt-get >/dev/null 2>&1; then
    echo "Installing python3-venv package..."
    apt-get update
    apt-get install -y python3-venv
elif ! command -v python3 -m venv >/dev/null 2>&1; then
    echo "Warning: python3-venv not found. Please install it manually."
    echo "For Debian/Ubuntu: apt-get install python3-venv"
    echo "For RedHat/CentOS: yum install python3-virtualenv"
fi

# Create and set up virtual environment
echo "Creating Python virtual environment..."
python3 -m venv "$INSTALL_DIR/venv"

# Install dependencies in the virtual environment
echo "Installing Python dependencies in virtual environment..."
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"
echo "Installing Gunicorn WSGI server..."
"$INSTALL_DIR/venv/bin/pip" install gunicorn

# Create a user for the service if it doesn't exist
if ! id -u validator >/dev/null 2>&1; then
    echo "Creating service user 'validator'..."
    useradd -r -d "$INSTALL_DIR" -s /bin/false validator
fi

# Set proper ownership
echo "Setting ownership..."
chown -R validator:validator "$INSTALL_DIR"

# Copy service file
echo "Installing systemd service..."
cp "$CURRENT_DIR/backup-validator.service" /etc/systemd/system/

# Configure sudo permissions for DHCP testing
echo "Setting up sudo permissions for DHCP testing..."

# Create sudoers file
SUDOERS_FILE="/etc/sudoers.d/validator-dhcp"
cat > "$SUDOERS_FILE" << 'EOF'
# Allow validator user to run network commands required for DHCP testing without a password

# Command aliases for network operations
Cmnd_Alias NETWORK_COMMANDS = \
    /sbin/ip link show *, \
    /sbin/ip -4 addr show dev *, \
    /sbin/ip link set * down, \
    /sbin/ip link set * up, \
    /sbin/ip route, \
    /usr/bin/ping -c * -W * *

# Command aliases for DHCP operations
Cmnd_Alias DHCP_COMMANDS = \
    /sbin/dhclient -r *, \
    /sbin/dhclient -v *, \
    /usr/sbin/dhclient -r *, \
    /usr/sbin/dhclient -v *, \
    /sbin/dhcpcd -k *, \
    /sbin/dhcpcd -t * *, \
    /usr/sbin/dhcpcd -k *, \
    /usr/sbin/dhcpcd -t * *

# Command aliases for DNS operations
Cmnd_Alias DNS_COMMANDS = \
    /usr/bin/host *, \
    /usr/bin/cat /etc/resolv.conf

# Command alias for timeout
Cmnd_Alias TIMEOUT_COMMAND = \
    /usr/bin/timeout * * *

# Grant validator user permission to run the commands without a password
validator ALL=(ALL) NOPASSWD: NETWORK_COMMANDS, DHCP_COMMANDS, DNS_COMMANDS, TIMEOUT_COMMAND
EOF

# Set proper permissions for sudoers file
chmod 440 "$SUDOERS_FILE"

# Verify sudoers syntax
if command -v visudo &>/dev/null; then
    if ! visudo -c -f "$SUDOERS_FILE"; then
        echo "Error: Syntax error in sudoers file. Removing file to prevent system issues."
        rm -f "$SUDOERS_FILE"
        echo "Warning: DHCP testing will not work without sudo permissions."
    else
        echo "Sudo permissions set up successfully."
    fi
fi

# Reload systemd configuration
echo "Reloading systemd configuration..."
systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting service..."
systemctl enable "$SERVICE_NAME.service"
systemctl start "$SERVICE_NAME.service"

# Check service status
echo "Checking service status..."
systemctl status "$SERVICE_NAME.service"

echo ""
echo "Installation complete! The Backup Validator service is now running."
echo ""
echo "You can manage the service with the following commands:"
echo "  systemctl status $SERVICE_NAME"
echo "  systemctl start $SERVICE_NAME"
echo "  systemctl stop $SERVICE_NAME"
echo "  systemctl restart $SERVICE_NAME"
echo ""
echo "Service logs can be viewed with:"
echo "  journalctl -u $SERVICE_NAME -f"
echo ""
echo "The API should be accessible at: http://localhost:5000" 