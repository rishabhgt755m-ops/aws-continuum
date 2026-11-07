import json
import os
import socket
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

INSTANCE_ID = os.environ.get("INSTANCE_ID", socket.gethostname())
DB_HOST = os.environ.get("DB_PROXY_HOST", "")
DB_USER = "continuum_app"
DB_NAME = "continuum"
REGION = "eu-west-1"


def database_healthy():
    if not DB_HOST:
        return False

    try:
        token = subprocess.run(
            [
                "/usr/bin/aws", "rds", "generate-db-auth-token",
                "--region", REGION,
                "--hostname", DB_HOST,
                "--port", "5432",
                "--username", DB_USER,
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        ).stdout.strip()

        env = os.environ.copy()
        env.update({
            "PGPASSWORD": token,
            "PGSSLMODE": "verify-full",
            "PGSSLROOTCERT": "/etc/pki/tls/certs/ca-bundle.crt",
            "PGCONNECT_TIMEOUT": "5",
        })

        result = subprocess.run(
            [
                "/usr/bin/psql", "-X", "-w", "-qAt",
                "-h", DB_HOST,
                "-p", "5432",
                "-U", DB_USER,
                "-d", DB_NAME,
                "-c", "SELECT 1;",
            ],
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.returncode == 0 and result.stdout.strip() == "1"

    except (OSError, subprocess.SubprocessError):
        return False


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            status = 200
            body = {"status": "healthy"}
        elif self.path == "/instance":
            status = 200
            body = {
                "application": "continuum",
                "instance_id": INSTANCE_ID,
            }
        elif self.path == "/db-health":
            healthy = database_healthy()
            status = 200 if healthy else 503
            body = {"database": "healthy" if healthy else "unavailable"}
        else:
            status = 404
            body = {"error": "not found"}

        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
