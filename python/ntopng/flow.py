#
#
# (C) 2022 - ntop.org
#
# flow class
# https://www.ntop.org/guides/ntopng/api/rest/api_v2.html
#

class Flow:
    def __init__(self, ntopng_obj):
        self.ntopng_obj      = ntopng_obj
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_active_flows_paginated(self, ifid, currentPage, perPage):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_active_host_flows_paginated(self, ifid, host, vlan, currentPage, perPage):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/active.lua", {"ifid": ifid, "host": host, "vlan": vlan, "currentPage": currentPage, "perPage": perPage}))

    def get_active_l4_proto_flow_counters(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l4/counters.lua", {"ifid": ifid }))

    def get_active_l7_proto_flow_counters(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/flow/l7/counters.lua", {"ifid": ifid }))

    def get_historical_flows(self, ifid, epoch_begin, epoch_end, max_hits, where_clause):
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/db/flows.lua", {"ifid": ifid, "begin_time_clause": epoch_begin, "end_time_clause": epoch_end, "maxhits_clause": max_hits, "where_clause": where_clause }))

    def get_historical_topk_flows(self, ifid, epoch_begin, epoch_end, max_hits, where_clause):
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/db/topk_flows.lua", {"ifid": ifid, "begin_time_clause": epoch_begin, "end_time_clause": epoch_end, "maxhits_clause": max_hits, "where_clause": where_clause }))



    def self_test(self, ifid, host):
        try:
            print(self.get_active_flows_paginated(ifid, 1, 100))
            print("----------------------------")
            print(self.get_active_host_flows_paginated(ifid, host, 0, 1, 100))
            print("----------------------------")
            print(self.get_active_l4_proto_flow_counters(ifid))
            print("----------------------------")
            print(self.get_active_l7_proto_flow_counters(ifid))
            print("----------------------------")
            print(self.get_historical_flows(ifid, 1641042000, 1735736400, 10, None))
            print("----------------------------")
            print(self.get_historical_topk_flows(ifid, 1641042000, 1735736400, 10, None))
            print("----------------------------")
        except:
            raise ValueError("Invalid parameters specified")
