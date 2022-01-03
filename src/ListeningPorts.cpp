/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef HAVE_NEDGE

/* ************************************************ */

void ListeningPorts::parsePortInfo(json_object *z, std::map <u_int16_t, ListeningPortInfo> *info) {
  json_object *p;
  ListeningPortInfo pinfo;
  u_int16_t port = 0;
  enum json_type o_type = json_object_get_type(z);
  
  if(o_type == json_type_array) {
    for(u_int i = 0; i < json_object_array_length(z); i++) {
      json_object *e = json_object_array_get_idx(z, i);
      
      if(json_object_object_get_ex(e, "port", &p))
	port = (u_int32_t)json_object_get_int(p);
      
      if(port != 0) {
	if(json_object_object_get_ex(e, "pkg", &p))  
	  pinfo.package = json_object_to_json_string(e);
	
	if(json_object_object_get_ex(e, "proc", &p))  
	  pinfo.process = json_object_to_json_string(e);
	
	(*info)[port] = pinfo;
      }
    }
  }
}

/* ************************************************ */

void ListeningPorts::parsePorts(json_object *z) {
  enum json_type o_type = json_object_get_type(z);

  if(o_type == json_type_object) {
    json_object *p;

    if(json_object_object_get_ex(z, "tcp4", &p))
      parsePortInfo(p, &tcp4);

    if(json_object_object_get_ex(z, "udp4", &p))
      parsePortInfo(p, &udp4);

    if(json_object_object_get_ex(z, "tcp6", &p))
      parsePortInfo(p, &tcp6);

    if(json_object_object_get_ex(z, "udp6", &p))
      parsePortInfo(p, &udp6);
  }
}

#endif
