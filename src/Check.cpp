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
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* **************************************************** */

Check::Check(NtopngEdition _edition, bool _packet_interface_only,
             bool _nedge_exclude, bool _nedge_only) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  check_edition = _edition;
  packet_interface_only = _packet_interface_only;
  nedge_exclude = _nedge_exclude;
  nedge_only = _nedge_only;
  enabled = false;
  tags_bitmap = 0;
};

/* **************************************************** */

Check::~Check() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
};

/* **************************************************** */

void Check::loadTags(json_object* tag_ids) {
  tags_bitmap = 0;

  if (!json_object_is_type(tag_ids, json_type_array)) return;

  for (size_t i = 0; i < json_object_array_length(tag_ids); i++) {
    int tag_id = json_object_get_int(json_object_array_get_idx(tag_ids, i));

    if ((tag_id >= 0) && (tag_id < 64)) tags_bitmap |= (1ULL << tag_id);
  }
}

/* **************************************************** */

bool Check::isCheckCompatibleWithEdition() const {
  /* Check first if the license allows script to be enabled */
  switch (check_edition) {
    case ntopng_edition_community:
      /* Ok */
      break;

    case ntopng_edition_pro:
#ifndef NTOPNG_PRO
      return (false);
#else
      if (!ntop->getPro()->is_pro_edition() /* includes Pro, Enterprise M/L */)
        return (false);
#endif
      break;

    case ntopng_edition_enterprise_m:
#ifndef NTOPNG_PRO
      return (false);
#else
      if (!ntop->getPro()->is_enterprise_m_edition() /* includes Enterprise M/L */)
        return (false);
#endif
      break;

    case ntopng_edition_enterprise_l:
#ifndef NTOPNG_PRO
      return (false);
#else
      if (!ntop->getPro()->is_enterprise_l_edition() /* includes L */)
        return (false);
#endif
      break;
  }

  return (true);
}

/* **************************************************** */

bool Check::isCheckCompatibleWithInterface(NetworkInterface* iface) {
  /* Version check, done at runtime as versions can change */
  if (!isCheckCompatibleWithEdition()) return (false);

  if (packet_interface_only && (!iface->isPacketInterface())) return (false);
#ifdef HAVE_NEDGE
  if (nedge_only && !ntop->getPro()->is_nedge_pro_edition()) return (false);
  if (nedge_exclude && ntop->getPro()->is_nedge_pro_edition()) return (false);
#else
  if (nedge_only) return (false);
#endif

  return (true);
}
