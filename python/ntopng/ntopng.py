#
#
# (C) 2022 - ntop.org
#
#

import requests
import json
from requests.auth import HTTPBasicAuth

class Ntopng:
    def issue_request(self, url, params):
        if(self.auth_token != None):
            response = requests.get(url, auth = None, headers = { "Authorization" : "Token " + self.auth_token }, params = params)
        else:
            response = requests.get(url, auth = HTTPBasicAuth(self.username, self.password), params = params)

        return(response)
    
    def __init__(self, username, password, auth_token, url):
        self.url        = url

        if(auth_token != None):
            self.auth_token = auth_token
        else:
            self.username   = username
            self.password   = password
                          
        # self_test
        try:
            url = self.url + "/lua/self_test.lua"

            response = self.issue_request(url, None)
                
            if(not(response.headers['Content-Type'].startswith('application/json'))):
                raise ValueError("Invalid credentials or URL specified")
        except:
            raise ValueError("Invalid credentials or URL specified")
        
    # internal method used to issue requests
    def request(self, url, params):
        api_url = self.url + url

        response = self.issue_request(api_url, params)
            
        if response.status_code != 200:
            raise Exception("Invalid response code " + str(response.status_code))

        response = response.json()

        return response['rsp']

    
