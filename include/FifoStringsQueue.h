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


#ifndef _FIFO_STRINGS_QUEUE_H
#define _FIFO_STRINGS_QUEUE_H

#include "ntop_includes.h"

class FifoStringsQueue : public FifoQueue<char*> {
 public:
  FifoStringsQueue(u_int32_t queue_size) : FifoQueue<char*>(queue_size) {}
  ~FifoStringsQueue() {
    while(!q.empty()) {
      char *s = q.front();

      q.pop();
      free(s);
    }
  }

  bool enqueue(char* item) {
    char *d;
    bool rv;
    
    if(!item) return(false); else d = strdup(item);

    if(!d) return(false);

    m.lock(__FILE__, __LINE__);

    if(canEnqueue()) {
      q.push(d);
      rv = true;
    } else
      rv = false;

    m.unlock(__FILE__, __LINE__);
    
    return(rv);
  }
};

#endif /* _FIFO_STRINGS_QUEUE_H */
