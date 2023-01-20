"""
Historical
====================================
The Historical class can be used to retrieve historical traffic data through the
REST API (https://www.ntop.org/guides/ntopng/api/rest/api_v2.html).
"""

import time
import pandas as pd

class Historical:
    """
    Historiacl provides access to historical information including flows and alerts
    
    :param ntopng_obj: The ntopng handle
    """
    def __init__(self, ntopng_obj, ifid=None):
        """
        Construct a new Historical object
        
        :param ntopng_obj: The ntopng handle
        """
        self.ntopng_obj      = ntopng_obj
        self.ifid            = ifid
        self.rest_v2_url     = "/lua/rest/v2"
        self.rest_pro_v2_url = "/lua/pro/rest/v2"

    def get_alert_type_counters(self, epoch_begin, epoch_end):
        """
        Return statistics about the number of alerts per alert type
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/type/counters.lua", { "ifid": self.ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_alert_severity_counters(self, epoch_begin, epoch_end):
        """
        Return statistics about the number of alerts per alert severity
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Statistics
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/severity/counters.lua", { "ifid": self.ifid, "status": "historical", "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_alerts(self, alert_family, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Run queries on the alert database
        
        :param alert_family: The alert family (flow, host, interface, etc)
        :type alert_family: string
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/list/alerts.lua", { "ifid": self.ifid, "alert_family": alert_family, "epoch_begin": epoch_begin, "epoch_end": epoch_end,
                                                                                          "select_clause": select_clause, "where_clause": where_clause,
                                                                                          "maxhits_clause": maxhits, "group_by_clause": group_by, "order_by_clause": order_by }))
    
    def get_alerts_stats(self, epoch_begin, epoch_end):
        """
        Return flow alerts stats
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Flow alert stats
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/alert/top.lua", { "ifid": self.ifid, "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flow_alerts_stats(self, epoch_begin, epoch_end):
        """
        Return flow alerts stats
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Flow alert stats
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/flow/alert/top.lua", { "ifid": self.ifid, "epoch_begin": epoch_begin, "epoch_end": epoch_end }))

    def get_flow_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return flow alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("flow", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_active_monitoring_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return  alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("active_monitoring", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_host_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return host alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("host", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_interface_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return interface alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("interface", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_mac_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return MAC alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("mac", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_network_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return Network alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("network", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_snmp_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return SNMP alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("snmp", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))
    
    def get_system_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return System alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("system", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))

    def get_user_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Return User alerts matching the specified criteria
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.get_alerts("user", epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by))

    def timeseries_to_pandas(self, rsp):
        interval = pd.interval_range(rsp['start'], periods=rsp['count'], freq=rsp['step'])
        data = {}
        for serie in rsp['series']:
            data[serie['label']] = serie['data']
        return pd.DataFrame(data, index=interval)

    def get_timeseries(self, ts_schema, ts_query, epoch_begin, epoch_end):
        """
        Return timeseries in a pandas DataFrame for a specified schema and query
        See https://pandas.pydata.org/docs/user_guide/10min.html
        
        :param ts_schema: The timeseries schema (e.g. 'host:traffic')
        :type ts_schema: string
        :param ts_query: The timeseries query (e.g. 'ifid:0,host:10.0.0.1')
        :type ts_query: string
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Timeseries data
        :rtype: object (pandas DataFrame)
        """
        rsp = self.ntopng_obj.post_request(self.rest_v2_url + "/get/timeseries/ts.lua", { "ts_schema": ts_schema, "ts_query": ts_query, "epoch_begin": epoch_begin, "epoch_end": epoch_end })
        return self.timeseries_to_pandas(rsp)

    def get_timeseries_metadata(self):
        """
        Return timeseries metadata (list all available timeseries)

        :return: Timeseries metadata
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_v2_url + "/get/timeseries/type/consts.lua", None))

    def get_host_timeseries(self, host_ip, ts_schema, epoch_begin, epoch_end):
        """
        Return timeseries data in a pandas DataFrame for a specified interface and host
        
        :param host_ip: The host IP
        :type host: string
        :param ts_schema: The timeseries schema
        :type ts_schema: string
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Timeseries data
        :rtype: object (pandas DataFrame)
        """
        return(self.get_timeseries(ts_schema, "ifid:"+str(self.ifid)+",host:"+host_ip, epoch_begin, epoch_end))

    def get_interface_timeseries(self, ts_schema, epoch_begin, epoch_end):
        """
        Return timeseries data in a pandas DataFrame for a specified interface
        
        :param ts_schema: The timeseries schema
        :type ts_schema: string
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :return: Timeseries data
        :rtype: object (pandas DataFrame)
        """
        return(self.get_timeseries(ts_schema, "ifid:"+str(self.ifid), epoch_begin, epoch_end))

    def get_flows(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by):
        """
        Run queries on the historical flows database (ClickHouse)
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param select_clause: Select clause (SQL syntax)
        :type select_clause: string
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param group_by: Group by condition (SQL syntax)
        :type group_by: string
        :param order_by: Order by condition (SQL syntax)
        :type order_by: string
        :return: Query result
        :rtype: object
        """
        return(self.ntopng_obj.post_request(self.rest_pro_v2_url + "/get/db/flows.lua", { "ifid": self.ifid, "epoch_begin": epoch_begin, "epoch_end": epoch_end, "select_clause": select_clause, "where_clause": where_clause, "maxhits_clause": maxhits, "group_by_clause": group_by, "order_by_clause": order_by }))

    def get_topk_flows(self, epoch_begin, epoch_end, max_hits, where_clause):
        """
        Retrieve Top-K from the historical flows database
        
        :param epoch_begin: Start of the time interval (epoch)
        :type epoch_begin: int
        :param epoch_end: End of the time interval (epoch)
        :type epoch_end: int
        :param maxhits: Max number of results (limit)
        :type maxhits: int
        :param where_clause: Where clause (SQL syntax)
        :type where_clause: string
        :return: Query result
        :rtype: object
        """
        return(self.ntopng_obj.request(self.rest_pro_v2_url + "/get/db/topk_flows.lua", {"ifid": self.ifid, "begin_time_clause": epoch_begin, "end_time_clause": epoch_end, "maxhits_clause": max_hits, "where_clause": where_clause }))

    def self_test(self, host):
        try:
            epoch_end   = int(time.time())
            epoch_begin = epoch_end - 3600

            print("Flow alerts ----------------------------")
            print(self.get_flow_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("Active Monitoring alerts ----------------------------")
            print(self.get_active_monitoring_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("Host alertss ----------------------------")
            print(self.get_host_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("Interface alerts ----------------------------")
            print(self.get_interface_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("MAC alerts ----------------------------")
            print(self.get_mac_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("Network alerts ----------------------------")
            print(self.get_network_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("SNMP alerts ----------------------------")
            print(self.get_snmp_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("System alerts ----------------------------")
            print(self.get_system_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("User alerts ----------------------------")
            print(self.get_user_alerts(epoch_begin, epoch_end, "*", None, 5, None, "epoch_begin"), None, None)
            print("Alert counters by type ----------------------------")
            print(self.get_alert_type_counters(epoch_begin, epoch_end))
            print("Alert counters by severity ----------------------------")
            print(self.get_alert_severity_counters(epoch_begin, epoch_end))
            print("Host traffic timeseries ----------------------------")
            print(self.get_timeseries("host:traffic", "ifid:"+str(self.ifid)+",host:"+host, epoch_begin, epoch_end))
            print("Interface traffic timeseries ----------------------------")
            print(self.get_interface_timeseries("iface:traffic_rxtx", epoch_begin, epoch_end))
            print("Interface score timeseries ----------------------------")
            print(self.get_interface_timeseries("iface:score", epoch_begin, epoch_end))
            print("Host flows ----------------------------")
            select_clause = "IPV4_SRC_ADDR,IPV4_DST_ADDR,PROTOCOL,IP_SRC_PORT,IP_DST_PORT,L7_PROTO,L7_PROTO_MASTER"
            where_clause  = "(IP_PROTOCOL_VERSION=4) AND IPV4_SRC_ADDR=(\""+host+"\") AND (PROTOCOL=6) "
            maxhits       = 10 # 10 records max
            print(self.get_flows( epoch_begin, epoch_end, select_clause, where_clause, maxhits, '', ''))
            print("----------------------------")
            print(self.get_topk_flows(epoch_begin, epoch_end, maxhits, None))
            print("----------------------------")
        except:
            raise ValueError("Invalid interface ID, host or parameters specified")
