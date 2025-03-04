# Sudo Configuration

Some scripts (such as the DHCP test) require root privileges to function correctly. Since the service runs as the unprivileged user `validator`, sudo rules are needed to allow specific privileged operations.

## Setting up sudo for DHCP Testing

1. Make the setup script executable:
   ```
   chmod +x setup-dhcp-sudo.sh
   ```

2. Run the setup script as root:
   ```
   sudo ./setup-dhcp-sudo.sh
   ```

This will:
- Create a sudoers configuration file at `/etc/sudoers.d/validator-dhcp`
- Configure necessary permissions for the `validator` user to run the required network commands
- Verify the syntax of the sudoers file to prevent system issues
- Check and warn about path inconsistencies that might need manual adjustment

The configuration allows the validator user to run only the specific commands needed for DHCP testing without a password, following the principle of least privilege.

## Sudoers Configuration Details

The configuration defines command aliases for various categories of operations:

```
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
```

These are then granted to the validator user:

```
validator ALL=(ALL) NOPASSWD: NETWORK_COMMANDS, DHCP_COMMANDS, DNS_COMMANDS, TIMEOUT_COMMAND
```

## Security Considerations

- The sudo configuration follows the principle of least privilege, granting only the specific permissions needed
- If you modify any of the test scripts to use additional commands, you'll need to update the sudoers file accordingly
- Always verify the syntax of sudoers files using `visudo -c` before applying them
- Path validation is important to ensure the commands referenced in the sudoers file match the system paths 