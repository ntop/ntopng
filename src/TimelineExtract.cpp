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
  running = false;
  shutdown = false;
}

/* ********************************************* */

TimelineExtract::~TimelineExtract() {
  stop();
}

/* ********************************************* */

bool TimelineExtract::extract(NetworkInterface *iface,
    time_t from, time_t to, const char *bpf_filter) {
  bool completed = false;
#ifdef HAVE_PF_RING
  char path[MAX_PATH];
  char from_buff[24], to_buff[24];
  PacketDumper *dumper;
  pfring  *handle;
  u_char *packet = NULL;
  struct pfring_pkthdr header = { 0 };
  struct pcap_pkthdr *h;
  struct tm *time_info;
  char *filter; 
  int rc;
 
  shutdown = false;

  dumper = new PacketDumper(iface);

  if (dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize packet dumper");
    goto error;
  }

  filter = (char *) malloc(64 + (bpf_filter ? strlen(bpf_filter) : 0));

  if (filter == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory");
    goto delete_dumper;
  }

  filter[0] = '\0';

  if (bpf_filter && strlen(bpf_filter) > 0) 
    sprintf(filter, "%s and ", bpf_filter);

  time_info = localtime(&from);
  strftime(from_buff, sizeof(from_buff), "%Y-%m-%d %H:%M:%S", time_info);

  time_info = localtime(&to);
  strftime(to_buff, sizeof(to_buff), "%Y-%m-%d %H:%M:%S", time_info);

  sprintf(&filter[strlen(filter)], "start %s and end %s", from_buff, to_buff);

  snprintf(path, sizeof(path), "timeline:%s/%d/timeline", ntop->getPrefs()->get_pcap_dir(), iface->get_id());

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Extracting traffic from %s matching filter %s",
    path, filter);

  handle = pfring_open(path, 16384, 0);

  if (handle == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open %s", path);
    goto free_filter;
  }

  rc = pfring_set_bpf_filter(handle, filter);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set filter '%s' (%d)", filter, rc);
    goto close_pfring;
  }

  if (pfring_enable_ring(handle) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start extraction on %s", path);
    goto close_pfring;
  }

  while (!shutdown && !ntop->getGlobals()->isShutdown() && 
         (rc = pfring_recv(handle, &packet, 0, &header, 0)) > 0) {
    h = (struct pcap_pkthdr *) &header;
    dumper->dumpPacket(h, packet, UNKNOWN, 1 /* sampling */);
  }

  completed = true;

 close_pfring:
  pfring_close(handle);

 free_filter:
  free(filter);

 delete_dumper:
  delete dumper;

 error:
#endif

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Extraction %s",
    completed ? "completed" : "failed");

  return completed;
}

/* ********************************************* */

static void *extractionThread(void *ptr) {
  TimelineExtract *extr = (TimelineExtract *) ptr;

  extr->extract(
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

