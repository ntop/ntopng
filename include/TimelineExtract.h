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

#ifndef _TIMELINE_EXTRACT_H_
#define _TIMELINE_EXTRACT_H_

#include "ntop_includes.h"

class TimelineExtract {
 private:
  pthread_t extraction_thread;
  bool running;
  bool shutdown;
  int status_code;

  struct {
    u_int64_t packets;
    u_int64_t bytes;
  } stats;

  struct {
    NetworkInterface *iface;
    u_int32_t id;
    time_t from;
    time_t to;
    char *bpf_filter;
    u_int64_t max_bytes;
    const char * timeline_path;
  } extraction;

#ifdef HAVE_PF_RING
  pfring *openTimeline(const char * const timeline_path, time_t from, time_t to, const char * const bpf_filter);
  pfring *openTimelineFromInterface(NetworkInterface *iface, time_t from, time_t to, const char * const bpf_filter);
#endif

 public:
  TimelineExtract();
  ~TimelineExtract();
  inline NetworkInterface *getNetworkInterface() { return extraction.iface; };
  inline u_int32_t getID() { return extraction.id; };
  inline time_t getFrom() { return extraction.from; };
  inline time_t getTo() { return extraction.to; };
  inline const char *getFilter() { return extraction.bpf_filter; };
  inline const char *getTimelinePath() { return extraction.timeline_path; };
  inline const u_int64_t getMaxBytes() { return extraction.max_bytes; };
  inline bool isRunning() { return running; };
  void stop();
  /* sync */
  bool extractToDisk(u_int32_t id, NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter, u_int64_t max_bytes, const char * const timeline_path);
  bool extractLive(struct mg_connection *conn, NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter, const char * const timeline_path);
  /* async */
  void runExtractionJob(u_int32_t id, NetworkInterface *iface, time_t from, time_t to, const char *bpf_filter, u_int64_t max_bytes, const char * const timeline_path);
  void stopExtractionJob(u_int32_t id);
  void cleanupJob();
  void getStatus(lua_State* vm);
};

#endif /* _TIMELINE_EXTRACT_H_ */
