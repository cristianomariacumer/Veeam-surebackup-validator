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

#### API Documentation (Swagger UI)

The API documentation is available through Swagger UI at:

```
http://localhost:5000/api/docs
```

This interactive documentation allows you to:
- Explore all available endpoints
- Test API calls directly from the browser
- View request and response schemas

#### Execute a Script

The script execution endpoint supports both GET and POST requests:

```
GET /backup-validator/{script-name}?param1=value1&param2=value2
```

OR

```
POST /backup-validator/{script-name}
Content-Type: application/json

{
  "param1": "value1", 
  "param2": "value2"
}
```

- `{script-name}`: Name of the script to execute (without extension)
- Parameters can be provided either as URL query parameters (GET) or as a JSON object in the request body (POST)
- In both cases, parameters are passed to the script as command-line arguments in the format `--param=value`
- For sensitive information like passwords, using POST with JSON body is recommended

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

## Available Test Scripts

The Backup Validator includes several pre-configured test scripts for common network and authentication services:

### [DNS Test](documentation/dns_test.md)

Tests if a hostname resolves to the expected IP address. Works on both Linux/macOS and Windows.

### [DHCP Test](documentation/dhcp_test.md)

Tests if DHCP is working properly on a specified network interface. Available for Linux systems.

**Note:** This script requires sudo privileges. See [Sudo Configuration](documentation/sudo_configuration.md) for setup.

### [Kerberos Test](documentation/kerberos_test.md)

Verifies if provided credentials can be used to obtain a valid Kerberos ticket. Available for Linux systems with Kerberos client tools installed.

### [LDAPS Test](documentation/ldaps_test.md)

Checks connectivity to a domain controller or LDAP server over SSL. Available for Linux systems with OpenLDAP client tools installed.

### [MSSQL Test](documentation/mssql_test.md)

Runs a parametrised SQL query against Microsoft SQL Server using Kerberos keytab authentication via `sqlcmd`, then asserts the result matches an expected value.

## Security Considerations

- The tool executes scripts on the host machine, so it should only be deployed in a trusted environment.
- Consider implementing authentication/authorization if deploying in a production environment.
- Restrict network access to the API endpoints to trusted clients.
- Some scripts require elevated privileges (sudo). Be sure to review and understand the sudo permissions granted in the [Sudo Configuration](documentation/sudo_configuration.md).

## Logging

The application uses Loguru for advanced logging capabilities:

- Console logs are displayed in a readable format
- File logs are stored in the `logs` directory
- Log files are automatically rotated when they reach 10MB
- Old logs are deleted after 1 week

You can customize the logging behavior by modifying the Loguru configuration in `app.py`.

## IP Whitelisting

The Backup Validator service supports IP whitelisting to restrict access to authorized clients only. By default, the service allows connections from:
- localhost (127.0.0.1, ::1)
- Private network ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

### Configuration Options

You can customize the allowed IPs using one of these methods:

1. **Environment Variable**:
   ```
   export ALLOWED_IPS="192.168.1.10,192.168.1.11,10.0.0.0/24"
   ```

2. **Configuration File**:
   Create a file named `allowed_ips.conf` in the application directory with one IP or network per line:
   ```
   # Allow specific hosts
   192.168.1.10
   # Allow a subnet
   10.0.0.0/24
   ```

   You can specify a different config file path with:
   ```
   export ALLOWED_IPS_FILE="/etc/backup-validator/allowed_ips.conf"
   ```

3. **Proxy Support**:
   If the application is behind a proxy, enable trust for the X-Forwarded-For header:
   ```
   export TRUST_PROXY="true"
   ```

Requests from unauthorized IPs will receive a 403 Forbidden response.

## License

[European Union Public License v1.2 (EUPL v1.2)](https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12)
