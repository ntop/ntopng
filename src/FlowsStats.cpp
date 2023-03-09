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

#include "ntop_includes.h"

/* ************************************************ */

char* FlowsStats::getCliIP(char* buf, u_int len) {
  return(cli_ip->print(buf, len));
}

/* ************************************************ */

char* FlowsStats::getSrvIP(char* buf, u_int len) {
  return(srv_ip->print(buf, len));
}

/* ************************************************ */

char* FlowsStats::getCliName(char* buf, u_int len, u_int16_t cli_port) {
  if(cli_host) {
    return cli_host->get_name(buf, len, false);
  } else {
    snprintf(buf, len,"%s:%u",cli_ip->print(buf, len), cli_port);
    return(buf);
  }
}

/* ************************************************ */

char* FlowsStats::getSrvName(char* buf, u_int len, u_int16_t srv_port) {
  if(srv_host) {
    return srv_host->get_name(buf, len, false);
  } else {
    snprintf(buf, len, "%s:%u", srv_ip->print(buf, len), srv_port);
    return(buf);
  }
}

/* ************************************************ */

char* FlowsStats::getCliIPHex(char* buf, u_int len) {
  return(((IpAddress*)cli_ip)->get_ip_hex(buf, len));
}

/* ************************************************ */

char* FlowsStats::getSrvIPHex(char* buf, u_int len) {             
  return(((IpAddress*)srv_ip)->get_ip_hex(buf, len)); 
}
