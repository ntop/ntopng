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

/* A simple thread safe FIFO non-blocking bounded queue for strings */
class FifoStringsQueue : public FifoQueue {
 public:
  FifoStringsQueue(u_int32_t queue_size, bool multi_producer=true) : FifoQueue(queue_size, multi_producer) {}
  ~FifoStringsQueue();
  bool enqueue(const char *item);
  char* dequeue();
};

#endif /* _FIFO_STRINGS_QUEUE_H */
