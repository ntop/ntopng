#!/usr/bin/env python3

#
# Test application for python API
#

from ntopng import ntopng, interface, host, flow
import os

my_ntopng = ntopng('admin', 'admin', 'http://localhost:3000')

ifid = 4

my_interface = interface.interface(my_ntopng)
my_interface.self_test(ifid)

my_host = host.host(my_ntopng)
my_host.self_test(ifid)

my_flow = flow.flow(my_ntopng)
my_flow.self_test(ifid)


os._exit(0)

