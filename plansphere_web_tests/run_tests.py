import os
import sys
import time
import subprocess
import http.server
import socketserver
import threading
import socket

PORT = 8000
DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "plansphere_web"))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def start_server():
    class SilentHTTPRequestHandler(Handler):
        def log_message(self, format, *args):
            pass
            
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", PORT), SilentHTTPRequestHandler) as httpd:
            print(f"Local Server: Started serving '{DIRECTORY}' on http://localhost:{PORT}")
            httpd.serve_forever()
    except Exception as e:
        print(f"Local Server Error: {e}")

def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

if __name__ == "__main__":
    print(f"Local Server Directory: {DIRECTORY}")
    
    # 1. Start local HTTP Server in background thread
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    
    # 2. Check and start Appium Server if not running
    appium_process = None
    if not is_port_open(4723):
        print("Appium Server is not running on port 4723. Attempting to start Appium...")
        try:
            # Run in a shell in the background
            appium_process = subprocess.Popen(
                ["appium", "--port", "4723"],
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print("Appium Server started in background. Waiting for initialization...")
            # Wait up to 5 seconds for Appium to start
            for _ in range(10):
                if is_port_open(4723):
                    print("Appium Server initialized successfully.")
                    break
                time.sleep(0.5)
            else:
                print("Appium Server initialization timed out. Tests will run in fallback emulation mode.")
        except Exception as e:
            print(f"Could not start Appium server: {e}. Tests will run in fallback emulation mode.")
    else:
        print("Appium Server is already running on port 4723.")

    # Wait for the HTTP server to spin up
    time.sleep(2)
    
    tests_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Run pytest
    print("Launching Pytest test suite execution (Selenium & Appium)...")
    pytest_command = [sys.executable, "-m", "pytest", "-v", tests_dir]
    
    if len(sys.argv) > 1:
        pytest_command.extend(sys.argv[1:])
        
    result = subprocess.run(pytest_command)
    
    # Cleanup Appium if we started it
    if appium_process:
        print("Stopping background Appium process...")
        try:
            appium_process.terminate()
            appium_process.wait(timeout=2)
        except Exception:
            pass
            
    print(f"Test run completed with exit code {result.returncode}")
    sys.exit(result.returncode)
