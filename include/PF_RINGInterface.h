/*
 *
 * (C) 2013-18 - ntop.org
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

#ifdef HAVE_PF_RING

#ifndef _PF_RING_NETWORK_INTERFACE_H_
#define _PF_RING_NETWORK_INTERFACE_H_

#include "ntop_includes.h"

#define PF_RING_MAX_SOCKETS 2

class PF_RINGInterface : public NetworkInterface {
 private:
  pfring *pfring_handle[PF_RING_MAX_SOCKETS];
  int num_pfring_handles;

  pfring_stat last_pfring_stat;
  u_int32_t getNumDroppedPackets();
  pfring *pfringSocketInit(const char *name);

 public:
  PF_RINGInterface(const char *name);
  ~PF_RINGInterface();

  void singlePacketPollLoop();
  void multiPacketPollLoop();
  inline bool areTrafficDirectionsSupported()  { return(true); };
  inline bool isDiscoverableInterface()        { return(true);                         };
  inline InterfaceType getIfType()             { return(interface_type_PF_RING);       };
  inline const char* get_type()                { return(CONST_INTERFACE_TYPE_PF_RING); };
  inline int get_num_pfring_handles()          { return(num_pfring_handles); };
  void startPacketPolling();
  void shutdown();
  bool set_packet_filter(char *filter);
};

#endif /* _PF_RING_NETWORK_INTERFACE_H_ */

#endif /* HAVE_PF_RING */

