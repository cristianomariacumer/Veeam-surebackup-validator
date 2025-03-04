# LDAPS Test

The LDAPS (LDAP over SSL) test script checks connectivity to a domain controller or LDAP server. This script is available for Linux systems with OpenLDAP client tools installed.

**Note:** This script requires the OpenLDAP client tools (`ldapsearch`) to be installed on the system.

## Usage

```
GET /backup-validator/ldaps_test?server=ldap.example.com&base-dn=dc=example,dc=com&username=cn=admin,dc=example,dc=com&password=secret
```

Parameters:
- `server` (required): The LDAP server hostname or IP address
- `base-dn` (required): Base DN for search (e.g., dc=example,dc=com)
- `port` (optional): LDAPS port (default: 636)
- `username` (optional): Bind DN for authentication
- `password` (optional): Password for authentication
- `search-filter` (optional): LDAP search filter (default: (objectClass=*))
- `attrs` (optional): Comma-separated list of attributes to return (default: dn)
- `timeout` (optional): Connection timeout in seconds (default: 10)
- `verify-cert` (optional): Whether to verify SSL certificate (default: true)

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Testing LDAPS connectivity to ldap.example.com:636\nBase DN: dc=example,dc=com\nUsing authentication with username: cn=admin,dc=example,dc=com\nCertificate verification enabled\nTesting LDAPS connection...\nChecking certificate expiration...\nnotBefore=Jan  1 00:00:00 2023 GMT\nnotAfter=Dec 31 23:59:59 2023 GMT\nCurrent date: Thu Jun 1 12:34:56 UTC 2023\nCertificate is valid. Days until expiration: 213\nExecuting LDAP search with filter: (objectClass=*)\nSuccessfully connected and searched the directory.\nFound 5 entries.\nSample result:\ndn: dc=example,dc=com\nobjectClass: dcObject\nobjectClass: organization\n\nLDAPS test completed successfully."
}
```

Error (connection failure):
```json
{
  "status": "error",
  "message": "Testing LDAPS connectivity to nonexistent.example.com:636\nBase DN: dc=example,dc=com\nUsing anonymous bind\nCertificate verification enabled\nTesting LDAPS connection...\nError: Failed to establish SSL connection to nonexistent.example.com:636\nconnect:errno=111"
}
```

Error (authentication failure):
```json
{
  "status": "error",
  "message": "Testing LDAPS connectivity to ldap.example.com:636\nBase DN: dc=example,dc=com\nUsing authentication with username: cn=admin,dc=example,dc=com\nCertificate verification enabled\nTesting LDAPS connection...\nChecking certificate expiration...\nnotBefore=Jan  1 00:00:00 2023 GMT\nnotAfter=Dec 31 23:59:59 2023 GMT\nCurrent date: Thu Jun 1 12:34:56 UTC 2023\nCertificate is valid. Days until expiration: 213\nExecuting LDAP search with filter: (objectClass=*)\nError: LDAP search failed with status code 49\nAuthentication failed. Please check username and password."
}
```

Error (certificate validation):
```json
{
  "status": "error",
  "message": "Testing LDAPS connectivity to ldap.example.com:636\nBase DN: dc=example,dc=com\nUsing anonymous bind\nCertificate verification enabled\nTesting LDAPS connection...\nChecking certificate expiration...\nError: Certificate has expired!"
}
``` 