#
#
# (C) 2022 - ntop.org
#
# interface class
# https://www.ntop.org/guides/ntopng/api/rest/api_v2.html
#

class Interface:
    def __init__(self, ntopng_obj):
        self.ntopng_obj = ntopng_obj
        self.rest_v2_url = "/lua/rest/v2"
        
    def get_data(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/data.lua", {"ifid": ifid}))
    
    def get_broadcast_domains(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/bcast_domains.lua", {"ifid": ifid}))
    
    def get_address(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/address.lua", {"ifid": ifid}))

    def get_l7_stats(self, ifid, max_num_results):
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
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/interface/dscp/stats.lua", {"ifid": ifid}))

    def get_interfaces(self):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/ntopng/interfaces.lua", None))

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
            print(self.get_interfaces())
            print("----------------------------")
        except:
            raise ValueError("Invalid interfaceId specified")

        

