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

    def self_test(self):
        print(self.get_data())
        try:
            print("----------------------------")
            print(self.get_broadcast_domains())
            print("----------------------------")
            print(self.get_address())
            print("----------------------------")
            max_num_records = 100
            print(self.get_l7_stats(max_num_records))
            print("----------------------------")
            print(self.get_dscp_stats())
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID specified")

        

