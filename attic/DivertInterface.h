/*
 *
 * (C) 2016-18 - ntop.org
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

#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__)

#ifndef _DIVERT_INTERFACE_H_
#define _DIVERT_INTERFACE_H_

#include "ntop_includes.h"

class DivertInterface : public NetworkInterface {
 private:
  int sock, port;

 public:
  DivertInterface(const char *name);
  ~DivertInterface();

  inline const char* get_type()                 { return(CONST_INTERFACE_TYPE_DIVERT); };
  inline InterfaceType getIfType()              { return(interface_type_DIVERT);       };
  inline int get_fd()                           { return(sock);                        };
  void startPacketPolling();
};

#endif /* _DIVERT_INTERFACE_H_ */

#endif /* defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__) */

