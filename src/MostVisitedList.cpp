/*
 *
 * (C) 2013-21 - ntop.org
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

MostVisitedList::MostVisitedList(u_int32_t _max_num_items) {
  top_data = new (std::nothrow) FrequentStringItems(_max_num_items);
  old_data = shadow_old_data = NULL;
  max_num_items = _max_num_items;
  current_cycle = 0;
}

/* *************************************** */

MostVisitedList::~MostVisitedList() {
  if(top_data) delete(top_data);
  if(old_data) free(old_data);
  if(shadow_old_data) free(shadow_old_data);
}

/* *************************************** */

void MostVisitedList::getCurrentTime(struct tm *t_now) {
  time_t now = time(NULL);

  memset(t_now, 0, sizeof(*t_now));
  localtime_r(&now, t_now);
}

/* *************************************** */

void MostVisitedList::saveOldData(u_int32_t iface_id, char *additional_key_info, char *hashkey) {
  char redis_key[64];
  int minute = 0;
  struct tm t_now;

  // Using a shadow due to a possible segv while freeing 
  // old_data and getting stats from lua
  if(shadow_old_data) { free(shadow_old_data); shadow_old_data = NULL; }

  if(!ntop->getRedis())
    return;

  /* Still no old data collected */
  if(!old_data) { old_data = top_data->json(); return; }

  getCurrentTime(&t_now);
  minute = t_now.tm_min - (t_now.tm_min % 5);

  snprintf(redis_key, sizeof(redis_key), "%s%s_%d_%d_%d_%d", (char*) NTOPNG_CACHE_PREFIX,
            additional_key_info, iface_id, t_now.tm_mday, t_now.tm_hour, minute);

  /* String like `ntopng.cache.1_17_11_45` */
  /* An other way is to use the localtime_r and compose the string like `ntopng.cache_2_1609761600` */

  ntop->getRedis()->set(redis_key , old_data, 7200);

  if(minute == 0 && current_cycle > 0) {
    char hour_done[64];
    int hour = 0;

    if(t_now.tm_hour == 0)
      hour = 23;
    else
      hour = t_now.tm_hour - 1;

    /* List key = ntopng.cache.top_sites_hour_done | value = 1_17_11 */
    snprintf(hour_done, sizeof(hour_done), "%d_%d_%d", iface_id, t_now.tm_mday, hour);

    ntop->getRedis()->lpush(hashkey, hour_done, 3600);

    current_cycle = 0;
  } else
    current_cycle++;

  shadow_old_data = old_data;
  old_data = top_data->json();
}

/* *************************************** */

void MostVisitedList::lua(lua_State *vm, char *name, char *old_name) {
  FrequentStringItems *cur_top_data = top_data;
  char *cur_old_data = old_data;

  if(cur_top_data) {
    char *cur_top_data_json = cur_top_data->json();

    if(cur_top_data_json) {
      lua_push_str_table_entry(vm, name, cur_top_data_json);
      free(cur_top_data_json);
    }  
  }

  if(cur_old_data)
    lua_push_str_table_entry(vm, old_name, cur_old_data);
}

/* *************************************** */

void MostVisitedList::serializeDeserialize(u_int32_t iface_id, 
                                            bool do_serialize, 
                                            char *extra_info, 
                                            char *info_subject, 
                                            char *hour_hashkey, 
                                            char *day_hashkey) {
  struct tm t_now;
  char redis_hour_key[64], redis_daily_key[64], redis_key_current_data[64];

  if(!top_data)
    return;

  /* Struct containing the current time */
  getCurrentTime(&t_now);

  /* Formatting the hour and daily redis key */
  snprintf(redis_hour_key, sizeof(redis_hour_key), "%s%u_%d_%u", extra_info, iface_id, t_now.tm_mday, t_now.tm_hour);
  snprintf(redis_daily_key, sizeof(redis_daily_key), "%s%u_%d", extra_info, iface_id, t_now.tm_mday);

  snprintf(redis_key_current_data, sizeof(redis_key_current_data), "%s%s%d_%d", (char*) NTOPNG_CACHE_PREFIX, info_subject,
            iface_id, t_now.tm_mday);

  /* Serialize the data */
  if(do_serialize) {
    ntop->getRedis()->lpush(hour_hashkey, redis_hour_key, 3600);
    ntop->getRedis()->lpush(day_hashkey, redis_daily_key, 3600);
    if(top_data->getSize()) {
      /* Serialize the double of the max value */
      char *top_data_json = top_data->json(2*max_num_items);

      if(top_data_json) {
        ntop->getRedis()->set(redis_key_current_data , top_data_json, 3600);
        free(top_data_json);
      }
    }
  }
  /* Deserialize the data */
  else {
    ntop->getRedis()->lrem(hour_hashkey, redis_hour_key);
    ntop->getRedis()->lrem(day_hashkey, redis_daily_key);
    deserializeTopData(redis_key_current_data);
    ntop->getRedis()->del(redis_key_current_data);
  }
}

/* *************************************** */

void MostVisitedList::deserializeTopData(char* redis_key_current) {
  char *json;
  u_int json_len;
  json_object *j;
  enum json_tokener_error jerr;

  json_len = ntop->getRedis()->len(redis_key_current);
  if(json_len == 0) json_len = CONST_MAX_LEN_REDIS_VALUE; else json_len += 8; /* Little overhead */

  if((json = (char*)malloc(json_len)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return;
  }

  if((ntop->getRedis()->get(redis_key_current, json, json_len) == -1)
     || (json[0] == '\0')) {
    free(json);
    return; /* Nothing found */
  }

  j = json_tokener_parse_verbose(json, &jerr);

  if(j != NULL) {

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [%u]", json, json_len);
#endif

    if(json_object_get_type(j) == json_type_object) {
      struct lh_entry *entry = json_object_get_object(j)->head;

      for(; entry != NULL; entry = entry->next) {
	char *key               = (char*)entry->k;
	struct json_object *val = (struct json_object*)entry->v;
	enum json_type type = json_object_get_type(val);

	if(type == json_type_int) {
	  u_int32_t value = json_object_get_int64(val);

#ifdef DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s = %u", key, value);
#endif
    
    incrVisitedData(key, value);
	}
      }
    } else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid JSON content for key %s", redis_key_current);

    json_object_put(j); /* Free memory */
  } else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deserialization Error: %s", json);

  free(json);
}

/* *************************************** */

void MostVisitedList::resetTopSitesData(u_int32_t iface_id, char *extra_info, char *hashkey) {
  char redis_reset_key[256];

  int minute = 0;
  struct tm t_now;

  if(!ntop->getRedis())
    return;

  getCurrentTime(&t_now);
  minute = t_now.tm_min - (t_now.tm_min % 5);

  snprintf(redis_reset_key, sizeof(redis_reset_key), "%s%u_%d_%u_%d", extra_info, iface_id, t_now.tm_mday, t_now.tm_hour, minute);
  ntop->getRedis()->lpush(hashkey, redis_reset_key, 3600);
}

/* *************************************** */