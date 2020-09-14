/*
 *
 * (C) 2013-20 - ntop.org
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
  NetworkInterface *iface;

 public:
  DB(NetworkInterface *_iface);
  virtual ~DB() {};

  inline void incNumExportedFlows(u_int64_t num = 1)        { exportedFlows += num;     };
  inline void incNumDroppedFlows(u_int32_t num = 1)         { droppedFlows += num;      };
  inline void incNumQueueDroppedFlows(u_int32_t num = 1)    { queueDroppedFlows += num; };

  inline u_int32_t getNumDroppedFlows()  const              { return(queueDroppedFlows + droppedFlows); };
  void updateStats(const struct timeval *tv);
  void checkPointCounters(bool drops_only);

  /* Pure Virtual Functions of a DB flow exporter */
  virtual bool dumpFlow(time_t when, Flow *f, char *json) = 0;
  virtual bool dumpFlowDirect(time_t when, ParsedFlow *f)   { return false; };
  virtual void startLoop() = 0;

  inline void startDBLoop()                                 { running = true; startLoop(); };
  inline int isRunning()                                    { return(running); };
  virtual void shutdown();
  virtual void flush() {};
  virtual void lua(lua_State* vm, bool since_last_checkpoint) const;
};

#endif /* _DB_CLASS_H_ */
