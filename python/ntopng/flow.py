"""
Flow
====================================
The Flow class can be used to access information about active flows through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

class Flow:
    """
    Flow provides information about active flows
    
    :param ntopng_obj: The ntopng handle
    """
    def __init__(self, ntopng_obj):
        """
        Construct a new Flow object
        
        :param ntopng_obj: The ntopng handle
        """
        self.ntopng_obj      = ntopng_obj
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_active_flows_paginated(self, ifid, currentPage, perPage):
        """
        Retrieve the (paginated) list of active flows for the specified interface
        
        :param ifid: The interface ID
        :type ifid: int
        :param currentPage: The current page
        :type currentPage: int
        :param perPage: The number of results per page
        :type perPage: int
        :return: All active flows
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_active_host_flows_paginated(self, ifid, host, vlan, currentPage, perPage):
        """
        Retrieve the (paginated) list of active flows for the specified interface and host
        
        :param ifid: The interface ID
        :type ifid: int
        :param host: The host
        :type host: string
        :param vlan: The host VLAN ID (if any)
        :type vlan: string
        :param currentPage: The current page
        :type currentPage: int
        :param perPage: The number of results per page
        :type perPage: int
        :return: All active flows
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": ifid, "host": host, "vlan": vlan, "currentPage": currentPage, "perPage": perPage}))

    def get_active_l4_proto_flow_counters(self, ifid):
        """
        Return statistics about active flows per Layer 4 protocol on an interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: Layer 4 protocol flows statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l4/counters.lua", {"ifid": ifid }))

    def get_active_l7_proto_flow_counters(self, ifid):
        """
        Return statistics about active flows per Layer 7 protocol on an interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: Layer 7 protocol flows statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l7/counters.lua", {"ifid": ifid }))

    def self_test(self, ifid, host):
        try:
            print("----------------------------")
            print(self.get_active_flows_paginated(ifid, 1, 100))
            print("----------------------------")
            print(self.get_active_host_flows_paginated(ifid, host, 0, 1, 100))
            print("----------------------------")
            print(self.get_active_l4_proto_flow_counters(ifid))
            print("----------------------------")
            print(self.get_active_l7_proto_flow_counters(ifid))
            print("----------------------------")
        except:
            raise ValueError("Invalid parameters specified")
