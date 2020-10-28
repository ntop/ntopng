/*
 *
 * (C) 2013-20 - ntop.org
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
  bool read_pkts_from_pcap_dump, read_pkts_from_pcap_dump_done, emulate_traffic_directions;
  ProtoStats prev_stats_in, prev_stats_out;
  FILE *pcap_list;

  pcap_stat last_pcap_stat;
  u_int32_t getNumDroppedPackets();
  void cleanupPcapDumpDir();

  virtual void incEthStats(bool ingressPacket, u_int16_t proto, u_int32_t num_pkts,
			   u_int32_t num_bytes, u_int pkt_overhead) {
    if(!emulate_traffic_directions)
      ethStats.incStats(ingressPacket, num_pkts, num_bytes, pkt_overhead);

    ethStats.incProtoStats(proto, num_pkts, num_bytes);
  };

 public:
  PcapInterface(const char *name, u_int8_t ifIdx);
  virtual ~PcapInterface();

  bool isDiscoverableInterface()    { return(getMDNS() != NULL  && !isTrafficMirrored()); };
  virtual InterfaceType getIfType() const { return((read_pkts_from_pcap_dump && !reproducePcapOriginalSpeed()) ? interface_type_PCAP_DUMP : interface_type_PCAP); }
  virtual const char* get_type()    const { return((read_pkts_from_pcap_dump && !reproducePcapOriginalSpeed()) ? CONST_INTERFACE_TYPE_PCAP_DUMP : CONST_INTERFACE_TYPE_PCAP); };
  inline pcap_t* get_pcap_handle()  { return(pcap_handle);   };
  inline virtual bool areTrafficDirectionsSupported() { return(emulate_traffic_directions); };
  inline void set_pcap_handle(pcap_t *p) { pcap_handle = p; };
  inline FILE*   get_pcap_list()   { return(pcap_list);     };
  void startPacketPolling();
  bool set_packet_filter(char *filter);
  bool read_from_pcap_dump()      const { return(read_pkts_from_pcap_dump);        };
  bool read_from_pcap_dump_done() const { return(read_pkts_from_pcap_dump_done);   };
  void set_read_from_pcap_dump_done()   { read_pkts_from_pcap_dump_done = true;    };
  inline void sendTermination()     { if(pcap_handle) pcap_breakloop(pcap_handle); };
  bool reproducePcapOriginalSpeed() const;
  virtual void updateDirectionStats();
};

#endif /* _PCAP_INTERFACE_H_ */
