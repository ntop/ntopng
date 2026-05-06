/*
 *
 * (C) 2013-26 - ntop.org
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

#ifndef _AUTONOMOUS_SYSTEM_H_
#define _AUTONOMOUS_SYSTEM_H_

// #define AS_LATENCY_DEBUG 1

#include "ntop_includes.h"

struct ExporterMapCmp {
  bool operator()(const std::pair<struct ndpi_in6_addr, u_int16_t>& a,
		  const std::pair<struct ndpi_in6_addr, u_int16_t>& b) const {
    // Compare IP addresses first
    int cmp = memcmp(&a.first, &b.first, sizeof(struct ndpi_in6_addr));
    if (cmp != 0) return(cmp < 0);

    // If IPs are the same, compare the other entry (u_int16_t)
    return(a.second < b.second);
  }
};

class AutonomousSystem : public GenericHashEntry,
                         public GenericTrafficElement,
                         public Score {
 private:
  u_int32_t asn;
  char* asname;
  u_int32_t round_trip_time;
  u_int32_t alerted_flows_as_client, alerted_flows_as_server;
  bool save_exporters_stats; /* Core ASN for which stats need to be saved */
  std::map<std::pair<struct ndpi_in6_addr, u_int16_t>, TrafficCounter, ExporterMapCmp> exporters_map;
#ifdef NTOPNG_PRO
  QoEStats qoe_stats;
#endif

#if defined(NTOPNG_PRO)
  time_t nextMinPeriodicUpdate;
#endif

  void incExportersStats(u_int64_t bytes_sent, u_int64_t bytes_rcvd,
                         struct ndpi_in6_addr *exporter_ip, u_int32_t in_index,
                         u_int32_t out_index);

  inline void incSentStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    if (first_seen == 0)
      first_seen = t, last_seen = iface->getTimeLastPktRcvd();
    sent.incStats(t, num_pkts, num_bytes);
  }
  inline void incRcvdStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    rcvd.incStats(t, num_pkts, num_bytes);
  }

#ifdef NTOPNG_PRO
  void updateBehaviorStats(const struct timeval* tv);
#endif

 public:
  AutonomousSystem(NetworkInterface* _iface, IpAddress* ipa);
  ~AutonomousSystem();

  void set_hash_entry_state_idle();

  inline u_int32_t getNumHosts() { return getUses(); }
  inline u_int32_t key() { return (asn); }
  inline u_int32_t get_asn() { return (asn); }
  inline char* get_asname() { return (asname ? asname : (char*)""); }

  bool equal(u_int32_t asn);

  inline void incStats(time_t when, u_int16_t proto_id, u_int64_t sent_packets,
                       u_int64_t sent_bytes, u_int64_t rcvd_packets,
                       u_int64_t rcvd_bytes, struct ndpi_in6_addr *exporter_ip,
                       u_int32_t in_index, u_int32_t out_index) {
    if (ndpiStats || (ndpiStats = new nDPIStats()))
      ndpiStats->incStats(when, proto_id, sent_packets, sent_bytes,
                          rcvd_packets, rcvd_bytes);
    incSentStats(when, sent_packets, sent_bytes);
    incRcvdStats(when, rcvd_packets, rcvd_bytes);
    incExportersStats(sent_bytes, rcvd_bytes, exporter_ip, out_index, in_index);
  }
  inline void incNumAlertedFlows(bool as_client) {
    if (as_client)
      alerted_flows_as_client++;
    else
      alerted_flows_as_server++;
  };

  void updateRoundTripTime(u_int32_t rtt_msecs);
  void lua(lua_State* vm, DetailsLevel details_level, bool asListElement,
           bool diff = false);

  virtual void updateStats(const struct timeval* tv);

  inline char* getSerializationKey(char* buf, u_int bufsize) {
    snprintf(buf, bufsize, AS_SERIALIZED_KEY, iface->get_id(), asn);
    return (buf);
  }
  inline u_int32_t getTotalAlertedNumFlowsAsClient() const {
    return (alerted_flows_as_client);
  };
  inline u_int32_t getTotalAlertedNumFlowsAsServer() const {
    return (alerted_flows_as_server);
  };
  inline void saveExporterStatsPrefs(bool _save_exporters_stats) {
    save_exporters_stats = _save_exporters_stats;

    if (!save_exporters_stats)
      exporters_map.clear(); /* Empty the map in case it's present */
  }
  void findExportersStats(u_int64_t bytes_sent, u_int64_t bytes_rcvd,
                          std::pair<struct ndpi_in6_addr, u_int16_t>* key);
#ifdef NTOPNG_PRO
  void incQoEStats(QoEType qoe_type) { qoe_stats.incQoEStats(qoe_type); };
#endif
};

#endif /* _AUTONOMOUS_SYSTEM_H_ */
