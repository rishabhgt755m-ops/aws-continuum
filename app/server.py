import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

INSTANCE_ID = os.environ.get("INSTANCE_ID", socket.gethostname())


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
