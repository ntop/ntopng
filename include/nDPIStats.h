/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _NDPI_STATS_H_
#define _NDPI_STATS_H_

#include "ntop_includes.h"

#define MAX_NDPI_PROTOS       (NDPI_MAX_SUPPORTED_PROTOCOLS + NDPI_MAX_NUM_CUSTOM_PROTOCOLS + 1)

/* *************************************** */

typedef struct {
  u_int64_t sent, rcvd;
} TrafficCounter;

typedef struct {
  TrafficCounter packets, bytes;
  u_int32_t duration /* sec */, last_epoch_update; /* useful to avoid multiple updates */
} ProtoCounter;

typedef struct {
  TrafficCounter bytes;
  u_int32_t duration /* sec */, last_epoch_update; /* useful to avoid multiple updates */
} CategoryCounter;

class NetworkInterface;

/* *************************************** */

class nDPIStats {
 private:
  ProtoCounter *counters[MAX_NDPI_PROTOS];
  /* NOTE: category counters are not dumped to redis right now, they are only used internally */
  CategoryCounter cat_counters[NDPI_PROTOCOL_NUM_CATEGORIES];

 public:
  nDPIStats();
  nDPIStats(const nDPIStats &stats);
  ~nDPIStats();

  void incStats(u_int32_t when, u_int16_t proto_id,
		u_int64_t sent_packets, u_int64_t sent_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes);

  void incCategoryStats(u_int32_t when, ndpi_protocol_category_t category_id,
          u_int64_t sent_bytes, u_int64_t rcvd_bytes);

  void print(NetworkInterface *iface);
  void lua(NetworkInterface *iface, lua_State* vm, bool with_categories = false);
  char* serialize(NetworkInterface *iface);
  json_object* getJSONObject(NetworkInterface *iface);
  json_object* getJSONObjectForCheckpoint(NetworkInterface *iface);
  void deserialize(NetworkInterface *iface, json_object *o);
  void sum(nDPIStats *s);

  inline u_int64_t getProtoBytes(u_int16_t proto_id) { 
    if((proto_id < MAX_NDPI_PROTOS) && counters[proto_id]) {
      TrafficCounter *tc = &counters[proto_id]->bytes;

      return(tc ? tc->sent+tc->rcvd : 0);
    } else 
      return(0); 
  }

  inline u_int32_t getProtoDuration(u_int16_t proto_id) {
    if((proto_id < MAX_NDPI_PROTOS) && counters[proto_id])
      return counters[proto_id]->duration;
    else
      return(0);
  }

  inline u_int64_t getCategoryBytes(ndpi_protocol_category_t category_id) {
    if (category_id < NDPI_PROTOCOL_NUM_CATEGORIES)
      return(cat_counters[category_id].bytes.sent + cat_counters[category_id].bytes.rcvd);
    else
      return(0);
  }

  inline u_int32_t getCategoryDuration(ndpi_protocol_category_t category_id) {
    if (category_id < NDPI_PROTOCOL_NUM_CATEGORIES)
      return(cat_counters[category_id].duration);
    else
      return(0);
  }

  void resetStats();
};

#endif /* _NDPI_STATS_H_ */
