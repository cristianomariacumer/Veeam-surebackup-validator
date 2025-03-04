# DHCP Test

The DHCP test script checks if DHCP is working properly on a specified network interface. This script is available for Linux systems.

**Note:** This script requires sudo privileges to interact with network interfaces and DHCP clients. See the [Sudo Configuration](sudo_configuration.md) section for setup instructions.

## Usage

```
GET /backup-validator/dhcp_test?interface=eth0&timeout=30&expected-subnet=192.168.1
```

Parameters:
- `interface` (required): The network interface to test (e.g., eth0, wlan0)
- `timeout` (optional): The timeout in seconds for DHCP request (default: 30)
- `expected-subnet` (optional): The expected subnet prefix for the assigned IP (e.g., 192.168.1)

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Testing DHCP on interface eth0 (timeout: 30s)\nInitial IP address: 192.168.1.100\nResetting interface eth0...\nReleasing DHCP lease...\nRequesting a new DHCP lease (timeout: 30s)...\nNew IP address: 192.168.1.120\nIP address is within expected subnet 192.168.1\nDefault gateway: 192.168.1.1\nTesting connectivity to gateway...\nSuccessfully pinged gateway\nDNS servers:\n8.8.8.8\n8.8.4.4\nTesting internet connectivity...\nInternet connectivity: OK\nTesting DNS resolution...\nDNS resolution: OK\nDHCP test completed successfully"
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
  "message": "Testing DHCP on interface eth0 (timeout: 30s)\nInitial IP address: 192.168.1.100\nResetting interface eth0...\nReleasing DHCP lease...\nRequesting a new DHCP lease (timeout: 30s)...\nNew IP address: 192.168.2.120\nError: IP address 192.168.2.120 is not in the expected subnet 192.168.1"
}
``` 