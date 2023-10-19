#!/usr/bin/env python3

#
# Sample application for historical flows extraction
#

import os
import sys
import getopt
import time

sys.path.insert(0, '../')

from ntopng.ntopng import Ntopng

# Defaults
username     = "admin"
password     = "admin"
ntopng_url   = "http://localhost:3000"
iface_id     = 0
auth_token   = None
enable_debug = False
epoch_end    = int(time.time())
epoch_begin  = epoch_end - 3600
maxhits      = 10
host_ip      = "192.168.1.1"

##########

def usage():
    print("live_data.py [-u <username>] [-p <password>] [-t <auth token>] [-n <ntopng_url>]")
    print("         [-i <interface ID>] [-H <host IP>] [--debug] [--help]")
    print("")
    print("Example: ./live_data.py -t ce0e284c774fac5a3e981152d325cfae -i 4")
    print("         ./live_data.py -u ntop -p mypassword -i 4")
    sys.exit(0)

##########

try:
    opts, args = getopt.getopt(sys.argv[1:],
                               "hdu:p:n:i:H:t:",
                               ["help",
                                "debug",
                                "username=",
                                "password=",
                                "ntopng_url=",
                                "iface_id=",
                                "host_ip=",
                                "auth_token="]
                               )
except getopt.GetoptError as err:
    print(err)
    usage()
    sys.exit(2)

for o, v in opts:
    if(o in ("-h", "--help")):
        usage()
    elif(o in ("-d", "--debug")):
        enable_debug = True
    elif(o in ("-u", "--username")):
        username = v
    elif(o in ("-p", "--password")):
        password = v
    elif(o in ("-n", "--ntopng_url")):
        ntopng_url = v
    elif(o in ("-i", "--iface_id")):
        iface_id = v
    elif(o in ("-H", "--host_ip")):
        host_ip = v
    elif(o in ("-t", "--auth_token")):
        auth_token = v

##########

def format_host(rsp):
    for host in rsp:
        print(host["ip"] + " => ", end='')
        print(host)

def active_hosts(my_interface):
    rsp = my_interface.get_active_hosts()
    format_host(rsp)

##########

try:
    my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

    if(enable_debug):
        my_ntopng.enable_debug()        
except ValueError as e:
    print(e)
    os._exit(-1)

try:
    my_interface = my_ntopng.get_interface(iface_id)
    print("==========================\nActive Hosts")
    active_hosts(my_interface)
    
except ValueError as e:
    print(e)
    os._exit(-1)

os._exit(0)
