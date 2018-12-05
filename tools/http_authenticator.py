#!/usr/bin/env python3
#
# https://gist.githubusercontent.com/Integralist/ce5ebb37390ab0ae56c9e6e80128fdc2/raw/2e62bcc38aed7873f07e06865f0f4c06ec9129ee/Python3%2520HTTP%2520Server.py
#
# Sample HTTP authenticator service which work with ntopng "http" authentication.
# The "HTTP server" URL should be set to "http://localhost:3001/login".
#
# Test with:
#   curl --header "Content-Type: application/json" --request POST --data '{"user":"testadmin","password":"avoid-plaintext-admin"}' -v http://localhost:3001/login
# 
import time
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST_NAME = 'localhost'
PORT_NUMBER = 3001

USERS_DB = {
    "testuser": {"password": "avoid-plaintext", "admin": False},
    "testadmin": {"password": "avoid-plaintext-admin", "admin": True},
}

class MyHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/login":
            self.handle_login()
        else:
            self.respond({'status': 500})

    def handle_http(self, status_code, path, data={}):
        self.send_response(status_code)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        content = json.dumps(data)
        return bytes(content, 'UTF-8')

    def respond(self, opts, data={}):
        response = self.handle_http(opts['status'], self.path, data)
        self.wfile.write(response)

    def handle_login(self):
        data_string = self.rfile.read(int(self.headers['Content-Length']))
        data = json.loads(data_string)
        print(data)
        username = data.get("user")
        password = data.get("password")
        status = 403
        response_data = {}

        if username and password and (username in USERS_DB):
            user = USERS_DB[username]

            if user["password"] == password:
                status = 200

                if user["admin"]:
                    admin = True
                    response_data = {"admin": True}

        return self.respond({'status': status}, response_data)

if __name__ == '__main__':
    server_class = HTTPServer
    httpd = server_class((HOST_NAME, PORT_NUMBER), MyHandler)
    print(time.asctime(), 'Server Starts - %s:%s' % (HOST_NAME, PORT_NUMBER))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    print(time.asctime(), 'Server Stops - %s:%s' % (HOST_NAME, PORT_NUMBER))
