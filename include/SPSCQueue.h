/*
 *
 * (C) 2014-18 - ntop.org
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

#ifndef _SPSC_QUEUE_H_
#define _SPSC_QUEUE_H_

#include "ntop_includes.h"

/* Single producer, single/multi consumer */

class SPSCQueue {
 private:
  spsc_queue_t *q;
  Mutex *m;
    
 public:
  SPSCQueue(bool multi_consumer = false) {
    q = (spsc_queue_t *) calloc(1, sizeof(spsc_queue_t));
    if(q == NULL) throw 1;
    q->tail = q->shadow_tail = QUEUE_ITEMS - 1;
    q->head = q->shadow_head = 0;

    if(multi_consumer)
      m = new Mutex();
    else
      m = NULL;
  }

  /* ************************************** */

  ~SPSCQueue() { free(q); if(m) delete m; }

  /* ************************************** */

  inline bool dequeue(void** item) {
    u_int32_t next_tail;
    bool rc;
    
    if(m) m->lock(__FILE__, __LINE__);
    
    next_tail = (q->shadow_tail + 1) & QUEUE_ITEMS_MASK;
    if(next_tail != q->head) {
      *item = q->items[next_tail];
      q->shadow_tail = next_tail;

      if((q->shadow_tail & QUEUE_WATERMARK_MASK) == 0) {
        // gcc_mb();
        q->tail = q->shadow_tail;
      }

      rc = true;
    } else
      rc = false;

    if(m) m->unlock(__FILE__, __LINE__);
    
    return(rc);   
  }

  /* ************************************** */

  inline bool enqueue(void *item, bool flush = true) {
    u_int32_t next_head;

    next_head = (q->shadow_head + 1) & QUEUE_ITEMS_MASK;

    if(q->tail != next_head) {
      q->items[q->shadow_head] = item;

      q->shadow_head = next_head;
      if(flush || (q->shadow_head & QUEUE_WATERMARK_MASK) == 0) {
        // gcc_mb();
        q->head = q->shadow_head;
      }

      return true;
    } else
      return false;
  }

};

#endif /* _SPSC_QUEUE_H_ */
