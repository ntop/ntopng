/*
 *
 * (C) 2013-16 - ntop.org
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

#define MAX_PAGINATION_OPTIONS 32

class Paginator{
 private:
  char *max_hits, *to_skip, *sort_column, *a2z_sort_order;
  char *detailed_results;
  char *os_filter, *vlan_filter, *asn_filter, *local_network_filter;
  char *country_filter;
  char *l7proto_filter, *port_filter;
  void *pagination_options[MAX_PAGINATION_OPTIONS * 2/* option name + pointer*/];

 public:
  Paginator();
  ~Paginator();
  void readOptions(lua_State *L, int index);

  inline u_int16_t maxHits() const {
    return max_hits ? min(atoi(max_hits), CONST_MAX_NUM_HITS) : CONST_MAX_NUM_HITS;
  }
  inline u_int16_t toSkip() const {
    return to_skip ? atoi(to_skip) : 0;
  }
  inline bool a2zSortOrder() const {
    if(a2z_sort_order){
      return a2z_sort_order[0] == 't' ? true : false;
    } else {
      return true;
    }
  }
  inline char *sortColumn() const {
    if(sort_column)
      return sort_column;
    return (char*)"column_thpt";
  }
  inline bool detailedResults() const {
    if(detailed_results)
      return detailed_results;
    return false;
  }
  inline bool countryFilter(char **f) const {
    if(country_filter) {(*f) = country_filter; return true;} return false;
  }
  inline bool l7protoFilter(int *f) const {
    if(l7proto_filter){(*f) = atoi(l7proto_filter); return true;} return false;
  }
  inline bool portFilter(u_int16_t *f) const {
    if(port_filter){(*f) = atoi(port_filter); return true;} return false;
  }
  inline bool localNetworkFilter(int16_t *f) const {
    if(local_network_filter){(*f) = atoi(local_network_filter); return true;} return false;
  }
};

#endif
