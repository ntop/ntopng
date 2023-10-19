/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _OBSERVATION_POINT_H
#define _OBSERVATION_POINT_H

#include "ntop_includes.h"

class Score;

class ObservationPoint : public GenericHashEntry,
                         public GenericTrafficElement,
                         public Score {
 private:
  /* Note: country name can be more then 2 chars, see
   * https://www.iso.org/iso-3166-country-codes.html
   */
  u_int16_t obs_point;
  NetworkStats dirstats;
  u_int64_t num_flows;
  ndpi_bitmap *exporter_list;
  std::atomic<bool> delete_requested;
  bool remove_entry;

  inline void incSentStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    if (first_seen == 0)
      first_seen = t, last_seen = iface->getTimeLastPktRcvd();
    sent.incStats(t, num_pkts, num_bytes);
  }

  inline void incRcvdStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    rcvd.incStats(t, num_pkts, num_bytes);
  }

 public:
  ObservationPoint(NetworkInterface *_iface, u_int16_t obs_point);
  ~ObservationPoint();

  void set_hash_entry_state_idle();
  bool is_hash_entry_state_idle_transition_ready();

  inline u_int64_t getNumFlows() { return num_flows; }
  inline u_int16_t getNumHosts() { return getUses(); }
  inline u_int32_t key() { return obs_point; }
  inline u_int32_t getObsPoint() { return obs_point; }
  inline void addProbeIp(u_int32_t probe_ip) {
    ndpi_bitmap_set(exporter_list, probe_ip);
  }

  bool equal(u_int16_t _obs_point) { return (obs_point == _obs_point); }
  inline bool equal(ObservationPoint *_obs_point) {
    return (obs_point == _obs_point->key());
  }

  inline void incFlows() { num_flows++; }

  inline void incStats(time_t when, u_int16_t proto_id, u_int64_t sent_packets,
                       u_int64_t sent_bytes, u_int64_t rcvd_packets,
                       u_int64_t rcvd_bytes) {
    if (!remove_entry) {
      if (ndpiStats || (ndpiStats = new nDPIStats()))
        ndpiStats->incStats(when, proto_id, sent_packets, sent_bytes,
                            rcvd_packets, rcvd_bytes);
      incSentStats(when, sent_packets, sent_bytes);
      incRcvdStats(when, rcvd_packets, rcvd_bytes);
    }
  }

  virtual void updateStats(const struct timeval *tv);

  void lua(lua_State *vm, DetailsLevel details_level, bool asListElement);

  inline void serialize(json_object *obj, DetailsLevel details_level) {
    if (!remove_entry) {
      GenericHashEntry::getJSONObject(obj, details_level);
      GenericTrafficElement::getJSONObject(obj, iface);
      json_object_object_add(obj, "flows", json_object_new_int64(num_flows));
    }
  }
  inline char *getSerializationKey(char *buf, uint bufsize) {
    snprintf(buf, bufsize, OBS_POINT_SERIALIZED_KEY, iface->get_id(),
             obs_point);
    return (buf);
  }

  inline void setDeleteRequested(bool to_be_deleted) {
    delete_requested = to_be_deleted;
  }
  inline void deleteObsStats() { remove_entry = true; }
};

#endif /* _OBSERVATION_POINT_H */
