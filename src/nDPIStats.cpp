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
#include <string>

/* *************************************** */

nDPIStats::nDPIStats() {
  memset(counters, 0, sizeof(counters));
  memset(cat_counters, 0, sizeof(cat_counters));
}

/* *************************************** */

nDPIStats::nDPIStats(const nDPIStats &stats) {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    if(stats.counters[i] != NULL) {
      counters[i] = (ProtoCounter*) malloc(sizeof(ProtoCounter));
      memcpy(counters[i], stats.counters[i], sizeof(ProtoCounter));
    } else {
      counters[i] = NULL;
    }
  }

  memcpy(cat_counters, stats.cat_counters, sizeof(cat_counters));
}

/* *************************************** */

nDPIStats::~nDPIStats() {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    if(counters[i] != NULL)
      free(counters[i]);
  }
}

/* *************************************** */

void nDPIStats::sum(nDPIStats *stats) {
  for(int i = 0; i < MAX_NDPI_PROTOS; i++) {
    if(counters[i] != NULL) {
      if(stats->counters[i] == NULL) {
	if((stats->counters[i] = (ProtoCounter*)calloc(1, sizeof(ProtoCounter))) == NULL) {
	  static bool oom_warning_sent = false;

	  if(!oom_warning_sent) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	    oom_warning_sent = true;
	  }
	 
	  return;
	}
      }

      stats->counters[i]->packets.sent  += counters[i]->packets.sent;
      stats->counters[i]->packets.rcvd  += counters[i]->packets.rcvd;
      stats->counters[i]->bytes.sent    += counters[i]->bytes.sent;
      stats->counters[i]->bytes.rcvd    += counters[i]->bytes.rcvd;
      stats->counters[i]->duration      += counters[i]->duration;
    }
  }

  for (int i = 0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    if(cat_counters[i].bytes.sent + cat_counters[i].bytes.rcvd > 0) {
      stats->cat_counters[i].bytes.sent += cat_counters[i].bytes.sent;
      stats->cat_counters[i].bytes.rcvd += cat_counters[i].bytes.rcvd;
      stats->cat_counters[i].duration += cat_counters[i].duration;
    }
  }

}

/* *************************************** */

void nDPIStats::print(NetworkInterface *iface) {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    if(counters[i] != NULL) {
      if(counters[i]->packets.sent || counters[i]->packets.rcvd)
	printf("[%s] [pkts: %llu/%llu][bytes: %llu/%llu][duration: %u sec]\n",
	       iface->get_ndpi_proto_name(i),
	       (long long unsigned) counters[i]->packets.sent, (long long unsigned) counters[i]->packets.rcvd,
	       (long long unsigned) counters[i]->bytes.sent,   (long long unsigned)counters[i]->bytes.rcvd,
	       counters[i]->duration);
    }
  }
}

/* *************************************** */

void nDPIStats::lua(NetworkInterface *iface, lua_State* vm, bool with_categories) {
  lua_newtable(vm);

  for(int i=0; i<MAX_NDPI_PROTOS; i++)
    if(counters[i] != NULL) {
      char *name = iface->get_ndpi_proto_name(i);

      if(name != NULL) {
	if(counters[i]->packets.sent || counters[i]->packets.rcvd) {
	  lua_newtable(vm);

	  lua_push_str_table_entry(vm, "breed", iface->get_ndpi_proto_breed_name(i));
	  lua_push_int_table_entry(vm, "packets.sent", counters[i]->packets.sent);
	  lua_push_int_table_entry(vm, "packets.rcvd", counters[i]->packets.rcvd);
	  lua_push_int_table_entry(vm, "bytes.sent", counters[i]->bytes.sent);
	  lua_push_int_table_entry(vm, "bytes.rcvd", counters[i]->bytes.rcvd);
	  lua_push_int_table_entry(vm, "duration", counters[i]->duration);

	  lua_pushstring(vm, name);
	  lua_insert(vm, -2);
	  lua_settable(vm, -3);
	}
      }
    }

  lua_pushstring(vm, "ndpi");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if (with_categories) {
    lua_newtable(vm);

    for (int i=0; i<NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
      if(cat_counters[i].bytes.sent + cat_counters[i].bytes.rcvd > 0) {
        lua_newtable(vm);

        lua_push_int_table_entry(vm, "category", i);
        lua_push_int_table_entry(vm, "bytes", cat_counters[i].bytes.sent + cat_counters[i].bytes.rcvd);
        lua_push_int_table_entry(vm, "bytes.sent", cat_counters[i].bytes.sent);
        lua_push_int_table_entry(vm, "bytes.rcvd", cat_counters[i].bytes.rcvd);
        lua_push_int_table_entry(vm, "duration", cat_counters[i].duration);

        lua_pushstring(vm, iface->get_ndpi_category_name((ndpi_protocol_category_t)i));
        lua_insert(vm, -2);
        lua_settable(vm, -3);
      }
    }

    lua_pushstring(vm, "ndpi_categories");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void nDPIStats::incStats(u_int32_t when, u_int16_t proto_id,
			 u_int64_t sent_packets, u_int64_t sent_bytes,
			 u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {

  if(proto_id < (MAX_NDPI_PROTOS)) {
    if(counters[proto_id] == NULL) {
      if((counters[proto_id] = (ProtoCounter*)calloc(1, sizeof(ProtoCounter))) == NULL) {
	static bool oom_warning_sent = false;

	if(!oom_warning_sent) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	  oom_warning_sent = true;
	}
	
	return;
      }
    }

    counters[proto_id]->packets.sent += sent_packets, counters[proto_id]->bytes.sent += sent_bytes;
    counters[proto_id]->packets.rcvd += rcvd_packets, counters[proto_id]->bytes.rcvd += rcvd_bytes;

    if((when != 0)
       && (when - counters[proto_id]->last_epoch_update >= ntop->getPrefs()->get_housekeeping_frequency())) {
      counters[proto_id]->duration += ntop->getPrefs()->get_housekeeping_frequency(),
	counters[proto_id]->last_epoch_update = when;
    }
  }
}

/* *************************************** */

void nDPIStats::incCategoryStats(u_int32_t when, ndpi_protocol_category_t category_id,
          u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
  if(category_id < NDPI_PROTOCOL_NUM_CATEGORIES) {
    cat_counters[category_id].bytes.sent += sent_bytes;
    cat_counters[category_id].bytes.rcvd += rcvd_bytes;

    if((when != 0)
       && (when - cat_counters[category_id].last_epoch_update >= ntop->getPrefs()->get_housekeeping_frequency())) {
      cat_counters[category_id].duration += ntop->getPrefs()->get_housekeeping_frequency(),
      cat_counters[category_id].last_epoch_update = when;
    }
  }
}

/* *************************************** */

char* nDPIStats::serialize(NetworkInterface *iface) {
  json_object *my_object = getJSONObject(iface);  
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void nDPIStats::deserialize(NetworkInterface *iface, json_object *o) {
  json_object *obj;

  if(!o) return;

  /* Reset all */
  for(int i=0; i<MAX_NDPI_PROTOS; i++) if(counters[i] != NULL) free(counters[i]);
  memset(counters, 0, sizeof(counters));
  memset(cat_counters, 0, sizeof(cat_counters));

  for(int proto_id = 0; proto_id < MAX_NDPI_PROTOS; proto_id++) {
    char *name = iface->get_ndpi_proto_name(proto_id);

    if(name != NULL) {

      if(json_object_object_get_ex(o, name, &obj)) {
	json_object *bytes, *packets;

	if((counters[proto_id] = (ProtoCounter*)calloc(1, sizeof(ProtoCounter))) != NULL) {
	  json_object *duration;
	  
	  if(json_object_object_get_ex(obj, "bytes", &bytes)) {
	    json_object *sent, *rcvd;

	    if(json_object_object_get_ex(bytes, "sent", &sent))
	      counters[proto_id]->bytes.sent = json_object_get_int64(sent);

	    if(json_object_object_get_ex(bytes, "rcvd", &rcvd))
	      counters[proto_id]->bytes.rcvd = json_object_get_int64(rcvd);
	  }

	  if(json_object_object_get_ex(obj, "packets", &packets)) {
	    json_object *sent, *rcvd;

	    if(json_object_object_get_ex(bytes, "sent", &sent))
	      counters[proto_id]->packets.sent = json_object_get_int64(sent);

	    if(json_object_object_get_ex(bytes, "rcvd", &rcvd))
	      counters[proto_id]->packets.rcvd = json_object_get_int64(rcvd);
	  }

	  if(json_object_object_get_ex(obj, "duration", &duration))
	    counters[proto_id]->duration = json_object_get_int(duration);	  
	}
      }
    }
  }

  if(json_object_object_get_ex(o, "categories", &obj)) {
    json_object *cat_o;

    for (int i = 0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
      const char *name = iface->get_ndpi_category_name((ndpi_protocol_category_t)i);

      if(name != NULL) {

	if(json_object_object_get_ex(obj, name, &cat_o)) {
	  json_object *data_o;

	  if(json_object_object_get_ex(cat_o, "bytes_sent", &data_o))
	    cat_counters[i].bytes.sent = json_object_get_int64(data_o);
	  if(json_object_object_get_ex(cat_o, "bytes_rcvd", &data_o))
	    cat_counters[i].bytes.rcvd = json_object_get_int64(data_o);
	  if(json_object_object_get_ex(cat_o, "duration", &data_o))
	    cat_counters[i].duration = json_object_get_int(data_o);
	}
      }
    }
  }
}

/* *************************************** */

static void addProtoJson(json_object *my_object, ProtoCounter *counter, const char *name) {
  json_object *inner, *inner1;

  inner = json_object_new_object();
  if(! inner) return;

  json_object_object_add(inner, "duration", json_object_new_int64(counter->duration));
  
  inner1 = json_object_new_object();
  if(! inner1) { json_object_put(inner); return; }
  json_object_object_add(inner1, "sent", json_object_new_int64(counter->bytes.sent));
  json_object_object_add(inner1, "rcvd", json_object_new_int64(counter->bytes.rcvd));
  json_object_object_add(inner, "bytes", inner1);

  inner1 = json_object_new_object();
  if(! inner1) { json_object_put(inner); return; }
  json_object_object_add(inner1, "sent", json_object_new_int64(counter->packets.sent));
  json_object_object_add(inner1, "rcvd", json_object_new_int64(counter->packets.rcvd));
  json_object_object_add(inner, "packets", inner1);

  json_object_object_add(my_object, name, inner);
} 

json_object* nDPIStats::getJSONObject(NetworkInterface *iface) {
  char *unknown = iface->get_ndpi_proto_name(NDPI_PROTOCOL_UNKNOWN);
  json_object *my_object;
  json_object *inner, *inner1;  

  my_object = json_object_new_object();

  for(int proto_id = 0; proto_id < MAX_NDPI_PROTOS; proto_id++) {
    if(counters[proto_id] != NULL) {
      char *name = iface->get_ndpi_proto_name(proto_id);
      
      if((proto_id > 0) && (name == unknown)) break;

      if(name != NULL)
        addProtoJson(my_object, counters[proto_id], name);
    }
  }

  inner = json_object_new_object();
  for (int i = 0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    if(cat_counters[i].bytes.sent + cat_counters[i].bytes.rcvd > 0) {
      inner1 = json_object_new_object();

      json_object_object_add(inner1, "id",      json_object_new_int64(i));
      json_object_object_add(inner1, "bytes_sent",   json_object_new_int64(cat_counters[i].bytes.sent));
      json_object_object_add(inner1, "bytes_rcvd",   json_object_new_int64(cat_counters[i].bytes.rcvd));
      json_object_object_add(inner1, "duration",json_object_new_int64(cat_counters[i].duration));

      json_object_object_add(inner, iface->get_ndpi_category_name((ndpi_protocol_category_t)i), inner1);
    }
  }
  json_object_object_add(my_object, "categories", inner);

  return(my_object);
}

/* *************************************** */

json_object* nDPIStats::getJSONObjectForCheckpoint(NetworkInterface *iface) {
  json_object *my_object;
  char *name;

  my_object = json_object_new_object();
  if(my_object == NULL) return NULL;

  if (counters[NDPI_PROTOCOL_DNS] != NULL) {
    name = iface->get_ndpi_proto_name(NDPI_PROTOCOL_DNS);
    if(name) addProtoJson(my_object, counters[NDPI_PROTOCOL_DNS], name);
  }

  if (counters[NDPI_PROTOCOL_EDONKEY] != NULL) {
    name = iface->get_ndpi_proto_name(NDPI_PROTOCOL_EDONKEY);
    if(name) addProtoJson(my_object, counters[NDPI_PROTOCOL_EDONKEY], name);
  }

  if (counters[NDPI_PROTOCOL_BITTORRENT] != NULL) {
    name = iface->get_ndpi_proto_name(NDPI_PROTOCOL_BITTORRENT);
    if(name) addProtoJson(my_object, counters[NDPI_PROTOCOL_BITTORRENT], name);
  }

  if (counters[NDPI_PROTOCOL_SKYPE] != NULL) {
    name = iface->get_ndpi_proto_name(NDPI_PROTOCOL_SKYPE);
    if(name) addProtoJson(my_object, counters[NDPI_PROTOCOL_SKYPE], name);
  }

  return my_object;
}

/* *************************************** */

void nDPIStats::resetStats() {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    /* NOTE: do not deallocate counters since they can be in use by other threads */
    if(counters[i] != NULL)
      memset(&counters[i], 0, sizeof(counters[i]));
  }

  memset(cat_counters, 0, sizeof(cat_counters));
}
