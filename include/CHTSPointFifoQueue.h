/*
 *
 * (C) 2024-26 - ntop.org
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

#ifndef _CH_TS_POINT_FIFO_QUEUE_H
#define _CH_TS_POINT_FIFO_QUEUE_H

#include "ntop_includes.h"

class CHTSPointFifoQueue : public FifoQueue<CHTSPoint*> {
 public:
  CHTSPointFifoQueue(u_int32_t queue_size) : FifoQueue<CHTSPoint*>(queue_size) {}

  ~CHTSPointFifoQueue() {
    while (!q.empty()) {
      delete q.front();
      q.pop();
    }
  }

  /*
    Dequeue up to max_rows points (in a single lock/unlock)
  */
  u_int32_t dequeueBatch(u_int32_t max_rows, std::vector<CHTSPoint*>& out) {
    m.lock(__FILE__, __LINE__);

    while ((out.size() < max_rows) && !q.empty()) {
      out.push_back(q.front());
      q.pop();
      num_dequeued++;
    }

    m.unlock(__FILE__, __LINE__);

    return (u_int32_t)out.size();
  }
};

#endif /* _CH_TS_POINT_FIFO_QUEUE_H */
