/*
 *
 * (C) 2013-15 - ntop.org
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
}

/* *************************************** */

nDPIStats::~nDPIStats() {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    if(counters[i] != NULL)
      free(counters[i]);
  }
}

/* *************************************** */

void nDPIStats::sumStats(nDPIStats *stats) {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
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

      stats->counters[i]->packets.sent += counters[i]->packets.sent;
      stats->counters[i]->packets.rcvd += counters[i]->packets.rcvd;
      stats->counters[i]->bytes.sent   += counters[i]->bytes.sent;
      stats->counters[i]->bytes.rcvd   += counters[i]->bytes.rcvd;
    }
  }
}

/* *************************************** */

void nDPIStats::print(NetworkInterface *iface) {
  for(int i=0; i<MAX_NDPI_PROTOS; i++) {
    if(counters[i] != NULL) {
      if(counters[i]->packets.sent || counters[i]->packets.rcvd)
	printf("[%s] [pkts: %llu/%llu][bytes: %llu/%llu]\n",
	       iface->get_ndpi_proto_name(i),
	       (long long unsigned) counters[i]->packets.sent, (long long unsigned) counters[i]->packets.rcvd,
	       (long long unsigned) counters[i]->bytes.sent,   (long long unsigned)counters[i]->bytes.rcvd);
    }
  }
}

/* *************************************** */

void nDPIStats::lua(NetworkInterface *iface, lua_State* vm) {
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

	  lua_pushstring(vm, name);
	  lua_insert(vm, -2);
	  lua_settable(vm, -3);
	}
      }
    }

  lua_pushstring(vm, "ndpi");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void nDPIStats::incStats(u_int16_t proto_id,
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
  if(!o) return;

  /* Reset all */
  for(int i=0; i<MAX_NDPI_PROTOS; i++) if(counters[i] != NULL) free(counters[i]);
  memset(counters, 0, sizeof(counters));

  for(int proto_id=0; proto_id<MAX_NDPI_PROTOS; proto_id++) {
    char *name = iface->get_ndpi_proto_name(proto_id);

    if(name != NULL) {
      json_object *obj;

      if(json_object_object_get_ex(o, name, &obj)) {
	json_object *bytes, *packets;

	if((counters[proto_id] = (ProtoCounter*)malloc(sizeof(ProtoCounter))) != NULL) {
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
	}
      }
    }
  }
}

/* *************************************** */

json_object* nDPIStats::getJSONObject(NetworkInterface *iface) {
  char *unknown = iface->get_ndpi_proto_name(NDPI_PROTOCOL_UNKNOWN);
  json_object *my_object;
  
  my_object = json_object_new_object();

  for(int proto_id=0; proto_id<MAX_NDPI_PROTOS; proto_id++) {
    if(counters[proto_id] != NULL) {
      char *name = iface->get_ndpi_proto_name(proto_id);
      
      if((proto_id > 0) && (name == unknown)) break;

      if(name != NULL) {
	json_object *inner, *inner1;

	inner = json_object_new_object();

	inner1 = json_object_new_object();
	json_object_object_add(inner1, "sent", json_object_new_int64(counters[proto_id]->bytes.sent));
	json_object_object_add(inner1, "rcvd", json_object_new_int64(counters[proto_id]->bytes.rcvd));
	json_object_object_add(inner, "bytes", inner1);

	inner1 = json_object_new_object();
	json_object_object_add(inner1, "sent", json_object_new_int64(counters[proto_id]->packets.sent));
	json_object_object_add(inner1, "rcvd", json_object_new_int64(counters[proto_id]->packets.rcvd));
	json_object_object_add(inner, "packets", inner1);

	json_object_object_add(my_object, name, inner);
      }
    }
  }

  return(my_object);
}
