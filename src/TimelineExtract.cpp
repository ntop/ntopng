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

TimelineExtract::TimelineExtract() {
  extraction.id = 0;
  status_code = 0;
  running = false;
  shutdown = false;
}

/* ********************************************* */

TimelineExtract::~TimelineExtract() {
  stop();
}

/* ********************************************* */

#ifdef HAVE_PF_RING
pfring *TimelineExtract::openTimeline(NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter) {
  char timeline_path[MAX_PATH];
  char from_buff[24], to_buff[24];
  pfring *handle = NULL;
  char *filter; 
  struct tm *time_info;
  int rc;

  snprintf(timeline_path, sizeof(timeline_path), "timeline:%s/%d/timeline", ntop->getPrefs()->get_pcap_dir(), iface->get_id());

  handle = pfring_open(timeline_path, 16384, 0);

  if (handle == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open %s", timeline_path);
    status_code = 4; /* Unable to open timeline */
    goto error;
  }

  filter = (char *) malloc(64 + (bpf_filter ? strlen(bpf_filter) : 0));

  if (filter == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory");
    status_code = 3; /* Memory allocation failure */
    goto close_pfring;
  }

  filter[0] = '\0';

  time_info = localtime(&from);
  strftime(from_buff, sizeof(from_buff), "%Y-%m-%d %H:%M:%S", time_info);

  time_info = localtime(&to);
  strftime(to_buff, sizeof(to_buff), "%Y-%m-%d %H:%M:%S", time_info);

  sprintf(filter, "start %s and end %s", from_buff, to_buff);

  if (bpf_filter && strlen(bpf_filter) > 0) 
    sprintf(&filter[strlen(filter)], " and %s", bpf_filter);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running extraction from '%s' matching filter '%s'",
    timeline_path, filter);

  rc = pfring_set_bpf_filter(handle, filter);

  free(filter);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set filter '%s' (%d)", filter, rc);
    status_code = 5; /* Unable to set filter */
    goto close_pfring;
  }

  if (pfring_enable_ring(handle) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start extraction on %s", timeline_path);
    status_code = 6; /* Unable to open timeline */
    goto close_pfring;
  }

  return handle;

close_pfring:
  pfring_close(handle);

error:
  return NULL;
}
#endif

/* ********************************************* */

bool TimelineExtract::extractToDisk(u_int32_t id, NetworkInterface *iface,
    time_t from, time_t to, const char *bpf_filter) {
  bool completed = false;
#ifdef HAVE_PF_RING
  char out_path[MAX_PATH];
  PacketDumper *dumper;
  pfring  *handle;
  u_char *packet = NULL;
  struct pfring_pkthdr header = { 0 };
  struct pcap_pkthdr *h;
 
  shutdown = false;
  stats.packets = stats.bytes = 0;
  status_code = 1; /* default: unexpected error */

  snprintf(out_path, sizeof(out_path), "%s/%u/extr_pcap/%u", ntop->getPrefs()->get_pcap_dir(), iface->get_id(), id);

  dumper = new PacketDumper(iface, out_path);

  if (dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize packet dumper");
    status_code = 2; /* Unable to initialize dumper */
    goto error;
  }

  handle = openTimeline(iface, from, to, bpf_filter);

  if (handle == NULL)
    goto delete_dumper;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping traffic to '%s'", out_path);

  while (!shutdown && !ntop->getGlobals()->isShutdown() && 
         pfring_recv(handle, &packet, 0, &header, 0) > 0) {
    h = (struct pcap_pkthdr *) &header;
    dumper->dumpPacket(h, packet);
    stats.packets++;
    stats.bytes += sizeof(struct pcap_disk_pkthdr) + h->caplen;
  }

  status_code = 0; /* Successfully completed */
  completed = true;

  pfring_close(handle);

 delete_dumper:
  delete dumper;

 error:
#else
  status_code = 7; /* No PF_RING support */
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Extraction #%u %s",
    id, completed ? "completed" : "failed");

  return completed;
}

/* ********************************************* */

bool TimelineExtract::extractLive(struct mg_connection *conn, NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter) {
  bool completed = false;
#ifdef HAVE_PF_RING
  pfring  *handle;
  u_char *packet = NULL;
  struct pfring_pkthdr h = { 0 };
  struct pcap_file_header pcaphdr;
  struct pcap_disk_pkthdr pkthdr;
  bool http_client_disconnected = false;

  stats.packets = stats.bytes = 0;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running live extraction");

  Utils::init_pcap_header(&pcaphdr, iface);

  if (mg_write_async(conn, &pcaphdr, sizeof(pcaphdr)) < (int) sizeof(pcaphdr))
    http_client_disconnected = true;

  handle = openTimeline(iface, from, to, bpf_filter);

  if (handle == NULL)
    goto error;

  while (!http_client_disconnected && 
         !ntop->getGlobals()->isShutdown() && 
         pfring_recv(handle, &packet, 0, &h, 0) > 0) {

    pkthdr.ts.tv_sec = h.ts.tv_sec;
    pkthdr.ts.tv_usec = h.ts.tv_usec,
    pkthdr.caplen = h.caplen;
    pkthdr.len = h.len;

    if (mg_write_async(conn, &pkthdr, sizeof(pkthdr)) < (int) sizeof(pkthdr) ||
        mg_write_async(conn, packet, h.caplen) < (int) h.caplen)
      http_client_disconnected = true;

    usleep(100); /* FIXX it seems that sendint too fast with mg_write_async breaks the connection */

    stats.packets++;
    stats.bytes += sizeof(struct pcap_disk_pkthdr) + h.caplen;
  }

  completed = true;
  pfring_close(handle);

 error:
#endif
  ntop->getTrace()->traceEvent(TRACE_INFO, "Live extraction %s %s", 
    completed ? "completed" : "failed", http_client_disconnected ? "(disconnected)" : "");
  return completed;
}

/* ********************************************* */

static void *extractionThread(void *ptr) {
  TimelineExtract *extr = (TimelineExtract *) ptr;

  extr->extractToDisk(
    extr->getID(),
    extr->getNetworkInterface(), 
    extr->getFrom(),
    extr->getTo(),
    extr->getFilter()
  );

  extr->cleanupJob();
  return NULL;
}

/* ********************************************* */

void TimelineExtract::runExtractionJob(u_int32_t id, NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter) {

  running = true;

  extraction.id = id;
  extraction.iface = iface;
  extraction.from = from;
  extraction.to = to;
  extraction.bpf_filter = strdup(bpf_filter);

  pthread_create(&extraction_thread, NULL, extractionThread, (void *) this);
}

/* ********************************************* */

void TimelineExtract::stopExtractionJob(u_int32_t id) {
  if (running && extraction.id == id)
    stop();
}

/* ********************************************* */

void TimelineExtract::stop() {
  void *res;

  shutdown = true;

  if (running)
    pthread_join(extraction_thread, &res);
}

/* ********************************************* */

void TimelineExtract::cleanupJob() {
  if (extraction.bpf_filter) free(extraction.bpf_filter);

  running = false;
}

/* ********************************************* */

void TimelineExtract::getStatus(lua_State* vm) {
  lua_newtable(vm);

  if (extraction.id) {
    lua_newtable(vm);

    lua_push_int_table_entry(vm, "id", extraction.id);
    lua_push_int_table_entry(vm, "extracted_pkts", stats.packets);
    lua_push_int_table_entry(vm, "extracted_bytes", stats.bytes);
    lua_push_int_table_entry(vm, "status", status_code);

    lua_pushnumber(vm, extraction.id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ********************************************* */

