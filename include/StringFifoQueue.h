/*
 *
 * (C) 2014-21 - ntop.org
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


#ifndef _STRING_FIFO_QUEUE_H
#define _STRING_FIFO_QUEUE_H

#include "ntop_includes.h"

class StringFifoQueue : public FifoQueue<char*> {
 public:
  StringFifoQueue(u_int32_t queue_size) : FifoQueue<char*>(queue_size) {}

  ~StringFifoQueue() {
    while(!q.empty()) {
      char *s = q.front();

      q.pop();
      free(s);
    }
  }

  bool enqueue(char* item) {
    bool rv;
    
    m.lock(__FILE__, __LINE__);

    if(canEnqueue()) {
      char *d = strdup(item);

      if(d) {
	q.push(d);
	rv = true;
      } else {
	rv = false;
      }
    } else
      rv = false;

    if(rv)
      num_enqueued++;
    else
      num_not_enqueued++;

    m.unlock(__FILE__, __LINE__);
    
    return(rv);
  }
};

#endif /* _STRING_FIFO_QUEUE_H */
