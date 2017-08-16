#!/usr/bin/env python

import sys
import json
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

FORMATS = ('json')

sample_bridge_config = {
    "shaping_profiles" : {
        "dropAll" : {"bw" : 0}, "passAll" : {"bw" : -1},
        "10Mbps" : {"bw" : 10000}, "20Mbps" : {"bw" : 20000}},
    "groups":{
        "maina" : {"shaping_profiles" : {"default" : "passAll", 10 :  "10Mbps"}},
        "simon" : {"shaping_profiles" : {"default" : "dropAll", 20 :  "20Mbps", 22 : "10Mbps"}}
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

