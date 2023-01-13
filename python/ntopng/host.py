"""
Host
====================================
The Host class can be used to access information about hosts through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

class Host:
    """
    Host provides information about hosts
    
    :param ntopng_obj: The ntopng handle
    """
    def __init__(self, ntopng_obj):
        """
        Construct a new Host object
        
        :param ntopng_obj: The ntopng handle
        """
        self.ntopng_obj      = ntopng_obj
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_active_hosts(self, ifid):
        """
        Retrieve the list of active hosts for the specified interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: All active hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid}))

    def get_active_hosts_paginated(self, ifid, currentPage, perPage):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_host_interfaces(self, host):
        """
        Return all ntopng interfaces for a given host
        
        :param host: The host
        :type host: string
        :return: List of interfaces
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/interfaces.lua", { "host": host }))

    def get_host_data(self, ifid, host):
        """
        Return all available information about a single host
        
        :param ifid: The interface ID
        :type ifid: int
        :param host: The host
        :type host: string
        :return: Information about the host
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/data.lua", { "ifid": ifid, "host": host }))

    def get_host_l7_stats(self, ifid, host, vlan):
        """
        Return statistics about Layer 7 protocols for an host
        
        :param ifid: The interface ID
        :type ifid: int
        :param host: The host
        :type host: string
        :param vlan: The host VLAN ID (if any)
        :type vlan: string
        :return: Layer 7 protocol statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/l7/stats.lua", { "ifid": ifid, "host": host, "vlan": vlan, "breed": True, "ndpi_category": True, "collapse_stats": False }))

    def get_host_dscp_stats(self, ifid, host, vlan, direction_rcvd):
        """
        Return statistics about DSCP per traffic direction for an host
        
        :param ifid: The interface ID
        :type ifid: int
        :param host: The host
        :type host: string
        :param vlan: The host VLAN ID (if any)
        :type vlan: string
        :param direction_rcvd: The traffic direction (True for received traffic, False for sent)
        :type direction_rcvd: boolean
        :return: DSCP statistics
        :rtype: object
        """
        if(direction_rcvd):
            direction = "recvd"
        else:
            direction = "sent"

        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/dscp/stats.lua", { "ifid": ifid, "host": host, "vlan": vlan, "direction": direction }))

    def get_top_local_talkers(self, ifid):
        """
        Return Top Local hosts generating more traffic
        
        :param ifid: The interface ID
        :type ifid: int
        :return: The top local hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/local/talkers.lua", { "ifid": ifid }))

    def get_top_remote_talkers(self, ifid):
        """
        Return Top Remote hosts generating more traffic
        
        :param ifid: The interface ID
        :type ifid: int
        :return: The top remote hosts
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/remote/talkers.lua", { "ifid": ifid }))

    def self_test(self, ifid, host):
        try:
            print("----------------------------")
            print(self.get_active_hosts(ifid))
            print("----------------------------")
            print(self.get_active_hosts_paginated(ifid, 1, 100))
            print("----------------------------")
            print(self.get_host_interfaces(host))
            print("----------------------------")
            print(self.get_host_data(ifid, host))
            print("----------------------------")
            print(self.get_host_l7_stats(ifid, host, 0))
            print("----------------------------")
            print(self.get_host_dscp_stats(ifid, host, 0, True))
            print("----------------------------")
            print(self.get_top_local_talkers(ifid))
            print("----------------------------")
            print(self.get_top_remote_talkers(ifid))
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID or host specified")
