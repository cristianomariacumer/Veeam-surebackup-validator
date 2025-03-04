import os
import subprocess
import sys
import logging
from flask import Flask, request
from flask_restful import Resource, Api
from werkzeug.exceptions import InternalServerError

# Configure logging
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('backup-validator')

app = Flask(__name__)
api = Api(app)

class ScriptExecutor(Resource):
    def get(self, script_name):
        """
        Execute a script with the provided URL parameters and return appropriate HTTP status.
        
        Args:
            script_name (str): Name of the script to execute
            
        Returns:
            tuple: (response, status_code)
        """
        try:
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
            
            # Make script executable (for Unix systems)
            if sys.platform != 'win32':
                os.chmod(script_path, 0o755)  # rwxr-xr-x
            
            # Extract URL parameters
            cmd_args = []
            for param, value in request.args.items():
                cmd_args.append(f"--{param}={value}")
            
            # Prepare the command
            if sys.platform == 'win32' and script_path.endswith('.ps1'):
                cmd = ["powershell", "-File", script_path] + cmd_args
            else:
                cmd = [script_path] + cmd_args
            
            logger.info(f"Executing command: {cmd}")
            
            # Execute the script
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            # Check return code
            if result.returncode == 0:
                return {'status': 'success', 'message': result.stdout.strip()}, 200
            else:
                error_message = result.stderr.strip() or result.stdout.strip() or "Unknown error occurred"
                return {'status': 'error', 'message': error_message}, 500
                
        except Exception as e:
            logger.exception(f"Error executing script {script_name}")
            return {'status': 'error', 'message': str(e)}, 500

# Add the resource to the API
api.add_resource(ScriptExecutor, '/backup-validator/<string:script_name>')

# Add a simple health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return {'status': 'ok'}, 200

if __name__ == '__main__':
    # Create scripts directory if it doesn't exist
    os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts'), exist_ok=True)
    
    # Get host and port from environment variables or use defaults
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    
    logger.info(f"Starting backup-validator service on {host}:{port}")
    app.run(host=host, port=port, debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true') 