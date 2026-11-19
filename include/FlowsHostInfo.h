/*
 *
 * (C) 2019-26 - ntop.org
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
  /* A copy of the address: the flow (or the host) it belongs to can be
     purged while the aggregated stats are still being sorted and returned */
  IpAddress ip;
  bool has_ip;
  Host* host;

 public:
  FlowsHostInfo(IpAddress* _ip, Host* _host);

  char* getHostName(char* buf, u_int16_t buf_len);
  const char* getIP(char* buf, u_int16_t buf_len);
  const char* getIPHex(char* buf, u_int16_t buf_len);
  inline IpAddress* getIPaddr() { return (has_ip ? &ip : NULL); }
  bool isHostInMem();
  u_int16_t getVLANId();
  Host* getHost();
};

#endif /* _FLOWS_HOST_INFO_H_ */
