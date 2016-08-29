/*
 *
 * (C) 2013-16 - ntop.org
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
  pthread_rwlock_t listMutex;
  bool reportDrops;
  u_int32_t elkDroppedFlowsQueueTooLong;
  u_int64_t elkExportedFlows, elkLastExportedFlows;
 public:
  ElasticSearch();
  ~ElasticSearch();
  inline u_int32_t numDroppedFlows() const { return elkDroppedFlowsQueueTooLong; };
  int sendToES(char* msg);
  void pushEStemplate();
  void indexESdata();
  void startFlowDump();

  void updateStats(const struct timeval *tv);
  void lua(lua_State* vm) const;
};


#endif /* _ELASTIC_SEARCH_H_ */
