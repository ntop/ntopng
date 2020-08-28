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

#ifndef _FIFO_SERIALIZER_QUEUE_H
#define _FIFO_SERIALIZER_QUEUE_H

#include "ntop_includes.h"

class FifoSerializerQueue : public FifoQueue<ndpi_serializer*> {
 public:
  FifoSerializerQueue(u_int32_t queue_size) : FifoQueue<ndpi_serializer*>(queue_size) {}
  ~FifoSerializerQueue() {
    while(!q.empty()) {
      ndpi_serializer *s = q.front();

      q.pop();
      ndpi_term_serializer(s);
      free(s);
    }
  }

};

#endif /* _FIFO_SERIALIZER_QUEUE_H */
