/*
 *
 * (C) 2013-20 - ntop.org
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

DnsStats::DnsStats() {
  memset(&sent_stats.breakdown, 0, sizeof(sent_stats.breakdown)),
    memset(&rcvd_stats.breakdown, 0, sizeof(rcvd_stats.breakdown));
  sent_stats.num_queries.reset(), sent_stats.num_replies_ok.reset(), sent_stats.num_replies_error.reset(),
    rcvd_stats.num_queries.reset(), rcvd_stats.num_replies_ok.reset(), rcvd_stats.num_replies_error.reset();
}

/* *************************************** */

void DnsStats::incStats(bool as_client, const FlowDNSStats *fts) {
  struct dns_stats *qry = as_client ? &sent_stats : &rcvd_stats;
  struct dns_stats *rsp = as_client ? &rcvd_stats : &sent_stats;
  u_int16_t tot_qry = 0;

  if(fts->num_a)     qry->breakdown.num_a     += fts->num_a,     tot_qry += fts->num_a;
  if(fts->num_ns)    qry->breakdown.num_ns    += fts->num_ns,    tot_qry += fts->num_ns;
  if(fts->num_cname) qry->breakdown.num_cname += fts->num_cname, tot_qry += fts->num_cname;
  if(fts->num_soa)   qry->breakdown.num_soa   += fts->num_soa,   tot_qry += fts->num_soa;
  if(fts->num_ptr)   qry->breakdown.num_ptr   += fts->num_ptr,   tot_qry += fts->num_ptr;
  if(fts->num_mx)    qry->breakdown.num_mx    += fts->num_mx,    tot_qry += fts->num_mx;
  if(fts->num_txt)   qry->breakdown.num_txt   += fts->num_txt,   tot_qry += fts->num_txt;
  if(fts->num_aaaa)  qry->breakdown.num_aaaa  += fts->num_aaaa,  tot_qry += fts->num_aaaa;
  if(fts->num_any)   qry->breakdown.num_any   += fts->num_any,   tot_qry += fts->num_any;
  if(fts->num_other) qry->breakdown.num_other += fts->num_other, tot_qry += fts->num_other;
  if(tot_qry)        qry->num_queries.inc(tot_qry);

  if(fts->num_replies_ok)    rsp->num_replies_ok.inc(fts->num_replies_ok);
  if(fts->num_replies_error) rsp->num_replies_error.inc(fts->num_replies_error);
}

/* *************************************** */

void DnsStats::luaStats(lua_State *vm, struct dns_stats *stats, const char *label, bool verbose) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "num_queries", stats->num_queries.get());
  lua_push_uint64_table_entry(vm, "num_replies_ok", stats->num_replies_ok.get());
  lua_push_uint64_table_entry(vm, "num_replies_error", stats->num_replies_error.get());

  if(verbose){
    lua_newtable(vm);
    lua_push_uint64_table_entry(vm, "num_a", stats->breakdown.num_a);
    lua_push_uint64_table_entry(vm, "num_ns", stats->breakdown.num_ns);
    lua_push_uint64_table_entry(vm, "num_cname", stats->breakdown.num_cname);
    lua_push_uint64_table_entry(vm, "num_soa", stats->breakdown.num_soa);
    lua_push_uint64_table_entry(vm, "num_ptr", stats->breakdown.num_ptr);
    lua_push_uint64_table_entry(vm, "num_mx", stats->breakdown.num_mx);
    lua_push_uint64_table_entry(vm, "num_txt", stats->breakdown.num_txt);
    lua_push_uint64_table_entry(vm, "num_aaaa", stats->breakdown.num_aaaa);
    lua_push_uint64_table_entry(vm, "num_any", stats->breakdown.num_any);
    lua_push_uint64_table_entry(vm, "num_other", stats->breakdown.num_other);
    lua_pushstring(vm, "queries");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void DnsStats::lua(lua_State *vm, bool verbose) {
  lua_newtable(vm);

  luaStats(vm, &sent_stats, "sent", verbose);
  luaStats(vm, &rcvd_stats, "rcvd", verbose);

  lua_pushstring(vm, "dns");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

bool DnsStats::hasAnomalies(time_t when) {
  return sent_stats.num_queries.is_misbehaving(when)
    || sent_stats.num_replies_ok.is_misbehaving(when)
    || sent_stats.num_replies_error.is_misbehaving(when)
    || rcvd_stats.num_queries.is_misbehaving(when)
    || rcvd_stats.num_replies_ok.is_misbehaving(when)
    || rcvd_stats.num_replies_error.is_misbehaving(when);
}

/* *************************************** */

void DnsStats::luaAnomalies(lua_State *vm, time_t when) {
  if(sent_stats.num_queries.is_misbehaving(when))
    sent_stats.num_queries.lua(vm, "dns.sent.num_queries");
  if(sent_stats.num_replies_ok.is_misbehaving(when))
    sent_stats.num_replies_ok.lua(vm, "dns.sent.num_replies_ok");
  if(sent_stats.num_replies_error.is_misbehaving(when))
    sent_stats.num_replies_error.lua(vm, "dns.sent.num_replies_error");

  if(rcvd_stats.num_queries.is_misbehaving(when))
    rcvd_stats.num_queries.lua(vm, "dns.rcvd.num_queries");
  if(rcvd_stats.num_replies_ok.is_misbehaving(when))
    rcvd_stats.num_replies_ok.lua(vm, "dns.rcvd.num_replies_ok");
  if(rcvd_stats.num_replies_error.is_misbehaving(when))
    rcvd_stats.num_replies_error.lua(vm, "dns.rcvd.num_replies_error");  
}

/* *************************************** */

char* DnsStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void DnsStats::deserializeStats(json_object *o, struct dns_stats *stats) {
  json_object *obj, *s;

  if(json_object_object_get_ex(o, "num_queries", &obj)) stats->num_queries.setInitialValue(json_object_get_int64(obj));
  if(json_object_object_get_ex(o, "num_replies_ok", &obj)) stats->num_replies_ok.setInitialValue(json_object_get_int64(obj));
  if(json_object_object_get_ex(o, "num_replies_error", &obj)) stats->num_replies_error.setInitialValue(json_object_get_int64(obj));

  memset(&stats->breakdown, 0, sizeof(stats->breakdown));
  if(json_object_object_get_ex(o, "stats", &s)) {
    if (json_object_object_get_ex(s, "num_a", &obj)) stats->breakdown.num_a = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_ns", &obj)) stats->breakdown.num_ns = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_cname", &obj)) stats->breakdown.num_cname = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_soa", &obj)) stats->breakdown.num_soa = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_ptr", &obj)) stats->breakdown.num_ptr = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_mx", &obj)) stats->breakdown.num_mx = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_txt", &obj)) stats->breakdown.num_txt = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_aaaa", &obj)) stats->breakdown.num_aaaa = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_any", &obj)) stats->breakdown.num_any = (u_int32_t)json_object_get_int64(obj);
    if (json_object_object_get_ex(s, "num_other", &obj)) stats->breakdown.num_other = (u_int32_t)json_object_get_int64(obj);
  }
}

/* ******************************************* */

void DnsStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "sent", &obj))
    deserializeStats(obj, &sent_stats);  

  if(json_object_object_get_ex(o, "rcvd", &obj))
    deserializeStats(obj, &rcvd_stats);  
}

/* ******************************************* */

json_object* DnsStats::getStatsJSONObject(struct dns_stats *stats) {
  json_object *my_object = json_object_new_object();
  json_object *my_stats = json_object_new_object();

  if(stats->num_queries.get() > 0) json_object_object_add(my_object, "num_queries", json_object_new_int64(stats->num_queries.get()));
  if(stats->num_replies_ok.get() > 0) json_object_object_add(my_object, "num_replies_ok", json_object_new_int64(stats->num_replies_ok.get()));
  if(stats->num_replies_error.get() > 0) json_object_object_add(my_object, "num_replies_error", json_object_new_int64(stats->num_replies_error.get()));
 
  if(stats->breakdown.num_a > 0) json_object_object_add(my_stats, "num_a", json_object_new_int64(stats->breakdown.num_a));
  if(stats->breakdown.num_ns > 0) json_object_object_add(my_stats, "num_ns", json_object_new_int64(stats->breakdown.num_ns));
  if(stats->breakdown.num_cname > 0) json_object_object_add(my_stats, "num_cname", json_object_new_int64(stats->breakdown.num_cname));
  if(stats->breakdown.num_soa > 0) json_object_object_add(my_stats, "num_soa", json_object_new_int64(stats->breakdown.num_soa));
  if(stats->breakdown.num_ptr > 0) json_object_object_add(my_stats, "num_ptr", json_object_new_int64(stats->breakdown.num_ptr));
  if(stats->breakdown.num_mx > 0) json_object_object_add(my_stats, "num_mx", json_object_new_int64(stats->breakdown.num_mx));
  if(stats->breakdown.num_txt > 0) json_object_object_add(my_stats, "num_txt", json_object_new_int64(stats->breakdown.num_txt));
  if(stats->breakdown.num_aaaa > 0) json_object_object_add(my_stats, "num_aaaa", json_object_new_int64(stats->breakdown.num_aaaa));
  if(stats->breakdown.num_any > 0) json_object_object_add(my_stats, "num_any", json_object_new_int64(stats->breakdown.num_any));
  if(stats->breakdown.num_other > 0) json_object_object_add(my_stats, "num_other", json_object_new_int64(stats->breakdown.num_other));
  json_object_object_add(my_object, "stats", my_stats);

  return(my_object);
}

/* ******************************************* */

json_object* DnsStats::getJSONObject() {
  json_object *my_object = json_object_new_object();

  json_object_object_add(my_object, "sent", getStatsJSONObject(&sent_stats));
  json_object_object_add(my_object, "rcvd", getStatsJSONObject(&rcvd_stats));
  
  return(my_object);
}

/* ******************************************* */

void DnsStats::updateStats(const struct timeval * const tv) {
  time_t when = tv->tv_sec;

  sent_stats.num_queries.computeAnomalyIndex(when),
    sent_stats.num_replies_ok.computeAnomalyIndex(when),
    sent_stats.num_replies_error.computeAnomalyIndex(when);
  rcvd_stats.num_queries.computeAnomalyIndex(when),
    rcvd_stats.num_replies_ok.computeAnomalyIndex(when),
    rcvd_stats.num_replies_error.computeAnomalyIndex(when);

#if 0
  char buf[64];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "sent.num_queries: %s",
			       sent_stats.num_queries.print(buf, sizeof(buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "sent.num_replies_ok: %s",
			       sent_stats.num_replies_ok.print(buf, sizeof(buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "sent.num_replies_error: %s",
			       sent_stats.num_replies_error.print(buf, sizeof(buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "rcvd.num_queries: %s",
			       rcvd_stats.num_queries.print(buf, sizeof(buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "rcvd.num_replies_ok: %s",
			       rcvd_stats.num_replies_ok.print(buf, sizeof(buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "rcvd.num_replies_error: %s",
			       rcvd_stats.num_replies_error.print(buf, sizeof(buf)));
#endif
}
