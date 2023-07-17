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

#ifndef _FLOWS_HOST_INFO_H_
#define _FLOWS_HOST_INFO_H_

#include "ntop_includes.h"

/* *************************************** */

class FlowsHostInfo {
 private:
  IpAddress* ip;
  Host* host;

 public:
  FlowsHostInfo(IpAddress* _ip, Host* _host) { ip = _ip, host = _host; };

  char* getHostName(char* buf, u_int16_t buf_len);
  const char* getIP(char* buf, u_int16_t buf_len);
  const char* getIPHex(char* buf, u_int16_t buf_len);
  inline IpAddress* getIPaddr() { return(ip); }
  bool isHostInMem();
  u_int16_t getVLANId();
  Host* getHost();
};

#endif /* _FLOWS_HOST_INFO_H_ */
