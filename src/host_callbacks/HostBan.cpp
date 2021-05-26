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
#include "host_callbacks_includes.h"

/* ***************************************************** */

HostBan::HostBan() : HostCallback(ntopng_edition_community) {
  score_threshold = (u_int64_t)-1;
};

/* ***************************************************** */

void HostBan::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;

  if(h->getScore() > score_threshold)
    h->incrConsecutiveHighScore();
  else
    h->resetConsecutiveHighScore();
  
  if(h->getConsecutiveHighScore() > 5) {
    if (!alert) { /* Alert not already triggered */
      /* Trigger the alert and add the host to the Default nProbe IPS host pool */
      alert = allocAlert(this, h, SCORE_LEVEL_ERROR, 0, h->getScore(), h->getConsecutiveHighScore());

#ifdef NTOPNG_PRO
      /* Get nProbe IPS host pool ID */
      HostPools* pool = h->getInterface()->getHostPools();
      u_int8_t poolId = pool->getPoolByName(DROP_HOST_POOL_NAME);
      
      char ipbuf[64], redis_host_key[256];
      struct timeval tp;

      gettimeofday(&tp, NULL);
  
      double time = (((double)tp.tv_usec) / (double)1000000) + tp.tv_sec;

      /* Save the host based on if we have to serialize by Mac (DHCP) or by IP */
      if(h->serializeByMac()) {
	ntop->addToPool(h->getMac()->print(ipbuf, sizeof(ipbuf)), poolId);
	snprintf(redis_host_key, sizeof(redis_host_key), "%s_%lf", h->getMac()->print(ipbuf, sizeof(ipbuf)), time);
      }
      else {
	ntop->addToPool(h->get_ip()->print(ipbuf, sizeof(ipbuf)), poolId);
	snprintf(redis_host_key, sizeof(redis_host_key), "%s_%lf", h->get_ip()->print(ipbuf, sizeof(ipbuf)), time);
      }

      ntop->getRedis()->rpush((char*) DROP_HOST_POOL_LIST, redis_host_key, 3600);
#endif
    }

    /* Refresh */
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool HostBan::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCallback::loadConfiguration(config); /* Parse parameters in common */

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    score_threshold = json_object_get_int64(json_threshold);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %u", json_object_to_json_string(config), p2p_bytes_threshold);

  return(true);
}

/* ***************************************************** */

