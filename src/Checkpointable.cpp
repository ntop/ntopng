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

#include "ntop_includes.h"

/* *************************************** */

Checkpointable::Checkpointable() {
  memset(&checkpoints, 0, sizeof(checkpoints));

#ifdef HAVE_ZLIB
  /* When 0, no compression has been performed */
  memset(&compressed_lengths, 0, sizeof(compressed_lengths));
#endif
}

/* *************************************** */

bool Checkpointable::checkpoint(lua_State* vm, NetworkInterface *iface, u_int8_t checkpoint_id, DetailsLevel details_level) {
  const char *new_data;
  json_object *json_dump;

#ifdef HAVE_ZLIB
  char *comp_buffer = iface->getCheckpointCompressionBuffer(checkpoint_id);
#endif

  if(checkpoint_id >= CONST_MAX_NUM_CHECKPOINTS) {
    if(vm) lua_pushnil(vm);
    return false;
  }

  if(vm) {
    lua_newtable(vm);

    if(checkpoints[checkpoint_id]) {
#ifdef HAVE_ZLIB
      if((compressed_lengths[checkpoint_id] != 0) && comp_buffer) {
        /* Value was compressed */
        int err;
        uLongf destSize = MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE - 1;

        if((err = uncompress((Bytef*)comp_buffer, &destSize, (Bytef*)checkpoints[checkpoint_id], compressed_lengths[checkpoint_id])) != Z_OK) {
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Uncompress error [%d][len: %u]", err, destSize);
          return false;
        }

        comp_buffer[destSize] = '\0';
        lua_push_str_table_entry(vm, (char*)"previous", comp_buffer);
      } else
        /* Not compressed */
        lua_push_str_table_entry(vm, (char*)"previous", checkpoints[checkpoint_id]);
#else
      lua_push_str_table_entry(vm, (char*)"previous", checkpoints[checkpoint_id]);
#endif
    }
  }

  if(checkpoints[checkpoint_id] != NULL) {
    free(checkpoints[checkpoint_id]);
    checkpoints[checkpoint_id] = NULL;
  }

  json_dump = json_object_new_object();

  if(json_dump && serializeCheckpoint(json_dump, details_level)) {
    if (details_level >= details_high) {
      /* Only add dump timestamp on high details */
      json_object_object_add(json_dump, "timestamp", json_object_new_int64(time(0)));
    }

    new_data = json_object_to_json_string(json_dump);

#ifdef HAVE_ZLIB
    /* Try to compress */
    uLongf sourceLen = strlen(new_data);
    uLongf destLen = MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE - 1;
    char *compressed_value = NULL;

    if (comp_buffer
          && (sourceLen < MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE) /* we use the same buffer for decompression, so uncompressed data must fit it */
          && (compress((Bytef*)comp_buffer, &destLen, (Bytef*)new_data, sourceLen) == Z_OK)
          && (sourceLen > destLen + 2)) { /* the compression is meaningful */
      compressed_value = (char *) malloc(destLen);
    }

    if (compressed_value == NULL) {
      checkpoints[checkpoint_id] = strdup(new_data);
      compressed_lengths[checkpoint_id] = 0;  /* No compression */

#ifdef CHECKPOINT_COMPRESSION_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Refusing to compress %u bytes [bufsize=%u]",
              sourceLen, MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE);
#endif
    } else {
      memcpy(compressed_value, comp_buffer, destLen);
      checkpoints[checkpoint_id] = compressed_value;
      compressed_lengths[checkpoint_id] = destLen; /* With compression */

#ifdef CHECKPOINT_COMPRESSION_DEBUG
      /* Negative values means compression is not worth it! */
      float save_ratio = (1 - (destLen * 1.f / sourceLen)) * 100;

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Checkpoint compress: [%u/%u bytes] %.2f%% save",
              destLen, sourceLen, save_ratio);
#endif
    }

#else
    checkpoints[checkpoint_id] = strdup(new_data);
#endif // HAVE_ZLIB

    if(vm)
      lua_push_str_table_entry(vm, (char*)"current", (char*)new_data);

  } else {
    if(vm) lua_pushnil(vm);
  }

  if (json_dump) json_object_put(json_dump);
  return true;
}

/* *************************************** */

Checkpointable::~Checkpointable() {
  for(int i = 0; i < CONST_MAX_NUM_CHECKPOINTS; i++) {
    if(checkpoints[i]) free(checkpoints[i]);
  }
}
