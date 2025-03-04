# Backup Validator

A multi-OS tool built with Flask-RESTful that executes scripts on the host machine and returns their status via REST API calls.

## Features

- Works on both Linux and Windows platforms
- RESTful API for script execution
- Passes URL parameters to scripts
- Returns appropriate HTTP status codes:
  - 200 OK if the script exits successfully
  - 500 with error text if the script fails
  - 404 if the script is not found
- Path security validation to prevent directory traversal attacks
- Advanced logging with rotation using Loguru

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/backup-validator.git
   cd backup-validator
   ```

2. Create and activate a virtual environment (optional but recommended):
   
   **Linux/macOS:**
   ```
   python -m venv venv
   source venv/bin/activate
   ```
   
   **Windows:**
   ```
   python -m venv venv
   venv\Scripts\activate
   ```

3. Install required packages:
   ```
   pip install -r requirements.txt
   ```

### Installing as a System Service

On Linux systems using systemd (most modern distributions), you can install Backup Validator as a system service:

1. Make the installation script executable:
   ```
   chmod +x install-service.sh
   ```

2. Run the installation script as root:
   ```
   sudo ./install-service.sh
   ```

This will:
- Copy all necessary files to `/opt/backup-validator/`
- Create a Python virtual environment in `/opt/backup-validator/venv/`
- Install required Python dependencies in the virtual environment
- Install Gunicorn WSGI server for production deployment
- Create a service user named `validator`
- Create and enable a systemd service
- Start the service automatically

The systemd service is configured to use Gunicorn with the Python interpreter from the virtual environment, ensuring all dependencies are properly available and the application runs in a production-ready environment.

After installation, you can manage the service with standard systemd commands:
```
sudo systemctl status backup-validator
sudo systemctl start backup-validator
sudo systemctl stop backup-validator
sudo systemctl restart backup-validator
```

To view service logs:
```
sudo journalctl -u backup-validator -f
```

#### Customizing the Service

If you need to customize the service settings (such as the port or host address), edit the systemd unit file:
```
sudo systemctl stop backup-validator
sudo vi /etc/systemd/system/backup-validator.service
sudo systemctl daemon-reload
sudo systemctl start backup-validator
```

## Usage

### Starting the Server

#### Development Mode

For development, you can run the server directly with Flask:

```
python app.py
```

By default, the server listens on `0.0.0.0:5000`. You can configure this by setting environment variables:

- `HOST`: Host to bind to (default: `0.0.0.0`)
- `PORT`: Port to listen on (default: `5000`)
- `FLASK_DEBUG`: Set to `true` to enable debug mode (default: `false`)

#### Production Mode

For production deployment, it's recommended to use Gunicorn:

```
pip install gunicorn
gunicorn --bind 0.0.0.0:5000 --workers 3 app:app
```

This provides better performance, stability, and security compared to Flask's built-in development server.

### API Endpoints

#### Execute a Script

```
GET /backup-validator/{script-name}?param1=value1&param2=value2
```

- `{script-name}`: Name of the script to execute (without extension)
- URL parameters are passed to the script as command-line arguments in the format `--param=value`

#### Health Check

```
GET /health
```

Returns `{"status": "ok"}` with status code 200 if the service is running.

### Adding Scripts

Place your scripts in the `scripts` directory:

- For Linux/macOS: Make sure the scripts are executable (`chmod +x script_name`)
- For Windows: Use `.bat`, `.cmd`, or `.ps1` extensions

## Example

1. Place a script named `sample_test.sh` (Linux/macOS) or `sample_test.bat` (Windows) in the `scripts` directory
2. Make a request:
   ```
   curl "http://localhost:5000/backup-validator/sample_test?message=Hello%20World&fail=false"
   ```
3. Expected response:
   ```json
   {
     "status": "success",
     "message": "Hello World"
   }
   ```

If you set `fail=true`, you'll get:
```json
{
  "status": "error",
  "message": "Error: Script failed as requested"
}
```

## Example Scripts

### DNS Test

The tool includes a DNS resolution test script that checks if a hostname resolves to the expected IP address. It works on both Linux/macOS and Windows.

#### Usage

```
GET /backup-validator/dns_test?hostname=example.com&expected-ip=93.184.216.34&dns-server=8.8.8.8
```

Parameters:
- `hostname` (required): The hostname to resolve
- `expected-ip` (required): The expected IP address
- `dns-server` (optional): The DNS server to use for resolution (defaults to system DNS)

#### Response Examples

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

### DHCP Test

The tool includes a DHCP test script that checks if DHCP is working properly on a specified network interface. This script is available for Linux systems.

**Note:** This script requires root/sudo privileges to run.

#### Usage

```
GET /backup-validator/dhcp_test?interface=eth0&timeout=30&expected-subnet=192.168.1
```

Parameters:
- `interface` (required): The network interface to test (e.g., eth0, wlan0)
- `timeout` (optional): The timeout in seconds for DHCP request (default: 30)
- `expected-subnet` (optional): The expected subnet prefix for the assigned IP (e.g., 192.168.1)

#### Response Examples

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

### Kerberos Test

The tool includes a Kerberos authentication test script that verifies if provided credentials can be used to obtain a valid Kerberos ticket. This script is available for Linux systems with Kerberos client tools installed.

**Note:** This script requires the Kerberos client tools (kinit, klist, etc.) to be installed on the system.

#### Usage

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

#### Response Examples

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

## Security Considerations

- The tool executes scripts on the host machine, so it should only be deployed in a trusted environment.
- Consider implementing authentication/authorization if deploying in a production environment.
- Restrict network access to the API endpoints to trusted clients.

## Logging

The application uses Loguru for advanced logging capabilities:

- Console logs are displayed in a readable format
- File logs are stored in the `logs` directory
- Log files are automatically rotated when they reach 10MB
- Old logs are deleted after 1 week

You can customize the logging behavior by modifying the Loguru configuration in `app.py`.

## License

[MIT License](LICENSE)
