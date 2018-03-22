/*
 *
 * (C) 2015-18 - ntop.org
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

#ifndef _PACKET_DUMPER_H_
#define _PACKET_DUMPER_H_

#include "ntop_includes.h"

class PacketDumper {
 private:
  NetworkInterface *iface;
  time_t dump_end;
  pcap_dumper_t *dumper;
  u_int64_t num_sampled_packets, num_dumped_packets, num_dumped_unknown_packets;
  u_int32_t file_id, num_dumped_unknown_files;
  u_int16_t iface_type;
  time_t sec_start;
  int sampling_rate;
  unsigned int max_pkts_per_file, max_sec_per_file;
  unsigned int num_pkts_cur_file;

 public:
  PacketDumper(NetworkInterface *i);
  ~PacketDumper();

  void closeDump();
  void idle(time_t when);
  bool checkClose(time_t when);
  void openDump(time_t when, int sampling_rate, unsigned int max_pkts_per_file,
                unsigned int max_sec_per_file);
  void dumpPacket(const struct pcap_pkthdr *h, const u_char *packet,
                  dump_reason reason, int sampling_rate,
                  unsigned int max_pkts_per_file, unsigned int max_sec_per_file);
  inline u_int64_t get_num_dumped_packets() { return(num_dumped_packets+num_dumped_unknown_packets); }
  inline u_int64_t get_num_dumped_files()   { return(file_id+num_dumped_unknown_files); }
  void lua(lua_State *vm);
  inline void incUnknownPacketDump(u_int16_t num_pkts) {
    num_dumped_unknown_packets += num_pkts, num_dumped_unknown_files++;
  }
};

#endif /* _PACKET_DUMPER_H_ */
