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

## Usage

### Starting the Server

Run the following command to start the server:

```
python app.py
```

By default, the server listens on `0.0.0.0:5000`. You can configure this by setting environment variables:

- `HOST`: Host to bind to (default: `0.0.0.0`)
- `PORT`: Port to listen on (default: `5000`)
- `FLASK_DEBUG`: Set to `true` to enable debug mode (default: `false`)

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
