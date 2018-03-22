/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _CHECKPOINTABLE_H_
#define _CHECKPOINTABLE_H_

#include "ntop_includes.h"

class NetworkInterface;

class Checkpointable {
 private:
  char *checkpoints[CONST_MAX_NUM_CHECKPOINTS]; /* controllable json serializations */

#ifdef HAVE_ZLIB
  u_int16_t compressed_lengths[CONST_MAX_NUM_CHECKPOINTS];
#endif

 public:
  Checkpointable();
  ~Checkpointable();
  bool checkpoint(lua_State* vm, NetworkInterface *iface, u_int8_t checkpoint_id, DetailsLevel details_level);

  /* This function must return a serialization of the entity information needed
   * for the checkpoint. The returned string is dynamically allocated and will be
   * free by the caller.
   */
  virtual bool serializeCheckpoint(json_object* my_object, DetailsLevel details_level) = 0;
};

#endif
