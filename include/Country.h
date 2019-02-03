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

#ifndef _COUNTRIES_H_
#define _COUNTRIES_H_

#include "ntop_includes.h"

class Country : public GenericHashEntry {
 private:
  /* Note: country name can be more then 2 chars, see
   * https://www.iso.org/iso-3166-country-codes.html
   */
  char *country_name;
  TrafficStats totstats;
  NetworkStats dirstats;

  inline void incStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    last_seen = t, totstats.incStats(t, num_pkts, num_bytes);    
  }

 public:
  Country(NetworkInterface *_iface, const char *country);
  ~Country();

  inline u_int16_t getNumHosts()               { return getUses();            }
  inline u_int32_t key()                       { return Utils::stringHash(country_name); }
  inline char* get_country_name()              { return country_name; }

  bool equal(const char *country);
  inline bool equal(Country *country)          { return equal(country->get_country_name()); }

  inline void incEgress(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    incStats(t, num_pkts, num_bytes);
    dirstats.incEgress(t, num_pkts, num_bytes, broadcast);
  }

  inline void incIngress(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    incStats(t, num_pkts, num_bytes);
    dirstats.incIngress(t, num_pkts, num_bytes, broadcast);
  }

  inline void incInner(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    incStats(t, num_pkts, num_bytes);
    dirstats.incInner(t, num_pkts, num_bytes, broadcast);
  }

  bool idle();
  void lua(lua_State* vm, DetailsLevel details_level, bool asListElement);
};

#endif /* _COUNTRIES_H_ */

