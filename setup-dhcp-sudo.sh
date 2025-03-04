#!/bin/bash
# Script to set up sudo privileges for the validator user to run DHCP test commands

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Define variables
SUDOERS_FILE="/etc/sudoers.d/validator-dhcp"
VALIDATOR_USER="validator"

# Ensure validator user exists
if ! id -u "$VALIDATOR_USER" &>/dev/null; then
  echo "Error: User '$VALIDATOR_USER' does not exist. Please create the user first." >&2
  exit 1
fi

# Create sudoers file
echo "Creating sudoers file for $VALIDATOR_USER..."
cat > "$SUDOERS_FILE" << 'EOF'
# Allow validator user to run network commands required for DHCP testing without a password
# Created by setup script $(date)

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

# Set proper permissions
chmod 440 "$SUDOERS_FILE"

# Verify sudoers syntax
if command -v visudo &>/dev/null; then
  if ! visudo -c -f "$SUDOERS_FILE"; then
    echo "Error: Syntax error in sudoers file. Removing file to prevent system issues." >&2
    rm -f "$SUDOERS_FILE"
    exit 1
  fi
fi

echo "Sudo privileges set up successfully for $VALIDATOR_USER."
echo "The DHCP test script can now be run without requiring root privileges."

# Check for common path issues
echo "Checking for command paths..."
for cmd in ip dhclient dhcpcd ping host timeout; do
  if ! which "$cmd" &>/dev/null; then
    echo "Warning: Command '$cmd' not found. You may need to adjust the paths in $SUDOERS_FILE."
  else
    path=$(which "$cmd")
    echo "Found $cmd at $path"
    if ! grep -q "$path" "$SUDOERS_FILE"; then
      echo "Warning: Path for $cmd in sudoers file may need to be updated to $path"
    fi
  fi
done

echo ""
echo "Note: If any path warnings were shown above, please edit $SUDOERS_FILE"
echo "to use the correct paths for your system."

exit 0 