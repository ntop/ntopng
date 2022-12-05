#
#
# (C) 2022 - ntop.org
#
#

import requests
import json
from requests.auth import HTTPBasicAuth

class Ntopng:
    def __init__(self, username, password, url):
        self.username = username        
        self.password = password
        self.url      = url

        # self_test
        try:
            url = self.url + "/lua/self_test.lua"
            response = requests.get(url, auth = HTTPBasicAuth(self.username, self.password))

            if(not(response.headers['Content-Type'].startswith('application/json'))):
                raise ValueError("Invalid credentials or URL specified")
        except:
            raise ValueError("Invalid credentials or URL specified")
        
    # internal method used to issue requests
    def request(self, url, params):
        api_url = self.url + url

        response = requests.get(api_url, auth = HTTPBasicAuth(self.username, self.password), params = params)
            
        if response.status_code != 200:
            raise Exception("Invalid response code " + str(response.status_code))

        response = response.json()

        return response['rsp']

    
