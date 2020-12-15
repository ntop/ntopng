/*
 *
 * (C) 2014-20 - ntop.org
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

#ifndef _ALERT_FIFO_QUEUE_H
#define _ALERT_FIFO_QUEUE_H

#include "ntop_includes.h"

class AlertFifoQueue : public FifoQueue<AlertFifoItem> {
 public:
  AlertFifoQueue(u_int32_t queue_size) : FifoQueue<AlertFifoItem>(queue_size) {}

  ~AlertFifoQueue() {
    while(!q.empty()) {
      AlertFifoItem item = q.front();
      q.pop();
      free(item.alert);
    }
  }

  AlertFifoItem dequeue() {
    AlertFifoItem rv;

    m.lock(__FILE__, __LINE__);

    if(q.empty()) {
      rv.alert_severity = alert_level_none;
      rv.alert = NULL;
    } else {
      rv = q.front();
      q.pop();
      num_dequeued++;
    }
    m.unlock(__FILE__, __LINE__);

    return(rv);
  }

};

#endif /* _ALERT_FIFO_QUEUE_H */
