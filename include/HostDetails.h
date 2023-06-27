/*
 *
 * (C) 2019-23 - ntop.org
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

#ifndef _HOST_DETAILS_H_
#define _HOST_DETAILS_H_

#include "ntop_includes.h"

class HostDetails {
 private:
  char* ip;
  char* mac_address;
  char* mac_manufacturer;
  char* ip_hex;
  char* name;
  u_int16_t vlan_id;
  u_int64_t total_traffic;
  u_int8_t score;
  u_int32_t active_flows_as_server;
  u_int64_t host_key;
  u_int16_t port;
    
 public:
  HostDetails(char* _ip, char* _mac_address, char* _mac_manufacturer, u_int64_t _total_traffic,
	      char* _ip_hex, u_int16_t _vlan_id, u_int8_t _score, u_int32_t _flows,
	      char* _name, u_int64_t _host_key) {
    ip = _ip ? strdup(_ip) : NULL;
    mac_address = _mac_address ? strdup(_mac_address) : NULL;
    mac_manufacturer = _mac_manufacturer ? strdup(_mac_manufacturer) : NULL;
    total_traffic = _total_traffic;
    ip_hex = _ip_hex ? strdup(_ip_hex) : NULL;
    vlan_id = _vlan_id;
    score = _score;
    active_flows_as_server = _flows;
    name = _name ? strdup(_name) : NULL;
    host_key = _host_key;
  };
  
  ~HostDetails() {
    if(ip_hex)      free(ip_hex);
    if(ip)          free(ip);
    if(mac_address) free(mac_address);
    if(name)        free(name);
    if(mac_manufacturer) free(mac_manufacturer);
  };

  /* Getters */
  inline char* get_ip()               { return(ip ? ip : (char*)""); };
  inline char* get_ip_hex()           { return(ip_hex ? ip_hex : (char*)""); };
  inline char* get_mac_address()      {  return(mac_address ? mac_address : (char*)""); };
  inline char* get_mac_manufacturer() {  return(mac_manufacturer ? mac_manufacturer : (char*)""); };  
  inline char* get_name()             {  return(name ? name : (char*)"");   };

  inline u_int64_t get_total_traffic() { return(total_traffic); }; 
  inline u_int8_t  get_score() { return(score); };
  inline u_int32_t get_active_flows_as_server() { return(active_flows_as_server); };
  inline u_int16_t get_vlan_id() { return(vlan_id); };
  inline u_int64_t get_host_key() { return(host_key); };
  inline u_int16_t get_port() { return(port); };

  /* Setters */
  inline void set_port(u_int16_t _port) { port = _port; }; 

};

#endif /* _HOST_DETAILS_H_ */
