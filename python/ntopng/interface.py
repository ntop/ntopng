"""
Interface
====================================
The Interface class can be used to access information about interface statistics through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

class Interface:
    """
    Interface provides information about a Network interface
    
    :param ntopng_obj: The ntopng handle
    """

    def __init__(self, ntopng_obj):
        """
        Construct a new Interface object
        
        :param ntopng_obj: The ntopng handle
        """ 
        self.ntopng_obj = ntopng_obj
        self.rest_v2_url = "/lua/rest/v2"
        
    def get_data(self, ifid):
        """
        Return information about a Network interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: Information about the interface
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/data.lua", {"ifid": ifid}))
    
    def get_broadcast_domains(self, ifid):
        """
        Return information about broadcast domains on an interface
        
        :param ifid: The interface ID
        :type ifid: int
        :return: Information about broadcast domains
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/bcast_domains.lua", {"ifid": ifid}))
    
    def get_address(self, ifid):
        """
        Return the interface IP address(es)
        
        :param ifid: The interface ID
        :type ifid: int
        :return: The interface address(es)
        :rtype: array
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/address.lua", {"ifid": ifid}))

    def get_l7_stats(self, ifid, max_num_results):
        """
        Return statistics about Layer 7 protocols seen on an interface
        
        :param ifid: The interface ID
        :type ifid: int
        :param max_num_results: The maximum number of results to limit the output
        :type max_num_results: int
        :return: Layer 7 protocol statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/l7/stats.lua",
                              {"ifid": ifid,
                               'ndpistats_mode': 'count',
                               'breed': True,
                               'ndpi_category': True,
                               'all_values' : True,
                               'max_values': max_num_results,
                               'collapse_stats': False
                               }))
    
    def get_dscp_stats(self, ifid):
        """
        Return statistics about DSCP
        
        :param ifid: The interface ID
        :type ifid: int
        :return: DSCP statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/dscp/stats.lua", {"ifid": ifid}))

    def self_test(self, ifid):
        print(self.get_data(ifid))
        try:
            print("----------------------------")
            print(self.get_broadcast_domains(ifid))
            print("----------------------------")
            print(self.get_address(ifid))
            print("----------------------------")
            max_num_records = 100
            print(self.get_l7_stats(ifid, max_num_records))
            print("----------------------------")
            print(self.get_dscp_stats(ifid))
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID specified")

        

