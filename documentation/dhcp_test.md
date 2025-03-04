# DHCP Test

The DHCP test script checks if DHCP is working properly on a specified network interface. This script is available for Linux systems.

**Note:** This script requires sudo privileges to interact with network interfaces and DHCP clients. See the [Sudo Configuration](sudo_configuration.md) section for setup instructions.

## Usage

```
GET /backup-validator/dhcp_test?interface=eth0&timeout=30&expected-subnet=192.168.1.0/24
```

Parameters:
- `interface` (required): The network interface to test (e.g., eth0, wlan0)
- `timeout` (optional): The timeout in seconds for DHCP request (default: 30)
- `expected-subnet` (optional): The expected subnet for the assigned IP. Supports:
  - CIDR notation (e.g., `192.168.1.0/24`)
  - Simple prefix (e.g., `192.168.1`) for backward compatibility

## Subnet Validation

The script includes sophisticated subnet validation that can handle different notations:

1. **CIDR Notation**: Specify a subnet using standard CIDR notation (e.g., `192.168.1.0/24`, `10.0.0.0/16`).

2. **Simple Prefix**: The script maintains backward compatibility by supporting simple prefix notation (e.g., `192.168.1`).

The subnet validation uses the following methods, in order of preference:
1. `ipcalc` (if available on the system)
   - Supports both GNU ipcalc (with `-c` option) and BSD ipcalc (with `-n` option)
2. `sipcalc` (if available on the system)
3. Built-in bash calculation (as a fallback method)

## Cleanup and State Restoration

The script includes proper cleanup to ensure the network interface is returned to its previous state:

1. **Cleanup on Error**: If an error occurs (such as subnet validation failure), the script releases the DHCP lease before exiting.

2. **Cleanup after Test**: At the end of a successful test, the script:
   - Releases the DHCP lease obtained during testing
   - Attempts to restore the original IP configuration if an initial IP was present

This ensures the test doesn't leave the interface in an unexpected state and minimizes disruption to the system's networking.

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Testing DHCP on interface eth0 (timeout: 30s)\nInitial IP address: 192.168.1.100\nResetting interface eth0...\nReleasing DHCP lease...\nRequesting a new DHCP lease (timeout: 30s)...\nNew IP address: 192.168.1.120\nIP address is within expected subnet 192.168.1.0/24\nDefault gateway: 192.168.1.1\nTesting connectivity to gateway...\nSuccessfully pinged gateway\nDNS servers:\n8.8.8.8\n8.8.4.4\nTesting internet connectivity...\nInternet connectivity: OK\nTesting DNS resolution...\nDNS resolution: OK\nDHCP test completed successfully\nReleasing DHCP lease at end of test...\nRequesting restoration of original IP configuration..."
}
```

Error (DHCP failure):
```json
{
  "status": "error",
  "message": "Testing DHCP on interface eth0 (timeout: 30s)\nNo initial IP address assigned\nResetting interface eth0...\nRequesting a new DHCP lease (timeout: 30s)...\nError: Failed to obtain DHCP lease"
}
```

Error (wrong subnet):
```json
{
  "status": "error",
  "message": "Testing DHCP on interface eth0 (timeout: 30s)\nInitial IP address: 192.168.1.100\nResetting interface eth0...\nReleasing DHCP lease...\nRequesting a new DHCP lease (timeout: 30s)...\nNew IP address: 192.168.2.120\nError: IP address 192.168.2.120 is not in the expected subnet 192.168.1.0/24\nReleasing DHCP lease before exit..."
}
``` 