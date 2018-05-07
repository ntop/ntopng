/*
 *
 * (C) 2013-18 - ntop.org
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

class ElasticSearch {
 private:
  pthread_t esThreadLoop;
  u_int num_queued_elems;
  struct string_list *head, *tail;
  Mutex listMutex;
  bool reportDrops;
  struct timeval lastUpdateTime;
  u_int32_t elkDroppedFlowsQueueTooLong;
  u_int64_t elkExportedFlows, elkLastExportedFlows;
  float elkExportRate;
  u_int64_t checkpointDroppedFlows, checkpointExportedFlows; /* Those will hold counters at checkpoints */

  char *es_template_push_url, *es_version_query_url;
  char *es_version;
  const char * const get_es_version();
 public:
  ElasticSearch();
  ~ElasticSearch();
  void checkPointCounters(bool drops_only) {
    if(!drops_only)
      checkpointExportedFlows = elkExportedFlows;
    checkpointDroppedFlows = elkDroppedFlowsQueueTooLong;
  };
  inline bool atleast_version_6() {
    const char * const ver = get_es_version();
    return ver && strcmp(ver, "6") >= 0;
  };
  inline u_int32_t numDroppedFlows() const { return elkDroppedFlowsQueueTooLong; };
  int sendToES(char* msg);
  void pushEStemplate();
  void indexESdata();
  void startFlowDump();

  void updateStats(const struct timeval *tv);
  void lua(lua_State* vm, bool since_last_checkpoint) const;
};


#endif /* _ELASTIC_SEARCH_H_ */
