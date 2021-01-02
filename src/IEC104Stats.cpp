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

// #define DEBUG_IEC60870
// #define IEC60870_TRACE

/* *************************************** */

IEC104Stats::IEC104Stats() {
  memset(&pkt_lost, 0, sizeof(pkt_lost));
  last_type_i = 0;
  memset(&last_i_apdu, 0, sizeof(last_i_apdu));
  memset(&stats, 0, sizeof(stats));
  i_s_apdu = ndpi_alloc_data_analysis(32 /* sliding window side */);
  tx_seq_num = rx_seq_num = 0;
}

/* *************************************** */

IEC104Stats::~IEC104Stats() {
  ndpi_free_data_analysis(i_s_apdu);
}

/* *************************************** */

void IEC104Stats::processPacket(Flow *f, bool tx_direction,
				const u_char *payload, u_int16_t payload_len,
				struct timeval *packet_time) {
  if((payload_len >= 6) && (payload[0] == 0x68 /* IEC magic byte */)) {
    u_int offset = 1 /* Skip magic byte */;
    u_int64_t *allowedTypeIDs = ntop->getPrefs()->getIEC104AllowedTypeIDs();
    std::unordered_map<u_int16_t, u_int32_t>::iterator it;

    lock.wrlock(__FILE__, __LINE__);

    if(tx_direction) stats.forward_msgs++; else stats.reverse_msgs++;

    while(offset /* Skip START byte */ < payload_len) {
      /* https://infosys.beckhoff.com/english.php?content=../content/1033/tcplclibiec870_5_104/html/tcplclibiec870_5_104_objref_overview.htm&id */
      u_int8_t len = payload[offset], pdu_type = ((payload[offset+1] & 0x01) == 0) ? 0 : (payload[offset+1] & 0x03);

#ifdef DEBUG_IEC60870
      ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s] %02X %02X %02X %02X",
				   __FUNCTION__, payload[offset-1], payload[offset],
				   payload[offset+1], payload[offset+2]);
#endif

#ifdef DEBUG_IEC60870
      ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s] A-PDU Len %u/%u [pdu_type: %u][magic: %02X]",
				   __FUNCTION__, len, payload_len, pdu_type, payload[offset-1]);
#endif

      if(len == 0) break; /* Something went wrong */

      switch(pdu_type) {
      case 0x03: /* U */
#ifdef IEC60870_TRACE
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "A-PDU U-%u", (payload[offset+1] & 0xFC) >> 2);
#endif
	/* No rx and tx to be updated */
	stats.type_u++;
	break;

      case 0x01: /* S */
	if(len >= 4) {
#ifdef IEC60870_TRACE
	  u_int16_t rx = ((((u_int16_t)payload[offset+4]) << 8) + payload[offset+3]) >> 1;
#endif

	  if(last_i_apdu.tv_sec != 0) {
	    float     ms =  Utils::msTimevalDiff(packet_time, &last_i_apdu);

#ifdef IEC60870_TRACE
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "A-PDU S [last I-TX: %u][S RX ack: %u][tdiff: %.2f msec]",
					 tx_seq_num, rx, ms);
#endif
	    /*
	      In theory if all is in good shape
	      (rx + 1) == tx_seq_num
	    */

	    ndpi_data_add_value(i_s_apdu, ms);
	  }

	  /* No rx and tx to be updated */
	}

	stats.type_s++;
	break;
      }

      if(pdu_type != 0x0 /* Type I */) {
	offset += len + 2;
	stats.type_other++;
	continue;
      }

      /* From now on, only Type I packets are processed */
      memcpy(&last_i_apdu, packet_time, sizeof(struct timeval));
      stats.type_i++;

      if(len >= 6 /* Ignore 4 bytes APDUs */) {
	u_int16_t rx_value, tx_value;
	bool initial_run = ((rx_seq_num == 0) && (tx_seq_num == 0)) ? true : false;

	tx_value = ((((u_int16_t)payload[offset+2]) << 8) + payload[offset+1]) >> 1;
	rx_value = ((((u_int16_t)payload[offset+4]) << 8) + payload[offset+3]) >> 1;

	if(!tx_direction) {
	  /* Counters are swapped */
	  u_int16_t v = rx_value;

	  rx_value = tx_value;
	  tx_value = v;
	}

	if((tx_value == tx_seq_num) && (rx_value == rx_seq_num)) {
	  stats.retransmitted_msgs++;
	  lock.unlock(__FILE__, __LINE__);
	  return;
	}

	if(!initial_run) {
	  u_int32_t diff = abs(tx_value-(tx_seq_num+1));

	  /* Check for id reset (16 bit only) */
	  if(diff != 32768) pkt_lost.tx += diff;
	}
	tx_seq_num = tx_value;

	if(!tx_direction) {
	  if(!initial_run) {
	    u_int32_t diff = abs(rx_value-rx_seq_num);

	    /* Check for id reset (16 bit only) */
	    if(diff != 32768) pkt_lost.rx += diff;
	  }

	  rx_value++; /* The next RX will be increased by 1 */
	} else {
	  if(!initial_run) {
	    u_int32_t diff = abs(rx_value-rx_seq_num);

	    /* Check for id reset (16 bit only) */
	    if(diff != 32768) pkt_lost.rx += diff;
	  }
	}
	rx_seq_num = rx_value;

	/* Skip magic(1), len(1), type/TX(2), RX(2) = 6 */
	len -= 6 /* Skip magic and len */, offset += 5 /* magic already skept */;

	if(payload_len >= (offset+len)) {
	  u_int8_t  type_id = payload[offset];
	  u_int8_t  cause_tx = payload[offset+1] & 0x3F;
	  u_int8_t  negative = ((payload[offset+1] & 0x40) == 0x40) ? true : false;
	  u_int16_t asdu;
	  u_int64_t bit;
	  bool alerted = false;

	  offset += len + 2 /* magic and len */;

	  if(len >= 6)
	    asdu = /* ntohs */(*((u_int16_t*)&payload[4+offset]));
	  else
	    asdu = 0;

#ifdef DEBUG_IEC60870
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s] TypeId %u [offset %u/%u]", __FUNCTION__, type_id, offset, payload_len);
#endif

#ifdef IEC60870_TRACE
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] A-PDU I-%-3u [rx: %u][tx: %u][lost rx/tx: %u/%u]",
				       tx_direction ? "->" : "<-",
				       type_id, rx_seq_num , tx_seq_num,
				       pkt_lost.rx, pkt_lost.tx);
#endif

	  if(!initial_run) {
	    u_int32_t transition = (last_type_i << 8) + type_id;

	    it = type_i_transitions.find(transition);

	    if(it == type_i_transitions.end()) {
	      json_object *my_object;

	      if(f->get_duration() > ntop->getPrefs()->getIEC60870LearingPeriod()) {
#ifdef IEC60870_TRACE
		ntop->getTrace()->traceEvent(TRACE_NORMAL, "Found new transition %u -> %u", last_type_i, type_id);
#endif

		if((my_object = json_object_new_object()) != NULL) {
		  const char *json;

		  json_object_object_add(my_object, "timestamp", json_object_new_int(packet_time->tv_sec));
		  json_object_object_add(my_object, "flow_key", json_object_new_int(f->key()));
		  json_object_object_add(my_object, "flow_hash_entry_id", json_object_new_int(f->get_hash_entry_id()));
		  json_object_object_add(my_object, "from", json_object_new_int(last_type_i));
		  json_object_object_add(my_object, "to", json_object_new_int(type_id));

		  json = json_object_to_json_string(my_object);

#ifdef DEBUG_IEC60870
		  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s] Alert %s", __FUNCTION__, json);
#endif

		  ntop->getRedis()->rpush(CONST_IEC104_FLOW_ALERT_QUEUE, json, 1024 /* Max queue size */);
		  json_object_put(my_object); /* Free memory */
		}
		
		type_i_transitions[transition] = 2; /* Post Learning */
	      } else
		type_i_transitions[transition] = 1; /* During Learning */
	    } else
	      type_i_transitions[transition] = it->second + 1;
	  }

	  last_type_i = type_id;

	  it = typeid_uses.find(type_id);

	  if(it == typeid_uses.end())
	    typeid_uses[type_id] = 1;
	  else
	    typeid_uses[type_id] = it->second + 1;

	  if(type_id < 64) {
	    bit = ((u_int64_t)1) << type_id;
	    if((allowedTypeIDs[0] & bit) == 0) alerted = true;
	  } else if(type_id < 128) {
	    bit = ((u_int64_t)1) << (type_id-64);

	    if((allowedTypeIDs[1] & bit) == 0) alerted = true;
	  }

	  if(alerted) {
	    json_object *my_object;

	    if((my_object = json_object_new_object()) != NULL) {
	      const char *json;

	      json_object_object_add(my_object, "timestamp", json_object_new_int(packet_time->tv_sec));
	      json_object_object_add(my_object, "client", f->get_cli_host()->get_ip()->getJSONObject());
	      json_object_object_add(my_object, "server", f->get_srv_host()->get_ip()->getJSONObject());

	      if(f->get_vlan_id())
		json_object_object_add(my_object, "vlanId", json_object_new_int(f->get_vlan_id()));

	      json_object_object_add(my_object, "type_id", json_object_new_int(type_id));
	      json_object_object_add(my_object, "asdu", json_object_new_int(asdu));
	      json_object_object_add(my_object, "cause_tx", json_object_new_int(cause_tx));
	      json_object_object_add(my_object, "negative", json_object_new_boolean(negative));

	      json = json_object_to_json_string(my_object);

#ifdef DEBUG_IEC60870
	      ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s] Alert %s", __FUNCTION__, json);
#endif

	      ntop->getRedis()->rpush(CONST_IEC104_ALERT_QUEUE, json, 1024 /* Max queue size */);

	      json_object_put(my_object); /* Free memory */
	    }
	  }

	  /* Discard typeIds 127..255 */
	} else /* payload_len < len */
	  break;
      } else {
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "*** short APDUs");
	break;
      }

      if(payload[offset] == 0x68 /* IEC magic byte */)
	offset += 1; /* We skip the initial magic byte */
      else {
#ifdef DEBUG_IEC60870
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping IEC entry: no magic byte @ offset %u", offset);
#endif
	break;
      }
    } /* while */

    lock.unlock(__FILE__, __LINE__);
  }
}

/* *************************************** */

void IEC104Stats::lua(lua_State* vm) {
  lua_newtable(vm);

  lock.rdlock(__FILE__, __LINE__);

  /* *************************** */

  lua_newtable(vm);

  for(std::unordered_map<u_int16_t, u_int32_t>::iterator it = typeid_uses.begin();
      it != typeid_uses.end(); ++it) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%u", it->first);
    lua_push_int32_table_entry(vm, buf, it->second);
  }

  lua_pushstring(vm, "typeid");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *************************** */

  lua_newtable(vm);

  for(std::unordered_map<u_int16_t, u_int32_t>::iterator it = type_i_transitions.begin();
      it != type_i_transitions.end(); ++it) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%u,%u", (it->first >> 8), it->first & 0xFF);
    lua_push_int32_table_entry(vm, buf, it->second);
  }

  lua_pushstring(vm, "typeid_transitions");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lock.unlock(__FILE__, __LINE__);

  /* *************************** */

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "type_i", stats.type_i);
  lua_push_int32_table_entry(vm, "type_s", stats.type_s);
  lua_push_int32_table_entry(vm, "type_u", stats.type_u);
  lua_push_int32_table_entry(vm, "type_other", stats.type_other);
  lua_push_int32_table_entry(vm, "forward_msgs", stats.forward_msgs);
  lua_push_int32_table_entry(vm, "reverse_msgs", stats.reverse_msgs);
  lua_push_int32_table_entry(vm, "retransmitted_msgs", stats.retransmitted_msgs);
  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *************************** */

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "rx", pkt_lost.rx);
  lua_push_int32_table_entry(vm, "tx", pkt_lost.tx);
  lua_pushstring(vm, "pkt_lost");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *************************** */

  lua_newtable(vm);
  lua_push_float_table_entry(vm, "average", ndpi_data_average(i_s_apdu));
  lua_push_float_table_entry(vm, "stddev", ndpi_data_stddev(i_s_apdu));
  lua_pushstring(vm, "ack_time");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *************************** */

  lua_pushstring(vm, "iec104");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
