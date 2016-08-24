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

class Paginator {
 private:
  u_int16_t max_hits, to_skip;
  bool a2z_sort_order, detailed_results;
  char *sort_column, *country_filter, *host_filter;
  int l7proto_filter;
  u_int16_t port_filter;
  int16_t local_network_filter;

 public:
  Paginator();
  ~Paginator();
  void readOptions(lua_State *L, int index);

  inline u_int16_t maxHits() const    { return(min_val(max_hits, CONST_MAX_NUM_HITS));  }
  inline u_int16_t toSkip() const     { return(to_skip);  }
  inline bool a2zSortOrder() const    { return(a2z_sort_order); }
  inline char *sortColumn() const     { return(sort_column); }
  inline bool detailedResults() const { return(detailed_results); }

  inline bool countryFilter(char **f) const {
    if(country_filter) { (*f) = country_filter; return true; } return false;
  }

  inline bool hostFilter(char **f) const {
    if(host_filter) { (*f) = host_filter; return true; } return false;
  }

  inline bool l7protoFilter(int *f) const {
    if(l7proto_filter) { (*f) = l7proto_filter; return true; } return false;
  }

  inline bool portFilter(u_int16_t *f) const {
    if(port_filter) { (*f) = port_filter; return true; } return false;
  }

  inline bool localNetworkFilter(int16_t *f) const {
    if(local_network_filter) { (*f) = local_network_filter; return true; } return false;
  }
};

#endif
