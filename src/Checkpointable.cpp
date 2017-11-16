/*
 *
 * (C) 2013-17 - ntop.org
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

#include "ntop_includes.h"

/* *************************************** */

Checkpointable::Checkpointable() {
  memset(&checkpoints, 0, sizeof(checkpoints));
}

/* *************************************** */

void Checkpointable::checkpoint(lua_State* vm, u_int8_t checkpoint_id) {
  if(checkpoint_id >= CONST_MAX_NUM_CHECKPOINTS) {
    if(vm) lua_pushnil(vm);
    return;
  }

  if(vm) {
    lua_newtable(vm);

    if(checkpoints[checkpoint_id])
      lua_push_str_table_entry(vm, (char*)"previous", checkpoints[checkpoint_id]);
  }

  if(checkpoints[checkpoint_id])
    free(checkpoints[checkpoint_id]);

  checkpoints[checkpoint_id] = serializeCheckpoint();

  if(vm) {
    if(checkpoints[checkpoint_id])
      lua_push_str_table_entry(vm, (char*)"current", checkpoints[checkpoint_id]);
  }
}

/* *************************************** */

Checkpointable::~Checkpointable() {
  for(int i = 0; i < CONST_MAX_NUM_CHECKPOINTS; i++) {
    if(checkpoints[i]) free(checkpoints[i]);
  }
}
