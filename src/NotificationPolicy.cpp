/*
 *
 * (C) 2026 - ntop.org
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

NotificationPolicy::NotificationPolicy(AlertLevel _minimum_severity,
                                       Bitmap128 _categories,
                                       Bitmap4096 _host_pools, Bitmap64 _tags,
                                       Bitmap64 _recipients) {
  minimum_severity = _minimum_severity;
  categories = _categories;
  host_pools = _host_pools;
  tags = _tags;
  recipients = _recipients;
  filter_categories = (categories.getNext(0) >= 0);
  filter_host_pools = (host_pools.getNext(0) >= 0);
}

/* *************************************** */

bool NotificationPolicy::match(const AlertFifoItem* const notification) const {
  u_int64_t raw_tags = tags.getBits64();

  if (notification->alert_severity < minimum_severity) return false;

  if (filter_categories && !categories.isSetBit(notification->alert_category))
    return false;

  if (filter_host_pools) {
    if (notification->alert_entity == alert_entity_flow) {
      if (!host_pools.isSetBit(notification->flow.cli_host_pool) &&
          !host_pools.isSetBit(notification->flow.srv_host_pool))
        return false;
    } else if (notification->alert_entity == alert_entity_host) {
      if (!host_pools.isSetBit(notification->host.host_pool)) return false;
    }
  }

  /* At least one of the tags */
  if (raw_tags != 0 && (notification->tags_bitmap & raw_tags) == 0)
    return false;

  return true;
}
