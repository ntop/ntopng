#!/usr/bin/env python3

#
# Test application for python API
#

import os
import sys
import getopt


from ntopng.ntopng import Ntopng
from ntopng.interface import Interface
from ntopng.host import Host
from ntopng.flow import Flow


# Defaults
username   = "admin"
password   = "admin"
ntopng_url = "http://localhost:3000"
iface_id   = 0
auth_token = None

def usage():
    print("test.py [-h] [-u <username>] [-p <passwrd>] [-n <ntopng_url>] [-i <iface id>]")
    print("        [-t <auth token>]")
    print("")
    print("Example: ./test.py -t ce0e284c774fac5a3e981152d325cfae -i 4")
    print("         ./test.py -u ntop -p mypassword -i 4")
    sys.exit(0)

##########

try:
    opts, args = getopt.getopt(sys.argv[1:], "hu:p:n:i:t:",
                               ["help",
                                "username=",
                                "password=",
                                "ntopng_url=",
                                "iface_id=",
                                "auth_token="]
                               )
except getopt.GetoptError as err:
    print(err)
    usage()
    sys.exit(2)

for o, v in opts:
    if(o in ("-h", "--help")):
        usage()
    elif(o in ("-u", "--username")):
        username = v
    elif(o in ("-p", "--password")):
        password = v
    elif(o in ("-n", "--ntopng_url")):
        ntopng_url = v
    elif(o in ("-i", "--iface_id")):
        iface_id = v
    elif(o in ("-t", "--auth_token")):
        auth_token = v

try:
    my_ntopng = Ntopng(username, password, auth_token, ntopng_url)
except ValueError as e:
    print(e)
    os._exit(-1)
    
try:
    my_interface = Interface(my_ntopng)
    print("\n\nInterface")
    my_interface.self_test(iface_id)
    
    my_host = Host(my_ntopng)
    print("\n\nHost")
    my_host.self_test(iface_id)
    
    my_flow = Flow(my_ntopng)
    print("\n\nFlow")
    my_flow.self_test(iface_id)
except ValueError as e:
    print(e)
    os._exit(-1)


os._exit(0)

