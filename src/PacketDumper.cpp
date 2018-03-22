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

#include "ntop_includes.h"

/* ********************************************* */

PacketDumper::PacketDumper(NetworkInterface *i) {
  char *name = i->get_name();

  iface = i, file_id = 1, sampling_rate = 1;
  dump_end = 0, dumper = NULL;
  num_sampled_packets = num_dumped_packets = 0;
  num_dumped_unknown_packets = num_dumped_unknown_files = 0;
  sec_start = 0, max_pkts_per_file = 0, max_sec_per_file = 0;  
  num_pkts_cur_file = 0;

  if((name[0] == 'l') && (name[1] == 'o'))
    iface_type = DLT_NULL;
  else
    iface_type = i->get_datalink();
}

/* ********************************************* */

PacketDumper::~PacketDumper() {
  closeDump();
}

/* ********************************************* */

void PacketDumper::closeDump() {
  if(dumper) {
    pcap_dump_close(dumper);
    dumper = NULL;
  }
}

/* ********************************************* */

void PacketDumper::idle(time_t when) {
  checkClose(when);
}

/* ********************************************* */

bool PacketDumper::checkClose(time_t when) {
  if((num_pkts_cur_file > max_pkts_per_file)
     || (when > dump_end)) {
    closeDump();
    return(true);
  } else
    return(false);
}

/* ********************************************* */

void PacketDumper::openDump(time_t when, int sampling_rate,
                            unsigned int max_pkts_per_file,
                            unsigned int max_sec_per_file) {
  char pcap_path[MAX_PATH], hour_path[64];
  int len;
  time_t _when = when;

  if(dumper) return;

  sec_start = when;
  this->sampling_rate = sampling_rate;
  this->max_pkts_per_file = iface->getDumpTrafficMaxPktsPerFile();
  this->max_sec_per_file = iface->getDumpTrafficMaxSecPerFile();
  when -= when % 3600; /* Hourly directories */
  strftime(hour_path, sizeof(hour_path), "%Y/%m/%d/%H", localtime(&when));
  snprintf(pcap_path, sizeof(pcap_path), "%s/%d/pcap/%s",
	   ntop->get_working_dir(), iface->get_id(), hour_path);
  ntop->fixPath(pcap_path);
  
  Utils::mkdir_tree(pcap_path);
  
  len = strlen(pcap_path);
  snprintf(&pcap_path[len], sizeof(pcap_path)-len-1, "/%u_%u.pcap",
	   (unsigned int)when, file_id);
  
  if((dumper = pcap_dump_open(pcap_open_dead(iface_type, 16384 /* MTU */), pcap_path)) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create pcap file %s", pcap_path);  
  else {
    dump_end = _when + this->max_sec_per_file;
    num_pkts_cur_file = 0, file_id++;
    ntop->getTrace()->traceEvent(TRACE_INFO, "Created pcap dump %s [max pkts=%u][max duration=%u sec]", \
				 pcap_path, this->max_pkts_per_file, this->max_sec_per_file);
  }
}

/* ********************************************* */

void PacketDumper::dumpPacket(const struct pcap_pkthdr *h, const u_char *packet,
                              dump_reason reason, int sampling_rate,
                              unsigned int max_pkts_per_file, unsigned int max_sec_per_file) {

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(len=%u)", __FUNCTION__, h->len);
  if(!dumper) openDump(h->ts.tv_sec, sampling_rate, max_pkts_per_file, max_sec_per_file);

  int rate_dump_ok = /* reason != ATTACK || TODO: not yet supported */ (num_sampled_packets++ % sampling_rate) == 0;

  if(dumper && rate_dump_ok) {
    pcap_dump((u_char*)dumper, h, packet);
    num_dumped_packets++, num_pkts_cur_file++;
    checkClose(h->ts.tv_sec);
  }
}

/* ********************************************* */

void PacketDumper::lua(lua_State *vm) {
  lua_newtable(vm);
  lua_push_int_table_entry(vm, "num_dumped_pkts", get_num_dumped_packets());
  lua_push_int_table_entry(vm, "num_dumped_files", get_num_dumped_files());
  
  lua_pushstring(vm, "pkt_dumper");
  lua_insert(vm, -2);
  lua_settable(vm, -3);  
}
