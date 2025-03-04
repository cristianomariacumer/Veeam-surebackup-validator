import os
import subprocess
import sys
import ipaddress
import re
from flask import Flask, request, abort, jsonify
from flask_restful import Resource, Api
from loguru import logger

# Create logs directory if it doesn't exist
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs'), exist_ok=True)
    
# Create scripts directory if it doesn't exist
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts'), exist_ok=True)

# Configure Loguru logger
logger.remove()  # Remove default handler
logger.add(
    sys.stderr,
    format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}",
    level="INFO"
)
logger.add(
    "logs/backup-validator.log",
    rotation="10 MB",
    retention="1 week",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}",
    level="INFO"
)

app = Flask(__name__)
api = Api(app)


# Load IP whitelist from environment variable or config file
def load_ip_whitelist():
    """
    Load the IP whitelist from environment variable or config file.
    Returns a list of allowed IP addresses or networks.
    """
    # Check for IP whitelist in environment variable (comma-separated list)
    whitelist_env = os.environ.get('ALLOWED_IPS', '')
    if whitelist_env:
        return [ip.strip() for ip in whitelist_env.split(',') if ip.strip()]
    
    # Check for IP whitelist file
    whitelist_file = os.environ.get('ALLOWED_IPS_FILE', 'allowed_ips.conf')
    if os.path.exists(whitelist_file):
        try:
            with open(whitelist_file, 'r') as f:
                return [line.strip() for line in f if line.strip() and not line.startswith('#')]
        except Exception as e:
            logger.error(f"Error reading IP whitelist file: {e}")
    
    # Default to allowing only localhost if no configuration is found
    return ['127.0.0.1', '::1', '172.16.0.0/12', '192.168.0.0/16', '10.0.0.0/8']

# Get the IP whitelist
ALLOWED_IPS = load_ip_whitelist()
logger.info(f"IP whitelist loaded with {len(ALLOWED_IPS)} entries")

# Function to check if an IP is in the whitelist
def is_ip_allowed(client_ip):
    """
    Check if the client IP is in the allowed IP list.
    Supports both individual IPs and CIDR notation.
    """
    if not ALLOWED_IPS:  # If the whitelist is empty, deny all
        return False
    
    # The request.remote_addr could be IPv4 or IPv6
    try:
        request_ip = ipaddress.ip_address(client_ip)
        
        # Check against each allowed IP/network
        for allowed in ALLOWED_IPS:
            try:
                # Check if it's a network (CIDR notation)
                if '/' in allowed:
                    network = ipaddress.ip_network(allowed, strict=False)
                    if request_ip in network:
                        return True
                else:
                    # It's a single IP
                    allowed_ip = ipaddress.ip_address(allowed)
                    if request_ip == allowed_ip:
                        return True
            except Exception as e:
                logger.warning(f"Invalid IP or network in whitelist: {allowed} - {e}")
                
        return False
    except ValueError:
        logger.warning(f"Invalid IP address received: {client_ip}")
        return False

# Request IP validation middleware
@app.before_request
def validate_ip():
    """Middleware to validate the client IP before processing the request."""
    client_ip = request.remote_addr
    
    # Optional: Check X-Forwarded-For header if behind a proxy
    if 'X-Forwarded-For' in request.headers and os.environ.get('TRUST_PROXY', 'False').lower() == 'true':
        client_ip = request.headers.get('X-Forwarded-For', '').split(',')[0].strip()
    
    if not is_ip_allowed(client_ip):
        logger.warning(f"Blocked request from unauthorized IP: {client_ip}")
        abort(403)  # Forbidden

class ScriptExecutor(Resource):
    def get(self, script_name):
        """
        Execute a script with the provided URL parameters and return appropriate HTTP status.
        
        Args:
            script_name (str): Name of the script to execute
            
        Returns:
            tuple: (response, status_code)
        """
        # Extract parameters from URL query string
        params = {}
        for param, value in request.args.items():
            params[param] = value
            
        # Execute the script with the parameters
        return self._execute_script(script_name, params)
    
    def post(self, script_name):
        """
        Execute a script with parameters provided in the JSON body and return appropriate HTTP status.
        
        Args:
            script_name (str): Name of the script to execute
            
        Returns:
            tuple: (response, status_code)
        """
        # Check if content type is JSON
        if not request.is_json:
            return {'error': 'Content-Type must be application/json'}, 415
            
        # Extract parameters from JSON body
        try:
            params = request.get_json()
            if not isinstance(params, dict):
                return {'error': 'JSON body must be an object'}, 400
        except Exception as e:
            logger.exception("Failed to parse JSON body")
            return {'error': f'Invalid JSON: {str(e)}'}, 400
            
        # Execute the script with the parameters
        return self._execute_script(script_name, params)
    
    def _execute_script(self, script_name, params):
        """
        Internal method to execute a script with the provided parameters.
        
        Args:
            script_name (str): Name of the script to execute
            params (dict): Parameters to pass to the script
            
        Returns:
            tuple: (response, status_code)
        """
        try:
            # Get client IP for logging
            client_ip = request.remote_addr
            if 'X-Forwarded-For' in request.headers and os.environ.get('TRUST_PROXY', 'False').lower() == 'true':
                client_ip = request.headers.get('X-Forwarded-For', '').split(',')[0].strip()
            
            # Sanitize script name to prevent directory traversal
            if not script_name or '/' in script_name or '\\' in script_name or '..' in script_name:
                return {'error': 'Invalid script name'}, 400
                
            # Get the script directory
            script_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts')
            
            # Construct full script path
            if sys.platform == 'win32':
                script_path = os.path.join(script_dir, f"{script_name}.bat")
                if not os.path.exists(script_path):
                    script_path = os.path.join(script_dir, f"{script_name}.cmd")
                    if not os.path.exists(script_path):
                        script_path = os.path.join(script_dir, f"{script_name}.ps1")
            else:  # Linux/Mac
                script_path = os.path.join(script_dir, script_name)
            
            # Check if script exists
            if not os.path.exists(script_path):
                return {'error': f'Script {script_name} not found'}, 404
                
            # Verify the script is inside the scripts directory (prevent symlink attacks)
            script_real_path = os.path.realpath(script_path)
            scripts_real_dir = os.path.realpath(script_dir)
            
            if not script_real_path.startswith(scripts_real_dir):
                logger.warning(f"Attempted to access script outside scripts directory: {script_path}")
                return {'error': 'Access denied'}, 403
            
            # Make script executable (for Unix systems)
            if sys.platform != 'win32':
                os.chmod(script_path, 0o755)  # rwxr-xr-x
            
            # Extract parameters and obfuscate password for logging
            cmd_args = []
            log_args = []
            for param, value in params.items():
                cmd_args.append(f"--{param}={value}")
                # Create a sanitized version for logging
                if 'password' in param.lower():
                    log_args.append(f"--{param}=********")
                else:
                    log_args.append(f"--{param}={value}")
            
            # Prepare the command
            if sys.platform == 'win32' and script_path.endswith('.ps1'):
                cmd = ["powershell", "-File", script_path] + cmd_args
                log_cmd = ["powershell", "-File", script_path] + log_args
            else:
                cmd = [script_path] + cmd_args
                log_cmd = [script_path] + log_args
            
            logger.info(f"Request from {client_ip} - Executing command: {log_cmd}")
            
            # Execute the script
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            # Check return code
            if result.returncode == 0:
                # Obfuscate password in outputs if present
                sanitized_output = self._sanitize_sensitive_data(result.stdout.strip())
                return {'status': 'success', 'message': sanitized_output}, 200
            else:
                error_message = result.stderr.strip() or result.stdout.strip() or "Unknown error occurred"
                # Obfuscate password in error messages
                sanitized_error = self._sanitize_sensitive_data(error_message)
                return {'status': 'error', 'message': sanitized_error}, 500
                
        except Exception as e:
            logger.exception(f"Error executing script {script_name}")
            return {'status': 'error', 'message': str(e)}, 500

    def _sanitize_sensitive_data(self, text):
        """
        Sanitize sensitive data like passwords from the output text.
        
        Args:
            text (str): The text to sanitize
            
        Returns:
            str: Sanitized text
        """
        # List of patterns to sanitize (add more as needed)
        patterns = [
            (r'--password=\S+', '--password=********'),
            (r'password: \S+', 'password: ********'),
            (r'Password: \S+', 'Password: ********'),
            (r'Authentication failed. Please check username and password.', 'Authentication failed.'),
            # Add other patterns as needed for different scripts
        ]
        
        result = text
        for pattern, replacement in patterns:
            result = re.sub(pattern, replacement, result)
            
        return result

# Add the resource to the API
api.add_resource(ScriptExecutor, '/backup-validator/<string:script_name>')

# Add a simple health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return {'status': 'ok'}, 200

if __name__ == '__main__':
    # Get host and port from environment variables or use defaults
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5001))
    
    logger.info(f"Starting backup-validator service on {host}:{port}")
    logger.info(f"IP whitelisting enabled. Allowed IPs/networks: {ALLOWED_IPS}")
    app.run(host=host, port=port, debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true') 