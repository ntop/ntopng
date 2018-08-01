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
    "users" : {
        "Not Assigned" : {
            "default_policy": "drop",
            "policies" : {10 : "slow_pass",
                          "Facebook": "pass",
                          "MyCustomProtocol": "pass",
                          "YouTube": "pass"}
        },
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
    },
    "associations" : { 
        "DE:AD:BE:EE:FF:FF"  : {"group" : "maina" ,        "connectivity" : "pass"},
        "11:22:33:44:55:66"  : {"group" : "maina" ,        "connectivity" : "pass"},
        "AA:BB:CC:DD:EE:FF"  : {"group" : "simon" ,        "connectivity" : "pass"},
        "66:55:44:33:22:11"  : {"group" : "simon" ,        "connectivity" : "pass"},
    }
}

# sample_string_config='{"users": {"DEFAULT": {"full_name": "default", "password": "default", "default_policy": "pass", "policies": {"JWP": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "default": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "30min": {"default_policy": "pass", "password": "30min", "full_name": "30min", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "HotelManager": {"default_policy": "pass", "password": "HotelManager", "full_name": "HotelManager", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "30Days": {"default_policy": "pass", "password": "30Days", "full_name": "30Days", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "sociaLogin": {"default_policy": "pass", "password": "sociaLogin", "full_name": "sociaLogin", "policies": {"JWP": "pass", "COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "COMODO": "pass", "JWPLTX": "pass", "119": "slower_pass", "PORTAL_SEAFY": "pass", "PAYMENT": "pass", "126": "slower_pass"}}, "4hours": {"default_policy": "pass", "password": "4hours", "full_name": "4hours", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "4G": {"default_policy": "pass", "password": "4G", "full_name": "4G", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "1hour": {"default_policy": "pass", "password": "1hour", "full_name": "1hour", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "8hours": {"default_policy": "pass", "password": "8hours", "full_name": "8hours", "policies": {"COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "JWP": "pass", "PORTAL_SEAFY": "pass", "JWPLTX": "pass", "PAYMENT": "pass", "COMODO": "pass"}}, "Special": {"default_policy": "pass", "password": "Special", "full_name": "Special", "policies": {"133": "slower_pass", "7": "slower_pass", "JWP": "pass", "142": "slower_pass", "144": "slower_pass", "COMODOCA": "pass", "ENTITJWP": "pass", "STRIPE": "pass", "SEAFY": "pass", "91": "slower_pass", "156": "slower_pass", "COMODO": "pass", "JWPLTX": "pass", "125": "slower_pass", "PORTAL_SEAFY": "pass", "124": "slower_pass", "PAYMENT": "pass"}}}}'

class Handler(BaseHTTPRequestHandler):
    #handle GET command
    def do_GET(self):
        self.request.sendall(json.dumps(sample_bridge_config))
#        self.request.sendall(sample_string_config)
        return

def run(port=8000):
    print('http server is starting...')
    #ip and port of server
    server_address = ('0.0.0.0', port)
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
