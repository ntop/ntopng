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

#ifndef _HOSTS_PORTS_ANALYSIS_H_
#define _HOSTS_PORTS_ANALYSIS_H_

#include "ntop_includes.h"

class HostsPortsAnalysis {

    private:
        u_int16_t port = 0;
        int l7_protocol_id = 0;
        u_int32_t l4_protocol_id = 0;
        std::unordered_map<u_int64_t, HostDetails *> *hosts_details;
    
    public:
        HostsPortsAnalysis(){
            hosts_details = new (std::nothrow) std::unordered_map<u_int64_t, HostDetails *>;
        };
        ~HostsPortsAnalysis() {
            std::unordered_map<u_int64_t, HostDetails *>::iterator it;
            for (it = hosts_details->begin(); it != hosts_details->end(); ++it) 
                delete it->second;
            if(hosts_details)
                delete hosts_details;
        };


        /* Getters */
        inline u_int16_t get_port() { return(port); };
        inline std::unordered_map<u_int64_t, HostDetails *>* get_hosts_details() { return(hosts_details); };
        inline int get_l7_proto() { return(l7_protocol_id); };
        inline u_int32_t get_l4_proto() { return(l4_protocol_id); };
        
        /* Setters */
        void add_host_details(HostDetails *host_details);
        inline void set_port(u_int16_t _port) { port = _port; };
        inline void set_l7_proto(int l7_proto) { l7_protocol_id = l7_proto; };
        inline void set_l4_proto(u_int32_t l4_proto) { l4_protocol_id = l4_proto; };
};

#endif /* _HOSTS_PORTS_ANALYSIS_H_ */

