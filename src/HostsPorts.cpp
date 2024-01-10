/*
 *
 * (C) 2013-24 - ntop.org
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

void HostsPorts::add_srv_port(u_int64_t key, u_int64_t host_key) {
  if (srv_ports.find(key) == srv_ports.end()) {
    /* port not found case */
    PortDetails* portDetails = new (std::nothrow) PortDetails();
    if (portDetails) {
      portDetails->add_host(host_key);
      srv_ports[key] = portDetails;
    }
  } else {
    /* port already present so add just the host */
    srv_ports[key]->add_host(host_key);
  }
}

/* *************************************** */
