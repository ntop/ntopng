/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef _DB_CLASS_H_
#define _DB_CLASS_H_

#include "ntop_includes.h"

#ifdef NTOPNG_PRO
class AggregatedFlow;
#endif

class DB {
 private:
  struct timeval lastUpdateTime;
  float exportRate;
  u_int64_t exportedFlows, lastExportedFlows;
  u_int32_t droppedFlows, queueDroppedFlows;
  u_int64_t checkpointExportedFlows;
  u_int32_t checkpointDroppedFlows, checkpointQueueDroppedFlows;

 protected:
  bool running;

  inline void incNumExportedFlows(u_int64_t num = 1)        { exportedFlows += num; };
  inline void incNumDroppedFlows(u_int32_t num = 1)         { droppedFlows += num; };
  inline void incNumQueueDroppedFlows(u_int32_t num = 1)    { queueDroppedFlows += num; };

 public:
  DB();
  virtual ~DB() {};
  inline u_int32_t getNumDroppedFlows()  const              { return(queueDroppedFlows + droppedFlows); };
  void updateStats(const struct timeval *tv);
  void checkPointCounters(bool drops_only);

  virtual bool dumpFlow(time_t when, Flow *f, char *json);  // TODO make this pure virtual
  virtual int exec_sql_query(lua_State *vm, char *sql,
			     bool limit_rows, bool wait_for_db_created = true);
  virtual void startDBLoop();
  inline int isRunning() { return running; };
  virtual void shutdown();
  virtual void flush() {};
  virtual bool createDBSchema(bool set_db_created = true) {
	  return false; /* override in non-schemaless subclasses */ };
  virtual bool createNprobeDBView() { return false; };
  virtual void lua(lua_State* vm, bool since_last_checkpoint) const;
#ifdef NTOPNG_PRO
  virtual bool dumpAggregatedFlow(time_t when, AggregatedFlow *f, bool is_top_aggregated_flow);
#endif
};

#endif /* _DB_CLASS_H_ */
