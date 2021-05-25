/*
 *
 * (C) 2017-21 - ntop.org
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

#ifndef _HOST_POOL_STATS_H_
#define _HOST_POOL_STATS_H_

#include "ntop_includes.h"

class HostPoolStats : public GenericTrafficElement {
 private:
  std::string pool_name;
  nDPIStats *totalStats;
  time_t first_seen;   /**< Time of first seen. */
  time_t last_seen;    /**< Time of last seen. */
  bool mustReset;

 public:

  HostPoolStats(NetworkInterface *iface);

 HostPoolStats(const HostPoolStats &hps) : GenericTrafficElement(hps) {
    // NOTE: ndpiStats already copied by GenericTrafficElement
    totalStats = (hps.totalStats) ? new nDPIStats(*hps.totalStats) : NULL;
    first_seen = hps.first_seen;
    last_seen = hps.last_seen;
    mustReset = hps.mustReset;
    pool_name.assign(hps.pool_name);
  };

  virtual ~HostPoolStats() { if(totalStats) delete totalStats; };

  void updateSeen(time_t when);
  void updateName(const char * const _pool_name);

  void lua(lua_State* vm, NetworkInterface *iface);
  char* serialize(NetworkInterface *iface);
  void deserialize(NetworkInterface *iface, json_object *o);
  json_object* getJSONObject(NetworkInterface *iface);

  inline void incStats(time_t when, u_int16_t ndpi_proto,
		       u_int64_t sent_packets, u_int64_t sent_bytes,
		       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(sent_packets || rcvd_packets) {
      sent.incStats(when, sent_packets, sent_bytes), rcvd.incStats(when, rcvd_packets, rcvd_bytes);

      if(ndpiStats)
	ndpiStats->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);

      if(totalStats) {
	/* Unknown protocol is the only (dummy) entry used to keep track of cross protocol statistics */
	totalStats->incStats(when, NDPI_PROTOCOL_UNKNOWN, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      }
    }

    updateSeen((time_t)when);
  }

  inline void incCategoryStats(time_t when, ndpi_protocol_category_t category_id,
		       u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
    if(ndpiStats)
      ndpiStats->incCategoryStats(when, category_id, sent_bytes, rcvd_bytes);
  }

  inline void getStats(u_int64_t *bytes, u_int32_t *duration) {
    /* Returns the overall traffic statistics seen on this pool */
    if(bytes && totalStats)    *bytes = totalStats->getProtoBytes(NDPI_PROTOCOL_UNKNOWN);
    if(duration && totalStats) *duration = totalStats->getProtoDuration(NDPI_PROTOCOL_UNKNOWN);
  }

  inline void getProtoStats(u_int16_t ndpi_proto, u_int64_t *bytes, u_int32_t *duration) {
    *bytes = ndpiStats->getProtoBytes(ndpi_proto);
    *duration = ndpiStats->getProtoDuration(ndpi_proto);
  }

  inline void getCategoryStats(ndpi_protocol_category_t category, u_int64_t *bytes, u_int32_t *duration) {
    *bytes = ndpiStats->getCategoryBytes(category);
    *duration = ndpiStats->getCategoryDuration(category);
  }

  inline std::string getName() const { return pool_name; }

  inline bool needsReset() { return mustReset; }

  /* We only set a flag here to prevent concurrency issues */
  inline void resetStats() { mustReset = true; }

  /* To be called on the same thread as incStats */
  inline void checkStatsReset() {
    if(mustReset) {
      if(ndpiStats) ndpiStats->resetStats();
      if(totalStats) totalStats->resetStats();
      GenericTrafficElement::resetStats();

      mustReset = false;
    }
  }
};

#endif /* _HOST_POOL_STATS_H_ */
