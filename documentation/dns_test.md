# DNS Test

The DNS resolution test script checks if a hostname resolves to the expected IP address. It works on both Linux/macOS and Windows.

## Usage

```
GET /backup-validator/dns_test?hostname=example.com&expected-ip=93.184.216.34&dns-server=8.8.8.8
```

Parameters:
- `hostname` (required): The hostname to resolve
- `expected-ip` (required): The expected IP address
- `dns-server` (optional): The DNS server to use for resolution (defaults to system DNS)

## Response Examples

Success:
```json
{
  "status": "success",
  "message": "Testing DNS resolution for example.com (expected: 93.184.216.34)\nResolved IP: 93.184.216.34\nSuccess: example.com resolved to expected IP 93.184.216.34"
}
```

Error (IP mismatch):
```json
{
  "status": "error",
  "message": "Testing DNS resolution for example.com (expected: 1.2.3.4)\nResolved IP: 93.184.216.34\nError: example.com resolved to 93.184.216.34 (expected: 1.2.3.4)"
}
```

Error (hostname doesn't exist):
```json
{
  "status": "error",
  "message": "Testing DNS resolution for nonexistent.example.com (expected: 1.2.3.4)\nError: Could not resolve nonexistent.example.com"
}
``` 