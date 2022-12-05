#
#
# (C) 2022 - ntop.org
#
# historical class (timeseries, alerts and flows)
# https://www.ntop.org/guides/ntopng/api/rest/api_v2.html
#

import time

class Historical:
    def __init__(self, ntopng_obj):
        self.ntopng_obj      = ntopng_obj
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_alert_type_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flows_type_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_alert_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flows_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flows_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_timeseries(self, ts_schema, ts_query, epoch_begin, epoch_end):
        return(self.ntopng_obj.post_request(self.rest_v2_url + "/get/timeseries/ts.lua", { "ts_schema": ts_schema, "ts_query": ts_query, "epoch_begin": epoch_begin, "epoch_end": epoch_end }))


    def self_test(self, ifid, host):
        try:
            epoch_end   = int(time.time())
            epoch_begin = epoch_end - 3600

            print(self.get_alert_type_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_flows_type_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_alert_severity_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_flows_severity_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_timeseries("host:traffic", "ifid:"+str(ifid)+",host:"+host, epoch_begin, epoch_end))
            print("----------------------------")
            return
        
            print("----------------------------")
        except:
            raise ValueError("Invalid interfaceId specified")
