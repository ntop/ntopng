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

#define MAX_STRING_LEN 128

#include "ntop_includes.h"

class HostDetails {
    private:
        char* ip;
        char* mac_address;
        char* ip_hex;
        char* name;
        u_int16_t vlan_id;
        u_int64_t total_traffic;
        u_int8_t score;
        u_int32_t active_flows_as_server;
        u_int64_t host_key;
    
    public:
        HostDetails(char* _ip, char* _mac_address, u_int64_t _total_traffic, char* _ip_hex, u_int16_t _vlan_id, u_int8_t _score, u_int32_t _flows, char* _name, u_int64_t _host_key) {
            ip = strdup(_ip);
            mac_address = strdup(_mac_address);
            total_traffic = _total_traffic;
            ip_hex = strdup(_ip_hex);
            vlan_id = _vlan_id;
            score = _score;
            active_flows_as_server = _flows;
            name = strdup(_name);
            host_key = _host_key;
        };
        ~HostDetails() {
            if(ip_hex)
                free(ip_hex);
            if(ip)
                free(ip);
            if(mac_address)
                free(mac_address);
            if(name)
                free(name);
        };

        /* Getters */
        inline char* get_ip(char buf[MAX_STRING_LEN]) { 
            strncpy(buf, ip, MAX_STRING_LEN);
            return(buf); 
        };
        inline char* get_ip_hex(char buf[MAX_STRING_LEN]) { 
            strncpy(buf, ip_hex, MAX_STRING_LEN);
            return(buf); 
        };
        inline char* get_mac_address(char buf[MAX_STRING_LEN]) { 
            strncpy(buf, mac_address, MAX_STRING_LEN);
            return(buf); 
        };
        inline char* get_name( char buf[MAX_STRING_LEN]) {
            strncpy(buf, name, MAX_STRING_LEN);
            return(buf); 
        }
        inline u_int64_t get_total_traffic() { return(total_traffic); }; 
        inline u_int8_t get_score() { return(score); };
        inline u_int32_t get_active_flows_as_server() { return(active_flows_as_server); };
        inline u_int16_t get_vlan_id() { return(vlan_id); };
        inline u_int64_t get_host_key() { return(host_key); };

};

#endif /* _HOST_DETAILS_H_ */
