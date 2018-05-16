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

#ifndef _PCAP_INTERFACE_H_
#define _PCAP_INTERFACE_H_

#include "ntop_includes.h"

class PcapInterface : public NetworkInterface {
 private:
  pcap_t *pcap_handle;
  bool read_pkts_from_pcap_dump;
  FILE *pcap_list;

  pcap_stat last_pcap_stat;
  u_int32_t getNumDroppedPackets();

 public:
  PcapInterface(const char *name);
  ~PcapInterface();

  inline bool isDiscoverableInterface(){ return(getMDNS() != NULL); };
  inline InterfaceType getIfType() { return(read_pkts_from_pcap_dump ? interface_type_PCAP_DUMP : interface_type_PCAP); }
  inline const char* get_type()    { return(read_pkts_from_pcap_dump ? CONST_INTERFACE_TYPE_PCAP_DUMP : CONST_INTERFACE_TYPE_PCAP); };
  inline pcap_t* get_pcap_handle() { return(pcap_handle);   };
  inline void set_pcap_handle(pcap_t *p) { pcap_handle = p; };
  inline FILE*   get_pcap_list()   { return(pcap_list);     };
  void startPacketPolling();
  void shutdown();
  bool set_packet_filter(char *filter);
  inline bool read_from_pcap_dump() { return(read_pkts_from_pcap_dump); };
  inline void sendTermination()     { pcap_breakloop(pcap_handle); }
};

#endif /* _PCAP_INTERFACE_H_ */
