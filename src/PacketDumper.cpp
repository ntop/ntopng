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

#include "ntop_includes.h"

/* ********************************************* */

PacketDumper::PacketDumper(NetworkInterface *i, const char *path) {
  init(i);
  out_path = strdup(path); 
}

/* ********************************************* */

PacketDumper::~PacketDumper() {
  closeDump();
  if (out_path) free(out_path);
}

/* ********************************************* */

void PacketDumper::init(NetworkInterface *i) {
  char *name = i->get_name();

  iface = i;
  file_id = 0;
  dumper = NULL;
  num_dumped_packets = 0;
  max_bytes_per_file = 0;
  num_bytes_cur_file = 0;
  out_path = NULL;

  if(strcmp(name, "lo") == 0)
    iface_type = DLT_NULL;
  else if(!i->isPacketInterface())
    iface_type = DLT_EN10MB;
  else
    iface_type = i->get_datalink();
}

/* ********************************************* */

void PacketDumper::closeDump() {
  if(dumper) {
    pcap_dump_close(dumper);
    dumper = NULL;
  }
}

/* ********************************************* */

void PacketDumper::idle() {
  checkClose();
}

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

  if (dumper != NULL)
    return true;

  max_bytes_per_file = ntop->getPrefs()->get_max_extracted_pcap_bytes();

  Utils::mkdir_tree(out_path);
  snprintf(pcap_path, sizeof(pcap_path), "%s/%u.pcap", out_path, file_id+1);
  
  dumper = pcap_dump_open(pcap_open_dead(iface_type, 16384 /* MTU */), pcap_path);

  if (dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create pcap file %s", pcap_path);
    return false;
  } 

  file_id++;
  num_bytes_cur_file = 0;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Created pcap dump %s [max bytes=%u]",
    pcap_path, max_bytes_per_file);

  return true;
}

/* ********************************************* */

void PacketDumper::dumpPacket(const struct pcap_pkthdr *h, const u_char *packet) {
  if (dumper == NULL) {
    openDump();
    if (dumper == NULL)
      return;
  }

  pcap_dump((u_char*)dumper, h, packet);

  num_dumped_packets++;
  num_bytes_cur_file += sizeof(struct pcap_disk_pkthdr) + h->caplen;

  checkClose();
}

/* ********************************************* */

