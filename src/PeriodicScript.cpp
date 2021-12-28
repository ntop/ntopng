/*
 *
 * (C) 2013-21 - ntop.org
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

/* ******************************************* */

PeriodicScript::PeriodicScript(const char* _path,		   
		   u_int32_t _periodicity_seconds,
		   u_int32_t _max_duration_seconds,
		   bool _align_to_localtime,
		   bool _exclude_viewed_interfaces,
		   bool _exclude_pcap_dump_interfaces,
		   ThreadPool* _pool) {    
  path = strdup(_path);
  periodicity = _periodicity_seconds;
  max_duration_secs = _max_duration_seconds;
  pool = _pool;
  align_to_localtime = _align_to_localtime;  
  exclude_viewed_interfaces = _exclude_viewed_interfaces;
  exclude_pcap_dump_interfaces = _exclude_pcap_dump_interfaces;
}

/* ******************************************* */

PeriodicScript::~PeriodicScript() {
    //if(path) free(path);
}
