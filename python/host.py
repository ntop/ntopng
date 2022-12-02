#
#
# (C) 2022 - ntop.org
#
# host class
# https://www.ntop.org/guides/ntopng/api/rest/api_v2.html
#

import requests
import json
from requests.auth import HTTPBasicAuth
from ntopng import ntopng

class host:
    def __init__(self, ntopng_obj):
        self.ntopng_obj = ntopng_obj
        self.rest_v2_url = "/lua/rest/v2"
        
    def get_active_hosts(self, ifid):
        return(ntopng.request(self.ntopng_obj, self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid}))
    
    def get_active_hosts_paginated(self, ifid, currentPage, perPage):
        return(ntopng.request(self.ntopng_obj, self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid, "currentPage": currentPage, "perPage": perPage}))
    
    def self_test(self, ifid):
        print("----------------------------")
        print(self.get_active_hosts(ifid))
        print("----------------------------")
        print(self.get_active_hosts_paginated(ifid, 1, 100))
        print("----------------------------")

