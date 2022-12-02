#
#
# (C) 2022 - ntopng.org
#
#

import requests
import json
from requests.auth import HTTPBasicAuth

class ntopng:
    def __init__(self, username, password, url):
        self.username = username        
        self.password = password
        self.url      = url

    # internal method used to issue requests
    def request(self, url, params):
        api_url = self.url + url
        
        response = requests.get(api_url, auth = HTTPBasicAuth(self.username, self.password), params = params )
            
        if response.status_code != 200:
            raise Exception("Invalid response code " + str(response.status_code))
        
        response = response.json()
        return response['rsp']

    
