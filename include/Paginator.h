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

#ifndef _PAGINATOR_H_
#define _PAGINATOR_H_

#include "ntop_includes.h"

class Paginator {
 protected:
  u_int16_t max_hits, to_skip;
  bool a2z_sort_order;
  bool detailed_results /* deprecated, use DetailsLevel instead */;
  char *sort_column, *country_filter, *host_filter;
  int l7proto_filter, l7category_filter;
  u_int16_t port_filter;
  int16_t local_network_filter;
  u_int16_t vlan_id_filter;
  u_int8_t ip_version /* Either 4 or 6 */;
  int8_t unicast_traffic, unidirectional_traffic, alerted_flows, filtered_flows;
  u_int32_t asn_filter;
  u_int32_t deviceIP;
  u_int16_t inIndex, outIndex;
  u_int16_t pool_filter;
  u_int8_t *mac_filter;
  DetailsLevel details_level;
  bool details_level_set;
  LocationPolicy client_mode;
  LocationPolicy server_mode;

 public:
  Paginator();
  virtual ~Paginator();
  virtual void readOptions(lua_State *L, int index);

  inline u_int16_t maxHits() const    { return(min_val(max_hits, CONST_MAX_NUM_HITS));  }
  inline u_int16_t toSkip() const     { return(to_skip);  }
  inline bool a2zSortOrder() const    { return(a2z_sort_order); }
  inline char *sortColumn() const     { return(sort_column); }
  inline bool detailedResults() const { return(detailed_results); }

  inline bool getDetailsLevel(DetailsLevel *f) const {
    if(details_level_set) { (*f) = details_level; return true; } return false;
  }

  inline bool countryFilter(char **f) const {
    if(country_filter) { (*f) = country_filter; return true; } return false;
  }

  inline bool hostFilter(char **f) const {
    if(host_filter) { (*f) = host_filter; return true; } return false;
  }

  inline bool l7protoFilter(int *f) const {
    if(l7proto_filter >= 0) { (*f) = l7proto_filter; return true; } return false;
  }

  inline bool l7categoryFilter(int *f) const {
    if(l7category_filter >= 0) { (*f) = l7category_filter; return true; } return false;
  }

  inline bool portFilter(u_int16_t *f) const {
    if(port_filter) { (*f) = port_filter; return true; } return false;
  }

  inline bool localNetworkFilter(int16_t *f) const {
    if(local_network_filter) { (*f) = local_network_filter; return true; } return false;
  }

  inline bool vlanIdFilter(u_int16_t *f) const {
    if(vlan_id_filter) { (*f) = vlan_id_filter; return true; } return false;
  }
  
  inline bool ipVersion(u_int8_t *f) const {
    if(ip_version) { (*f) = ip_version; return true; } return false;
  }

  inline bool deviceIpFilter(u_int32_t *f) const {
    if(deviceIP) { (*f) = deviceIP; return true; } return false;
  }

  inline bool inIndexFilter(u_int16_t *f) const {
    if(inIndex) { (*f) = inIndex; return true; } return false;
  }

  inline bool outIndexFilter(u_int16_t *f) const {
    if(outIndex) { (*f) = outIndex; return true; } return false;
  }

  inline bool poolFilter(u_int16_t *f) const {
    if(pool_filter != ((u_int16_t)-1)) { (*f) = pool_filter; return true; } return false;
  }

  inline bool macFilter(u_int8_t **f) const {
    if(mac_filter) { (*f) = mac_filter; return true; } return false;
  }

  inline bool clientMode(LocationPolicy *f) const {
    if(client_mode) { (*f) = client_mode; return true; } return false;
  }

  inline bool serverMode(LocationPolicy *f) const {
    if(server_mode) { (*f) = server_mode; return true; } return false;
  }

  inline bool asnFilter(u_int32_t *f) const {
    if(asn_filter != (u_int32_t)-1) { (*f) = asn_filter; return true; } return false;
  }

  inline bool unidirectionalTraffic(bool *f) const {
    if(unidirectional_traffic != -1) { (*f) = (unidirectional_traffic==1) ? true : false; return true; } return false;
  }

  inline bool unicastTraffic(bool *f) const {
    if(unicast_traffic != -1) { (*f) = (unicast_traffic==1) ? true : false; return true; } return false;
  }

  inline bool alertedFlows(bool *f) const {
    if(alerted_flows != -1) { (*f) = (alerted_flows==1) ? true : false; return true; } return false;
  }

  inline bool filteredFlows(bool *f) const {
    if(filtered_flows != -1) { (*f) = (filtered_flows==1) ? true : false; return true; } return false;
  }
};

#endif
