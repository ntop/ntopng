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

Checkpointable::Checkpointable(bool compress) {
  memset(&checkpoints, 0, sizeof(checkpoints));

#ifdef HAVE_ZLIB
  compression_enabled = compress;

  if(compression_enabled) {
    compressed_lengths = (uLongf *) calloc(CONST_MAX_NUM_CHECKPOINTS, sizeof(uLongf));
    uncompressed_lengths = (uLongf *) calloc(CONST_MAX_NUM_CHECKPOINTS, sizeof(uLongf));
  } else
    compressed_lengths = uncompressed_lengths = NULL;
#endif
}

/* *************************************** */

bool Checkpointable::checkpoint(lua_State* vm, u_int8_t checkpoint_id) {
  char *new_data;

  if(checkpoint_id >= CONST_MAX_NUM_CHECKPOINTS) {
    if(vm) lua_pushnil(vm);
    return false;
  }

  if(vm) {
    lua_newtable(vm);

    if(checkpoints[checkpoint_id]) {
#ifdef HAVE_ZLIB
      if(compression_enabled) {
        char *uncompressed = (char*) malloc(uncompressed_lengths[checkpoint_id] + 1);

        if(uncompressed == NULL) {
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot allocate decompression buffer");
          return false;
        }

        int err;

        if((err = uncompress((Bytef*)uncompressed, &uncompressed_lengths[checkpoint_id], (Bytef*)checkpoints[checkpoint_id], compressed_lengths[checkpoint_id])) != Z_OK) {
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Uncompress error [%d][len: %u]", err, uncompressed_lengths[checkpoint_id]);
          free(uncompressed);
          return false;
        }

        uncompressed[uncompressed_lengths[checkpoint_id]] = '\0';
        lua_push_str_table_entry(vm, (char*)"previous", uncompressed);
        free(uncompressed);
      } else
        lua_push_str_table_entry(vm, (char*)"previous", checkpoints[checkpoint_id]);
#else
      lua_push_str_table_entry(vm, (char*)"previous", checkpoints[checkpoint_id]);
#endif
    }
  }

  if(checkpoints[checkpoint_id])
    free(checkpoints[checkpoint_id]);

  new_data = serializeCheckpoint();

  if(new_data) {
#ifdef HAVE_ZLIB
    if(compression_enabled) {
      uLongf sourceLen = strlen(new_data);
      uLongf destLen = compressBound(sourceLen);

      checkpoints[checkpoint_id] = (char *) malloc(destLen);
      if(checkpoints[checkpoint_id] == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot allocate compression buffer");
        free(new_data);
        return false;
      }

      compress((Bytef*)checkpoints[checkpoint_id], &destLen, (Bytef*)new_data, sourceLen);
      uncompressed_lengths[checkpoint_id] = sourceLen;
      compressed_lengths[checkpoint_id] = destLen;

#ifdef CHECKPOINT_COMPRESSION_DEBUG
      /* Note: 2 * uLongf is the space needed to hold compression metadata */
      /* Negative values means compression is not worth it! */
      uLongf occupied_len = destLen + 2 * sizeof(uLongf);
      float save_ratio = (1 - (occupied_len * 1.f / sourceLen)) * 100;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Checkpoint compress: [%u/%u bytes] %.2f%% save",
              occupied_len, sourceLen, save_ratio);
#endif
    } else
      checkpoints[checkpoint_id] = new_data;
#else
    checkpoints[checkpoint_id] = new_data;
#endif

    if(vm)
      lua_push_str_table_entry(vm, (char*)"current", new_data);

#ifdef HAVE_ZLIB
  if(compression_enabled)
    free(new_data);
#endif
  } else {
    if(vm) lua_pushnil(vm);
  }

  return true;
}

/* *************************************** */

Checkpointable::~Checkpointable() {
  for(int i = 0; i < CONST_MAX_NUM_CHECKPOINTS; i++) {
    if(checkpoints[i]) free(checkpoints[i]);
  }

#ifdef HAVE_ZLIB
  if (compressed_lengths) free(compressed_lengths);
  if (uncompressed_lengths) free(uncompressed_lengths);
#endif
}
