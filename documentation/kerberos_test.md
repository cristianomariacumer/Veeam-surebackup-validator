# Kerberos Test

The Kerberos authentication test script verifies if provided credentials can be used to obtain a valid Kerberos ticket. This script is available for Linux systems with Kerberos client tools installed.

**Note:** This script requires the Kerberos client tools (kinit, klist, etc.) to be installed on the system.

## Usage

```
GET /backup-validator/kerberos_test?username=user&password=pass&realm=EXAMPLE.COM&kdc=kdc.example.com&test-service=host/server.example.com
```

Parameters:
- `username` (required*): The Kerberos principal name (user)
- `password` (required*): The password for the principal
- `realm` (required): The Kerberos realm (usually uppercase, e.g., EXAMPLE.COM)
- `kdc` (optional): The Key Distribution Center server (if different from the default)
- `keytab` (optional*): Path to a keytab file (alternative to username/password)
- `test-service` (optional): A service principal to test obtaining a service ticket

*Either username+password OR keytab must be provided

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Testing Kerberos authentication for realm: EXAMPLE.COM\nAuthenticating with username: user\nSuccessfully obtained Kerberos ticket\nTicket information:\nTicket cache: FILE:/tmp/krb5cc_1000\nDefault principal: user@EXAMPLE.COM\n\nValid starting       Expires              Service principal\n05/15/2023 10:00:00  05/15/2023 20:00:00  krbtgt/EXAMPLE.COM@EXAMPLE.COM\nKerberos test completed successfully"
}
```

Error (authentication failure):
```json
{
  "status": "error",
  "message": "Testing Kerberos authentication for realm: EXAMPLE.COM\nAuthenticating with username: user\nError: Failed to authenticate with Kerberos"
}
```

Error (missing Kerberos tools):
```json
{
  "status": "error",
  "message": "Error: 'kinit' command not found. Please install Kerberos client tools.\n  For Debian/Ubuntu: apt-get install krb5-user\n  For RedHat/CentOS: yum install krb5-workstation"
}
``` 