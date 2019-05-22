/*
 *
 * (C) 2013-19 - ntop.org
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


class TimeseriesStats: public GenericTrafficElement {
 protected:
  Host *host;
  u_int32_t total_alerts;
  u_int32_t unreachable_flows_as_client, unreachable_flows_as_server;
  u_int32_t anomalous_flows_as_client, anomalous_flows_as_server;
  u_int32_t host_unreachable_flows_as_client, host_unreachable_flows_as_server;
  u_int64_t udp_sent_unicast, udp_sent_non_unicast;
  L4Stats l4stats;

 public:
  TimeseriesStats(Host * _host);
  virtual ~TimeseriesStats();

  inline void incNumAnomalousFlows(bool as_client)   { if(as_client) anomalous_flows_as_client++; else anomalous_flows_as_server++; };
  inline void incNumUnreachableFlows(bool as_server) { if(as_server) unreachable_flows_as_server++; else unreachable_flows_as_client++; }
  inline void incNumHostUnreachableFlows(bool as_server) { if(as_server) host_unreachable_flows_as_server++; else host_unreachable_flows_as_client++; };
  inline void incTotalAlerts() { total_alerts++; };

  inline u_int32_t getTotalAnomalousNumFlowsAsClient() const { return(anomalous_flows_as_client);  };
  inline u_int32_t getTotalAnomalousNumFlowsAsServer() const { return(anomalous_flows_as_server);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsClient() const { return(unreachable_flows_as_client);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsServer() const { return(unreachable_flows_as_server);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsClient() const { return(host_unreachable_flows_as_client);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsServer() const { return(host_unreachable_flows_as_server);  };
  inline u_int32_t getTotalAlerts() const { return(total_alerts); };
  void luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua = false);
  virtual u_int16_t getNumActiveContactsAsClient() { return 0; }
  virtual u_int16_t getNumActiveContactsAsServer() { return 0; }
};

#endif
