/*
 *
 * (C) 2013-20 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _TIMESERIES_STATS_H_
#define _TIMESERIES_STATS_H_

class Host;

/* This class is specific for hosts and its used for two purposes:
 *  - Keep realtime local/remote hosts stats
 *  - Keep local/remote hosts timeseries stats in the form of HostTimeseriesPoint
 *
 * In order to add a totally new Host metric as class member:
 *  1. Add the metric to this class
 *  2. Edit TimeseriesStats::luaStats to push the metric to lua
 *  3. Possibly serialize in HostStats and deserialize in LocalHostStats
 *  4. The value is updated in HostStats. Usually the method is exposed by the Host (e.g. incNumMisbehavingFlows)
 *
 * In order to export a simple metric which does result in a class member (e.g. number of alerts of an Host):
 *  1. Add the metric to HostTimeseriesPoint
 *  2. Save the current the metric value into HostTimeseriesPoint copy constructor
 *  3. Edit HostTimeseriesPoint::lua to push the metric to lua
 *
 *  Note: Timeseries data is stored into HostTimeseriesPoint, which is populated
 *  in LocalHostStats::tsLua. */
class TimeseriesStats: public GenericTrafficElement {
 protected:
  Host *host;
  std::map<AlertType,u_int32_t> total_alerts;
  u_int32_t unreachable_flows_as_client, unreachable_flows_as_server;
  u_int32_t misbehaving_flows_as_client, misbehaving_flows_as_server;
  u_int32_t host_unreachable_flows_as_client, host_unreachable_flows_as_server;
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;
  u_int32_t num_flow_alerts;
  u_int64_t udp_sent_unicast, udp_sent_non_unicast;
  L4Stats l4stats;

 public:
  TimeseriesStats(Host * _host);
  /* NOTE: default copy constructor used by LocalHostStats::updateStats */
  virtual ~TimeseriesStats() {}

  inline Host* getHost() const { return(host); }
  inline void incNumMisbehavingFlows(bool as_client)   { if(as_client) misbehaving_flows_as_client++; else misbehaving_flows_as_server++; };
  inline void incNumUnreachableFlows(bool as_server) { if(as_server) unreachable_flows_as_server++; else unreachable_flows_as_client++; }
  inline void incNumHostUnreachableFlows(bool as_server) { if(as_server) host_unreachable_flows_as_server++; else host_unreachable_flows_as_client++; };
  inline void incNumFlowAlerts()                     { num_flow_alerts++; }
  inline void incTotalAlerts(AlertType alert_type)   { total_alerts[alert_type]++; };

  inline u_int32_t getTotalMisbehavingNumFlowsAsClient() const { return(misbehaving_flows_as_client);  };
  inline u_int32_t getTotalMisbehavingNumFlowsAsServer() const { return(misbehaving_flows_as_server);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsClient() const { return(unreachable_flows_as_client);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsServer() const { return(unreachable_flows_as_server);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsClient() const { return(host_unreachable_flows_as_client);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsServer() const { return(host_unreachable_flows_as_server);  };
  u_int32_t getTotalAlerts() const;
  inline u_int32_t getNumFlowAlerts() const { return(num_flow_alerts); };
  void luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua = false);
  virtual u_int16_t getNumActiveContactsAsClient() { return 0; }
  virtual u_int16_t getNumActiveContactsAsServer() { return 0; }
};

#endif
