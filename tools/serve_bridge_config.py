#!/usr/bin/env python

import sys
import json
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

FORMATS = ('json')
'''
Config groups allows both nDPI ids as well as protocol names.

Custom protocol names are supported as well. Custom protocol names
are defined in a text file. To tell ntopng to use that custom file
use option --ndpi-protocols, e.g., --ndpi-protocols /tmp/custom.txt

'''

sample_bridge_config = {
    "users":{
        "maina" : {
            "full_name": "Maina Fast",
            "password": "ntop0101",
            "default_policy": "pass",
            "policies" : {10 : "slow_pass",
                          "Facebook": "slower_pass",
                          "MyCustomProtocol": "drop",
                          "YouTube": "drop"}
        },
        "simon" : {
            "full_name": "Simon Speed",
            "password": "ntop0102",
            "default_policy": "drop",
            "policies" : {20 : "slow_pass",
                          22: "slower_pass",
                          "MyCustomProtocol": "pass",
                          "YouTube": "slower_pass"}
        }
    }}

class Handler(BaseHTTPRequestHandler):
    #handle GET command
    def do_GET(self):
        self.request.sendall(json.dumps(sample_bridge_config))
        return

def run(port=8000):
    print('http server is starting...')
    #ip and port of server
    server_address = ('127.0.0.1', port)
    httpd = HTTPServer(server_address, Handler)
    print('http server is running...listening on port %s' %port)
    httpd.serve_forever()

if __name__ == '__main__':
    from optparse import OptionParser
    op = OptionParser(__doc__)

    op.add_option("-p", default=8000, type="int", dest="port",
                  help="port #")

    opts, args = op.parse_args(sys.argv)

    run(opts.port)

