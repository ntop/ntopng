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

#include "ntop_includes.h"

/* *************************************** */

void HostsPorts::mergeSrvPorts(std::unordered_map<u_int16_t, ndpi_protocol> *new_server_ports) {
    std::unordered_map<u_int16_t, PortDetails*>::iterator server_ports_it;

    for (auto new_server_ports_it = new_server_ports->begin(); new_server_ports_it != new_server_ports->end(); ++new_server_ports_it ) {
        server_ports_it = server_ports.find(new_server_ports_it->first);
        if(server_ports_it == server_ports.end()) {
            PortDetails *port_details = new (std::nothrow) PortDetails();
            if(port_details) {
                port_details->set_protocol(new_server_ports_it->second);
                server_ports[new_server_ports_it->first] = port_details;
            }
        } else {
            server_ports_it->second->inc_h_count();

        }
    }
                  
}