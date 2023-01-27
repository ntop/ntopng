#!/usr/bin/env python3

"""
PDF report creation script using the Report class of the ntopng Python API
"""

import os
import sys
import time
import getopt
import pandas as pd
from fpdf import FPDF
import plotly.figure_factory as ff
import plotly.graph_objects as go

sys.path.insert(0, '../../')

from ntopng.ntopng import Ntopng
from ntopng.report import Report

### NTOPNG API SETUP
username     = "admin"
password     = "admin"
ntopng_url   = "http://localhost:3000"
iface_id     = 0
auth_token   = None
enable_debug = False
output_file  = "report.pdf"

actual_ts = int(time.time())
yesterday = (actual_ts - 86400)

##########

def usage():
    print("test.py [-u <username>] [-p <password>] [-t <auth token>] [-n <ntopng_url>]")
    print("             [-i <interface ID>] [--debug] [--help]")
    print("")
    print("Example: ./test.py -t ce0e284c774fac5a3e981152d325cfae -i 4")
    print("         ./test.py -u ntop -p mypassword -i 4")
    sys.exit(0)

##########

try:
    opts, args = getopt.getopt(sys.argv[1:],
                               "hdu:p:n:i:t:",
                               ["help",
                                "debug",
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
    elif(o in ("-t", "--auth_token")):
        auth_token = v

##################################
######### DATA COLLECTOR #########
##################################

print("Connecting to ntopng...")

try:
    my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

    if(enable_debug):
        my_ntopng.enable_debug()        
except ValueError as e:
    print(e)
    os._exit(-1)

generator = Report(my_ntopng, iface_id)

print("Generating PDF...")

generator.generate_interface_report(output_file)


