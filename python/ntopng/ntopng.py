"""
Ntopng
====================================
The Ntopng class stores information for accessing the ntopng instance (IP and credentials)
and provides global traffic information and constants (interfaces, alert types, etc).
"""

import requests
import json
from requests.auth import HTTPBasicAuth

from ntopng.interface import Interface
from ntopng.historical import Historical

class Ntopng:        
    def __init__(self, username, password, auth_token, url):
        """
        Construct a new 'Ntopng' object
        
        :param username: The ntopng username (leave empty if token authentication is used)
        :type username: string
        :param password: The ntopng password (leave empty if token authentication is used)
        :type password: string
        :param auth_token: The authentication token (leave empty if username/password authentication is used)
        :type auth_token: int
        :param url: The ntopng URL (e.g. http://localhost:3000)
        :type url: string
        """
        
        self.url        = url
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

        if(auth_token != None):
            self.auth_token = auth_token
        else:
            self.username   = username
            self.password   = password
            self.auth_token = None
            
        self.debug = False
        
        # self_test
        try:
            url = self.url + "/lua/self_test.lua"

            response = self.issue_request(url, None)
                
            if(not(response.headers['Content-Type'].startswith('application/json'))):
                raise ValueError("Invalid credentials or URL specified")
        except:
            raise ValueError("Invalid credentials or URL specified")
       
    def issue_request(self, url, params):
        if(self.debug):
            print("Requesting [GET]: "+url)
            print(params)

        if(self.auth_token != None):
            response = requests.get(url, auth = None, headers = { "Authorization" : "Token " + self.auth_token }, params = params)
        else:
            response = requests.get(url, auth = HTTPBasicAuth(self.username, self.password), params = params)

        if(self.debug):
            print("Elapsed time: " + str(response.elapsed))
            
        return(response)

    def issue_post_request(self, url, params):
        if(self.debug):
            print("Requesting [POST]: " + url)
            print(params)
        
        if(self.auth_token != None):
            response = requests.post(url, auth = None, headers = { "Authorization" : "Token " + self.auth_token, "Content-Type" : "application/json" }, json = params)
        else:
            response = requests.post(url, auth = HTTPBasicAuth(self.username, self.password), headers = { "Content-Type" : "application/json" }, json = params)

        if(self.debug):
            print("Elapsed time: " + str(response.elapsed))
            
        return(response)

    def enable_debug(self):
        self.debug = True
 
    # internal method used to issue requests
    def request(self, url, params):
        api_url = self.url + url

        if(self.debug):
            print(params)
            
        response = self.issue_request(api_url, params)
            
        if response.status_code != 200:
            print(api_url)
            print(params)
            print("Invalid response code " + str(response.status_code))
            raise Exception("Invalid response code " + str(response.status_code))

        response = response.json()

        return response['rsp']


    # internal method used to issue requests
    def post_request(self, url, params):
        api_url = self.url + url

        if(self.debug):
            print(params)
            
        response = self.issue_post_request(api_url, params)
            
        if response.status_code != 200:
            print(api_url)
            print(params)
            print("Invalid response code " + str(response.status_code))
            raise Exception("Invalid response code " + str(response.status_code))

        response = response.json()

        return response['rsp']

    def get_alert_types(self):
        """
        Return all alert types
        
        :return: The list of alert types
        :rtype: array
        """
        return(self.request(self.rest_v2_url + "/get/alert/type/consts.lua", None))

    def get_alert_severities(self):
        """
        Return all severities
        
        :return: The list of severities
        :rtype: array
        """
        return(self.request(self.rest_v2_url + "/get/alert/severity/consts.lua", None))

    def get_interface(self, ifid):
        """
        Return an Interface instance
        
        :param ifid: The interface ID
        :type ifid: int
        :return: The interface instance
        :rtype: ntopng.Interface
        """ 
        return Interface(self, ifid)

    def get_historical_interface(self, ifid):
        """
        Return an Historical handle for an interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: The historical handle
        :rtype: ntopng.Historical
        """ 
        return Historical(self, ifid)

    def get_interfaces_list(self):
        """
        Return all available interfaces
        
        :return: The list of interfaces
        :rtype: array
        """
        return(self.request(self.rest_v2_url + "/get/ntopng/interfaces.lua", None))

    def get_host_interfaces_list(self, host):
        """
        Return all ntopng interfaces for a given host
        
        :param host: The host
        :type host: string
        :return: List of interfaces
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/interfaces.lua", { "host": host }))

    def self_test(self):
        try:
            print("Alert Types ----------------------------")
            print(self.get_alert_types())
            print("Severities ----------------------------")
            print(self.get_alert_severities())
            print("Interfaces List ----------------------------")
            print(self.get_interfaces_list())
            print("----------------------------")
        except:
            raise ValueError("Unable to retrieve information")   
