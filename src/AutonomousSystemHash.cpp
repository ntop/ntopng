/*
 *
 * (C) 2013-26 - ntop.org
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
 *x
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ************************************ */

AutonomousSystemHash::AutonomousSystemHash(NetworkInterface* _iface,
                                           u_int _num_hashes,
                                           u_int _max_hash_size)
    : GenericHash(_iface, _num_hashes, _max_hash_size, "AutonomousSystemHash") {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
}

/* ************************************ */

AutonomousSystem* AutonomousSystemHash::get(IpAddress* ipa,
                                            bool is_inline_call) {
  u_int32_t asn;

  ntop->getGeolocation()->getAS(ipa, &asn,
                                NULL /* Don't care about AS name here */);

  return (get(asn, is_inline_call));
}

/* ************************************ */

AutonomousSystem* AutonomousSystemHash::get(u_int32_t asn, bool is_inline_call,
                                            bool inc_uses) {
  u_int32_t hash = asn % num_hashes;

  if (table[hash] == NULL) {
    return (NULL);
  } else {
    AutonomousSystem* head;

    if (!is_inline_call) locks[hash]->rdlock(__FILE__, __LINE__);

    head = (AutonomousSystem*)table[hash];

    while (head != NULL) {
      if (!head->idle() && head->equal(asn))
        break;
      else
        head = (AutonomousSystem*)head->next();
    }

    if (head && inc_uses) head->incUses(); /* Under the bucket lock */

    if (!is_inline_call) locks[hash]->unlock(__FILE__, __LINE__);

    return (head);
  }
}

/* ************************************ */

#ifdef AS_DEBUG

static bool print_ases(GenericHashEntry* _as, void* user_data) {
  AutonomousSystem* as = (AutonomousSystem*)_as;

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "Autonomous System [asn: %u] [asname: %s] [num_uses: %u]",
      as->get_asn(), as->get_asname(), as->getNumHosts());

  return (false); /* false = keep on walking */
}

/* ************************************ */

void AutonomousSystemHash::printHash() {
  disablePurge();

  walk(print_ases, NULL);

  enablePurge();
}

#endif

static bool update_ases_prefs(GenericHashEntry* _as, void* user_data,
                              bool* entry_matched) {
  AutonomousSystem* as = (AutonomousSystem*)_as;
  if (ntop->getPrefs()->isCustomerASN(as->get_asn()) ||
      ntop->getPrefs()->isSubCustomerASN(as->get_asn()) ||
      ntop->getPrefs()->isRemoteASN(as->get_asn())) {
    as->saveExporterStatsPrefs(true);
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG, "Autonomous System [asn: %u] [exporter stats: true]",
        as->get_asn());
  } else {
    as->saveExporterStatsPrefs(false);
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG, "Autonomous System [asn: %u] [exporter stats: false]",
        as->get_asn());
  }
  return (false); /* false = keep on walking */
}

/* ************************************ */

void AutonomousSystemHash::updateASNExportersPrefs() {
  if (getNumEntries() > 0) {
    u_int32_t begin_slot = 0;
    walk(&begin_slot, true, update_ases_prefs, NULL);
  }
}
