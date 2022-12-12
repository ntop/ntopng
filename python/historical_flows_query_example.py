#!/usr/bin/env python3

#
# Test application for python API for historical flows extraction
#

import os
import sys
import getopt
import time

from ntopng.ntopng import Ntopng
from ntopng.interface import Interface
from ntopng.host import Host
from ntopng.historical import Historical
from ntopng.flow import Flow


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

##########

def usage():
    print("historical_flows_query_example.py [-h] [-d] [-u <username>] [-p <passwrd>] [-n <ntopng_url>]")
    print("         [-i <iface id>] [-t <auth token>]")
    print("")
    print("Example: ./historical_flows_query_example.py -t ce0e284c774fac5a3e981152d325cfae -i 4")
    print("         ./historical_flows_query_example.py -u ntop -p mypassword -i 4")
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

# -----------------------------------------------------------

def format_rsp(rsp):
    for row in rsp:
        print(row)


def top_x_remote_ipv4_hosts(my_historical, epoch_begin, epoch_end, maxhits):
    select_clause = "IPV4_DST_ADDR,SUM(TOTAL_BYTES) TOT"
    where_clause  = "(SERVER_LOCATION=1)"
    group_by      = "IPV4_DST_ADDR_FORMATTED"
    order_by      = "TOT DESC"

    rsp = my_historical.get_flows(iface_id, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)
    format_rsp(rsp)

def top_x_remote_ipv4_hosts_ports(my_historical, epoch_begin, epoch_end, maxhits):
    select_clause = "IPV4_DST_ADDR,SUM(TOTAL_BYTES) TOT,IP_DST_PORT"
    where_clause  = "(SERVER_LOCATION=1)"
    group_by      = "IPV4_DST_ADDR_FORMATTED,IP_DST_PORT"
    order_by      = "TOT DESC"

    rsp = my_historical.get_flows(iface_id, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)
    format_rsp(rsp)

def top_x_remote_ports(my_historical, epoch_begin, epoch_end, maxhits):
    select_clause = "SUM(TOTAL_BYTES) TOT,IP_DST_PORT"
    where_clause  = "(SERVER_LOCATION=1)"
    group_by      = "IP_DST_PORT"
    order_by      = "TOT DESC"

    rsp = my_historical.get_flows(iface_id, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)
    format_rsp(rsp)

# -----------------------------------------------------------

try:
    my_ntopng = Ntopng(username, password, auth_token, ntopng_url)

    if(enable_debug):
        my_ntopng.enable_debug()        
except ValueError as e:
    print(e)
    os._exit(-1)

try:
    my_historical = Historical(my_ntopng)

    print("\n\n==========================\nTop X Remote Hosts Traffic")
    top_x_remote_ipv4_hosts(my_historical, epoch_begin, epoch_end, maxhits)
    print("\n\n==========================\nTop X Remote Host/Ports Traffic")
    top_x_remote_ipv4_hosts_ports(my_historical, epoch_begin, epoch_end, maxhits)
    print("\n\n==========================\nTop X Remote Ports Traffic")
    top_x_remote_ports(my_historical, epoch_begin, epoch_end, maxhits)
    
except ValueError as e:
    print(e)
    os._exit(-1)


os._exit(0)
