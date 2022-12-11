#
#
# (C) 2022 - ntop.org
#
# host class
# https://www.ntop.org/guides/ntopng/api/rest/api_v2.html
#

class Host:
    def __init__(self, ntopng_obj):
        self.ntopng_obj      = ntopng_obj
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_active_hosts(self, ifid):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid}))

    def get_active_hosts_paginated(self, ifid, currentPage, perPage):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/active.lua", {"ifid": ifid, "currentPage": currentPage, "perPage": perPage}))

    def get_host_interfaces(self, host):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/interfaces.lua", { "host": host }))

    def get_host_data(self, ifid, host):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/data.lua", { "ifid": ifid, "host": host }))

    def get_host_l7_stats(self, ifid, host, vlan):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/l7/stats.lua", { "ifid": ifid, "host": host, "vlan": vlan, "breed": True, "ndpi_category": True, "collapse_stats": False }))

    def get_host_dscp_stats(self, ifid, host, vlan, direction_rcvd):
        if(direction_rcvd):
            direction = "recvd"
        else:
            direction = "sent"

        return(self.ntopng_obj.request(self.rest_v2_url + "/get/host/dscp/stats.lua", { "ifid": ifid, "host": host, "vlan": vlan, "direction": direction }))

    def get_top_local_talkers(self, ifid):
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/local/talkers.lua", { "ifid": ifid }))

    def get_top_remote_talkers(self, ifid):
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/interface/top/remote/talkers.lua", { "ifid": ifid }))

    def get_alert_types(self):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/consts.lua", None))

    def get_alert_severities(self):
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/consts.lua", None))

    def self_test(self, ifid, host):
        try:
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
            print(self.get_alert_types())
            print("----------------------------")
            print(self.get_alert_severities())
            print("----------------------------")
        except:
            raise ValueError("Invalid interfaceId specified")
