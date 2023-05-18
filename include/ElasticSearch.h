/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _ELASTIC_SEARCH_H_
#define _ELASTIC_SEARCH_H_

#include "ntop_includes.h"

class ElasticSearch : public DB {
 private:
  pthread_t esThreadLoop;
  std::atomic<u_int32_t> num_queued_elems;
  SPSCQueue<char *> *export_queue;

  bool reportDrops;
  time_t lastReportedDropsTime;

  char *es_template_push_url, *es_version_query_url;
  char es_version[2];
  bool es_version_inited;

  const char *get_es_version();
  const char *get_es_template();
  void shutdown();

 public:
  ElasticSearch(NetworkInterface *_iface);
  ~ElasticSearch();

  inline bool atleast_version_6() {
    const char *ver = get_es_version();

    return ver && strcmp(ver, "6") >= 0;
  };

  inline bool atleast_version_8() {
    const char *ver = get_es_version();

    return ver && strcmp(ver, "8") >= 0;
  };

  void pushEStemplate();
  void indexESdata();

  virtual bool dumpFlow(time_t when, Flow *f, char *json);
  virtual bool startQueryLoop();
};

#endif /* _ELASTIC_SEARCH_H_ */
