"""
Interface
====================================
The Interface class can be used to access information about interface statistics through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

from ntopng.host import Host
from ntopng.historical import Historical

class Interface:
    """
    Interface provides information about a Network interface
    
    :param ntopng_obj: The ntopng handle
    """

    def __init__(self, ntopng_obj, ifid):
        """
        Construct a new Interface object
        
        :param ntopng_obj: The ntopng handle
        :type ifid: Ntopng
        :param ifid: The interface ID
        :type ifid: int
        """ 
        self.ntopng_obj = ntopng_obj
        self.ifid = ifid
        self.rest_v2_url = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"
        
    def get_data(self):
        """
        Return information about a Network interface
        
        :return: Information about the interface
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/data.lua", {"ifid": self.ifid}))
    
    def get_broadcast_domains(self):
        """
        Return information about broadcast domains on an interface
        
        :return: Information about broadcast domains
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/bcast_domains.lua", {"ifid": self.ifid}))
    
    def get_address(self):
        """
        Return the interface IP address(es)
        
        :return: The interface address(es)
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/address.lua", {"ifid": self.ifid}))

    def get_l7_stats(self, max_num_results):
        """
        Return statistics about Layer 7 protocols seen on an interface
        
        :param max_num_results: The maximum number of results to limit the output
        :type max_num_results: int
        :return: Layer 7 protocol statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/l7/stats.lua",
                              {"ifid": self.ifid,
                               'ndpistats_mode': 'count',
                               'breed': True,
                               'ndpi_category': True,
                               'all_values' : True,
                               'max_values': max_num_results,
                               'collapse_stats': False
                               }))
    
    def get_dscp_stats(self):
        """
        Return statistics about DSCP
        
        :return: DSCP statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/dscp/stats.lua", {"ifid": self.ifid}))

    def get_host(self, ip, vlan=None):
        """
        Return an Host instance
        
        :param ifid: The interface ID
        :type ifid: int
        :param ip: The host IP address
        :type ip: string
        :param vlan: The host VLAN ID (if any)
        :type vlan: int
        :return: The host instance
        :rtype: ntopng.Host
        """ 
        return Host(self.ntopng_obj, self.ifid, ip, vlan)

    def get_active_hosts(self):
        """
        Retrieve the list of active hosts for the specified interface
        
        :return: All active hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": self.ifid}))

    def get_active_hosts_paginated(self, currentPage, perPage):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": self.ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_top_local_talkers(self):
        """
        Return Top Local hosts generating more traffic
        
        :return: The top local hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/local/talkers.lua", { "ifid": self.ifid }))

    def get_top_remote_talkers(self):
        """
        Return Top Remote hosts generating more traffic
        
        :return: The top remote hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/remote/talkers.lua", { "ifid": self.ifid }))

    def get_active_flows_paginated(self, currentPage, perPage):
        """
        Retrieve the (paginated) list of active flows for the specified interface
        
        :param currentPage: The current page
        :type currentPage: int
        :param perPage: The number of results per page
        :type perPage: int
        :return: All active flows
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": self.ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_active_l4_proto_flow_counters(self):
        """
        Return statistics about active flows per Layer 4 protocol on an interface
        
        :return: Layer 4 protocol flows statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l4/counters.lua", {"ifid": self.ifid }))

    def get_active_l7_proto_flow_counters(self):
        """
        Return statistics about active flows per Layer 7 protocol on an interface
        
        :return: Layer 7 protocol flows statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l7/counters.lua", {"ifid": self.ifid }))

    def get_historical(self):
        """
        Return an Historical handle for the interface
        
        :return: The historical handle
        :rtype: ntopng.Historical
        """ 
        return Historical(self.ntopng_obj, self.ifid)

    def self_test(self):
        print(self.get_data())
        try:
            print("Broadcast Domains ----------------------------")
            print(self.get_broadcast_domains())
            print("Address ----------------------------")
            print(self.get_address())
            print("L7 Stats ----------------------------")
            max_num_records = 100
            print(self.get_l7_stats(max_num_records))
            print("DSCP Stats ----------------------------")
            print(self.get_dscp_stats())
            print("Active Hosts ----------------------------")
            print(self.get_active_hosts())
            print("Active Hosts (100) ----------------------------")
            print(self.get_active_hosts_paginated(1, 100))
            print("Top Local Talkers ----------------------------")
            print(self.get_top_local_talkers())
            print("Top Remote Talkers ----------------------------")
            print(self.get_top_remote_talkers())
            print("Active Flows (100) ----------------------------")
            print(self.get_active_flows_paginated(1, 100))
            print("L4 Flow Counters ----------------------------")
            print(self.get_active_l4_proto_flow_counters())
            print("L7 Flow Counters ----------------------------")
            print(self.get_active_l7_proto_flow_counters())
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID specified")

        

