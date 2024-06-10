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

#ifndef _PCAP_INTERFACE_H_
#define _PCAP_INTERFACE_H_

#include "ntop_includes.h"

class PcapInterface : public NetworkInterface {
 private:
  u_int8_t num_ifaces;
  char* pcap_ifaces[MAX_NUM_PCAP_INTERFACES]; /* Used when interfaces such as eth0,eth1 */
  pcap_t* pcap_handle[MAX_NUM_PCAP_INTERFACES];
  unsigned int ifname_indexes[MAX_NUM_PCAP_INTERFACES];
  int iface_datalink[MAX_NUM_PCAP_INTERFACES];
  char *pcap_path;
  bool read_pkts_from_pcap_dump, read_pkts_from_pcap_dump_done,
    emulate_traffic_directions, read_from_stdin_pipe,
    delete_pcap_when_done;
  ProtoStats prev_stats_in, prev_stats_out;
  FILE *pcap_list;
  struct timeval startTS, firstPktTS;
  
  pcap_stat last_pcap_stat;
  u_int32_t getNumDroppedPackets();
  void cleanupPcapDumpDir();

  virtual void incEthStats(bool ingressPacket, u_int16_t proto,
                           u_int32_t num_pkts, u_int32_t num_bytes,
                           u_int pkt_overhead) {
    if (read_from_stdin_pipe || (!emulate_traffic_directions))
      ethStats.incStats(ingressPacket, num_pkts, num_bytes, pkt_overhead);

    ethStats.incProtoStats(proto, num_pkts, num_bytes);
  };

 public:
  PcapInterface(const char *name, u_int8_t ifIdx, bool _delete_pcap_when_done);
  virtual ~PcapInterface();

  bool isDiscoverableInterface() {
    return (getMDNS() != NULL && !isTrafficMirrored());
  };
  virtual InterfaceType getIfType() const {
    return ((read_pkts_from_pcap_dump && !reproducePcapOriginalSpeed())
                ? interface_type_PCAP_DUMP
                : interface_type_PCAP);
  }
  virtual const char *get_type() const {
    return ((read_pkts_from_pcap_dump && !reproducePcapOriginalSpeed())
                ? CONST_INTERFACE_TYPE_PCAP_DUMP
                : CONST_INTERFACE_TYPE_PCAP);
  };
  inline pcap_t *get_pcap_handle(u_int8_t id) { return ((id < num_ifaces) ? pcap_handle[id] : NULL); };
  inline virtual bool areTrafficDirectionsSupported() {
    return (emulate_traffic_directions);
  };
  inline void set_pcap_handle(pcap_t *p, u_int8_t id) { if(id < num_ifaces) pcap_handle[id] = p; };
  inline FILE *get_pcap_list() { return (pcap_list); };
  void startPacketPolling();
  bool set_packet_filter(char *filter);
  bool read_from_stdin() const { return (read_from_stdin_pipe); };
  bool read_from_pcap_dump() const { return (read_pkts_from_pcap_dump); };
  bool read_from_pcap_dump_done() const {
    return (read_pkts_from_pcap_dump_done);
  };
  void set_read_from_pcap_dump_done() { read_pkts_from_pcap_dump_done = true; };
  void sendTermination();
  bool reproducePcapOriginalSpeed() const;
  virtual void updateDirectionStats();
  inline u_int8_t get_num_ifaces() { return(num_ifaces); }
  bool processNextPacket(pcap_t *pd, int32_t if_index, int datalink_type);
  bool reopen(u_int8_t iface_id);  
  unsigned int get_ifindex(int i) { return(ifname_indexes[i]); }
  int get_ifdatalink(int i)       { return(iface_datalink[i]); }
  char* getPcapIfaceName(int i)   { return(pcap_ifaces[i]);    }
};

#endif /* _PCAP_INTERFACE_H_ */
