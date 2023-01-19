"""
Host
====================================
The Host class can be used to access information about an host through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

class Host:
    """
    Host provides information about hosts
    
    :param ntopng_obj: The ntopng handle
    """
    def __init__(self, ntopng_obj, ifid, ip, vlan=None):
        """
        Construct a new Host object

        :param ntopng_obj: The ntopng handle (Ntopng instance)
        :param ifid: The interface ID
        :type ifid: int
        :param ip: The host IP address
        :type ip: string
        :param vlan: The host VLAN ID (if any)
        :type vlan: int
        """
        self.ntopng_obj      = ntopng_obj
        self.ifid            = ifid
        self.ip              = ip
        self.vlan            = vlan
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_host_data(self):
        """
        Return all available information about a single host
        
        :return: Information about the host
        :rtype: object
        """

        params = { "ifid": self.ifid, "host": self.ip }
        if(self.vlan is not None):
            params['vlan'] = self.vlan

        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/data.lua", params))

    def get_l7_stats(self):
        """
        Return statistics about Layer 7 protocols for the host
        
        :return: Layer 7 protocol statistics
        :rtype: object
        """
        params = { "ifid": self.ifid, "host": self.ip, "breed": True, "ndpi_category": True, "collapse_stats": False }
        if(self.vlan is not None):
            params['vlan'] = self.vlan

        print("BBB")
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/l7/stats.lua", params))

    def get_dscp_stats(self, direction_rcvd):
        """
        Return statistics about DSCP per traffic direction for an host
        
        :param direction_rcvd: The traffic direction (True for received traffic, False for sent)
        :type direction_rcvd: boolean
        :return: DSCP statistics
        :rtype: object
        """
        if(direction_rcvd):
            direction = "recvd"
        else:
            direction = "sent"

        params = { "ifid": self.ifid, "host": self.ip, "direction": direction }
        if(self.vlan is not None):
            params['vlan'] = self.vlan

        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/dscp/stats.lua", params))

    def get_active_flows_paginated(self, currentPage, perPage):
        """
        Retrieve the (paginated) list of active flows for the specified interface and host
        
        :param currentPage: The current page
        :type currentPage: int
        :param perPage: The number of results per page
        :type perPage: int
        :return: All active flows
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": self.ifid, "host": self.ip, "vlan": self.vlan, "currentPage": currentPage, "perPage": perPage}))

    def self_test(self):
        try:
            print("Host Data ----------------------------")
            print(self.get_host_data())
            print("L7 Stats ----------------------------")
            print(self.get_l7_stats())
            print("DSCP Stats (RX) ----------------------------")
            print(self.get_dscp_stats(True))
            print("DSCP Stats (TX) ----------------------------")
            print(self.get_dscp_stats(False))
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID or host specified")
