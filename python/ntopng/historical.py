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

    #
    # Alerts
    #
    def get_alert_type_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_alerts_type_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_alert_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flows_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flows_severity_counters(self, ifid, epoch_begin, epoch_end):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    #
    # Timseseries
    #
    # For ts_schema see get_available_timeseries()
    def get_timeseries(self, ts_schema, ts_query, epoch_begin, epoch_end):
        return(self.ntopng_obj.post_request(self.rest_v2_url + "/get/timeseries/ts.lua", { "ts_schema": ts_schema, "ts_query": ts_query, "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    # List all available timeseries
    def get_timeseries_metadata(self):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/timeseries/type/consts.lua", None))

    def get_host_timeseries(self, ifid, host_ip, ts_schema, epoch_begin, epoch_end):
        return(self.get_timeseries(ts_schema, "ifid:"+str(ifid)+",host:"+host_ip, epoch_begin, epoch_end))

    def get_interface_timeseries(self, ifid, ts_schema, epoch_begin, epoch_end):
        return(self.get_timeseries(ts_schema, "ifid:"+str(ifid), epoch_begin, epoch_end))

    #
    # Flows
    #
    # Raw call for gettting historical data from ClickHouse
    def get_flows(self, ifid, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        return(self.ntopng_obj.post_request(self.rest_pro_v2_url + "/get/db/flows.lua", { "ifid": ifid, "epoch_begin": epoch_begin, "epoch_end": epoch_end,
                                                                                          "select_clause": select_clause, "where_clause": where_clause,
                                                                                          "maxhits_clause": maxhits, "group_by_clause": group_by, "order_by_clause": order_by }))


    def self_test(self, ifid, host):
        try:
            epoch_end   = int(time.time())
            epoch_begin = epoch_end - 3600

            print(self.get_alert_type_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_alerts_type_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_alert_severity_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_flows_severity_counters(ifid, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_timeseries("host:traffic", "ifid:"+str(ifid)+",host:"+host, epoch_begin, epoch_end))
            print("----------------------------")
            print(self.get_interface_timeseries(ifid, "iface:score", epoch_begin, epoch_end))
            print("----------------------------")

            select_clause = "IPV4_SRC_ADDR,IPV4_DST_ADDR,PROTOCOL,IP_SRC_PORT,IP_DST_PORT,L7_PROTO,L7_PROTO_MASTER"
            where_clause  = "(PROTOCOL=6) AND IPV4_SRC_ADDR=(\""+host+"\")"
            maxhits       = 10 # 10 records max
            print(self.get_flows(ifid, epoch_begin, epoch_end, select_clause, where_clause, maxhits))
            print("----------------------------")
            return

            print("----------------------------")
        except:
            raise ValueError("Invalid interfaceId specified")
