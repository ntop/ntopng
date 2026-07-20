/*
 *
 * (C) 2015-26 - ntop.org
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

/* ********************************************* */

PacketDumper::PacketDumper(NetworkInterface* i, const char* path) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  init(i);
  out_path = strdup(path);
}

/* ********************************************* */

PacketDumper::~PacketDumper() {
  closeDump();
  if (out_path) free(out_path);
}

/* ********************************************* */

void PacketDumper::init(NetworkInterface* _iface) {
  iface = _iface;

  file_id = 0;
  dumper = NULL;
  num_dumped_packets = 0;
  max_bytes_per_file = 0;
  num_bytes_cur_file = 0;
  out_path = NULL;

#ifdef HAVE_NEDGE
  iface_type = DLT_EN10MB;
#else
  if (strcmp(iface->get_name(), "lo") == 0)
    iface_type = DLT_NULL;
  else if (!iface->isPacketInterface())
    iface_type = DLT_EN10MB;
  else
    iface_type = iface->get_datalink();
#endif
}

/* ********************************************* */

void PacketDumper::closeDump() {
  if (dumper) {
    pcap_dump_close(dumper);
    dumper = NULL;
  }
}

/* ********************************************* */

void PacketDumper::idle() { checkClose(); }

/* ********************************************* */

bool PacketDumper::checkClose() {
  if (num_bytes_cur_file >= max_bytes_per_file) {
    closeDump();
    return true;
  }

  return false;
}

/* ********************************************* */

bool PacketDumper::openDump() {
  char pcap_path[MAX_PATH];
  pcap_t *dead_pcap;

  if (dumper != NULL) return true;

  max_bytes_per_file = ntop->getPrefs()->get_max_extracted_pcap_bytes();
  max_files = ntop->getPrefs()->get_max_extracted_pcap_files();

#ifdef HAVE_NEDGE
  if (file_id >= max_files) file_id = 0;
#else
  if (max_files && file_id >= max_files) return false; /* Max files exceeded */
#endif

  Utils::mkdir_tree(out_path);
  snprintf(pcap_path, sizeof(pcap_path), "%s/%u.pcap", out_path, file_id + 1);

  dead_pcap = pcap_open_dead(iface_type, 16384 /* MTU */);
  dumper = pcap_dump_open(dead_pcap, pcap_path);
  if (dead_pcap) pcap_close(dead_pcap);

  if (dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create pcap file %s",
                                 pcap_path);
    return false;
  }

  file_id++;
  num_bytes_cur_file = 0;

  ntop->getTrace()->traceEvent(TRACE_INFO,
                               "Created pcap dump %s [max bytes=%u]", pcap_path,
                               max_bytes_per_file);

  return true;
}

/* ********************************************* */

bool PacketDumper::dumpPacket(const struct pcap_pkthdr* h,
                              const u_char* packet) {
  if (dumper == NULL) {
    openDump();
    if (dumper == NULL) return false;
  }

  pcap_dump((u_char*)dumper, h, packet);

  num_dumped_packets++;
  num_bytes_cur_file += sizeof(struct pcap_disk_pkthdr) + h->caplen;

  checkClose();

  return true;
}

/* ********************************************* */

bool PacketDumper::dumpL3Packet(const u_char* l3, u_int32_t l3_len,
                                struct timeval* ts, u_char* dst_mac,
                                u_char* src_mac, int ip_version) {
  u_char buffer[CONST_DEFAULT_MAX_PACKET_SIZE];
  struct ndpi_ethhdr* eth;
  struct pcap_pkthdr h;

  h.ts.tv_sec = ts->tv_sec;
  h.ts.tv_usec = ts->tv_usec;

  h.len = sizeof(struct ndpi_ethhdr) + l3_len;

  if (sizeof(struct ndpi_ethhdr) + l3_len > sizeof(buffer))
    l3_len = sizeof(buffer) - sizeof(struct ndpi_ethhdr);

  h.caplen = sizeof(struct ndpi_ethhdr) + l3_len;

  eth = (struct ndpi_ethhdr*)buffer;

  if (ip_version == 4)
    eth->h_proto = htons(ETHERTYPE_IP);
  else
    eth->h_proto = htons(ETHERTYPE_IPV6);

  if (dst_mac != NULL)
    memcpy(eth->h_dest, dst_mac, sizeof(eth->h_dest));
  else
    memset(eth->h_dest, 0, sizeof(eth->h_dest));

  if (src_mac != NULL)
    memcpy(eth->h_source, src_mac, sizeof(eth->h_source));
  else
    memset(eth->h_source, 0, sizeof(eth->h_source));

  memcpy(&buffer[sizeof(struct ndpi_ethhdr)], l3, l3_len);

  return dumpPacket(&h, buffer);
}

/* ********************************************* */
