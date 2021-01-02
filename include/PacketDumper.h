/*
 *
 * (C) 2015-21 - ntop.org
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
  pcap_dumper_t *dumper;
  u_int32_t file_id;
  u_int16_t iface_type;
  u_int64_t num_dumped_packets;
  u_int64_t max_bytes_per_file;
  u_int64_t num_bytes_cur_file;
  char *out_path;

 public:
  PacketDumper(NetworkInterface *i, const char *path);
  ~PacketDumper();

  void init(NetworkInterface *i);
  void closeDump();
  void idle();
  bool checkClose();
  bool openDump();
  void dumpPacket(const struct pcap_pkthdr *h, const u_char *packet);
  inline u_int64_t get_num_dumped_packets() { return num_dumped_packets; }
  inline u_int64_t get_num_dumped_files()   { return file_id; }
};

#endif /* _PACKET_DUMPER_H_ */
