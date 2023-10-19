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

#ifndef _CATEGORY_COUNTER_H_
#define _CATEGORY_COUNTER_H_

#include "ntop_includes.h"

class CategoryCounter {
 private:
  TrafficCounter bytes;
  u_int32_t duration /* sec */,
      last_epoch_update; /* useful to avoid multiple updates */

 public:
  CategoryCounter();
  CategoryCounter(const CategoryCounter &c);

  void incStats(u_int32_t when, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  inline void sum(CategoryCounter c) {
    bytes = c.bytes, duration += c.duration;
  };

  void lua(NetworkInterface *iface, lua_State *vm, u_int16_t category_id,
           bool tsLua);
  void addProtoJson(json_object *my_object, NetworkInterface *iface,
                    ndpi_protocol_category_t category_id);
  inline u_int64_t getTotalBytes() { return (bytes.getTotal()); }
  inline u_int32_t getDuration() { return (duration); }
  void resetStats();
};

#endif /* _CATEGORY_COUNTER_H_ */
