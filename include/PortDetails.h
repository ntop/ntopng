/*
 *
 * (C) 2019-24 - ntop.org
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

#ifndef _PORT_DETAILS_H_
#define _PORT_DETAILS_H_

#include "ntop_includes.h"

class PortDetails {
  private: 
    /* <srv_host_key, vlan_id > -> 1 */
    std::unordered_map<u_int64_t, u_int8_t> hosts;
  
  public:
    PortDetails(){};
    ~PortDetails(){};

    /* Getters */
    inline u_int16_t get_size() { return(hosts.size());};
    
    /* Setters */
    /* host_key = <srv_host_key, vlan_id> */
    void add_host(u_int64_t host_key) { 
      hosts[host_key] = (hosts.find(host_key) == hosts.end()) ? 1 : hosts[host_key]; 
    };
};

#endif /* _PORT_DETAILS_H_ */