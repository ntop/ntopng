/*
 *
 * (C) 2013-22 - ntop.org
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
#include "host_checks_includes.h"

#define NUM_CONSECUTIVE_CHECKS_BEFORE_ALERTING 5

/* ***************************************************** */

DangerousHost::DangerousHost() : HostCheck(ntopng_edition_community, false /* All interfaces */, true /* Exclude for nEdge */, false /* NOT only for nEdge */) {
  score_threshold = (u_int64_t)-1;
};

/* ***************************************************** */

void DangerousHost::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;

  if(h->getScore() > score_threshold)
    h->incrConsecutiveHighScore();
  else
    h->resetConsecutiveHighScore();

  if(h->getConsecutiveHighScore() > NUM_CONSECUTIVE_CHECKS_BEFORE_ALERTING) {
    if(!alert) { /* Alert not already triggered */
      /* Trigger the alert and add the host to the Default nProbe IPS host pool */
      alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE, h->getScore(), h->getConsecutiveHighScore());
    }

#ifdef NTOPNG_PRO
    /* Get nProbe IPS host pool ID */
    char buf[64], redis_host_key[CONST_MAX_LEN_REDIS_KEY];
    char host_buf[64], *e;
    u_int16_t host_pool_id = h->get_host_pool();

    /*
      Save the host based on if we have to serialize by Mac (DHCP) or by IP. The pool addition
      is deferred because pools reload is a costly operation 
    */
    if(h->serializeByMac()) {
      e = h->getMac()->print(buf, sizeof(buf));

      /* The MAC as-is */
      snprintf(host_buf, sizeof(host_buf), "%s", e);
    } else {
      e = h->get_ip()->print(buf, sizeof(buf));

      /* For hosts we need to add a VLAN and a subnet */
      snprintf(host_buf, sizeof(host_buf), "%s/%u@%u",
	       e,  h->get_ip()->isIPv4() ? 32 : 128, h->get_vlan_id());
    }

    /*
      If the host is not already jailed, ADD it to the queue of hosts that will be added to the jail and save its current pool.
      NOTE: Add to the queue only if the host is not already jailed to avoid extra unnecessry work.
     */
    if(host_pool_id != DROP_HOST_POOL_ID) {
      ntop->getRedis()->lpush(DROP_TMP_ADD_HOST_LIST, host_buf, 0);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Pushing to jail %s", host_buf);

      if(host_pool_id != NO_HOST_POOL_ID) {
	/* Save it's current pool so it will be restored once freed from the jail. Don't use a TTL. */
	snprintf(redis_host_key, sizeof(redis_host_key), DROP_HOST_POOL_PRE_JAIL_POOL, host_buf);
	ntop->getRedis()->set(redis_host_key, std::to_string(host_pool_id).c_str());

	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Remembering old pool %s", host_buf);
      }
    }

    /*
      Keep the host in jail, refresh it's TTL!
      NOTE: Refresh is always done, even if the host is already jailed. This is to make sure it will stay
      in the jail for at least DROP_HOST_POOL_EXPIRATION_TIME.
    */
    snprintf(redis_host_key, sizeof(redis_host_key), DROP_HOST_POOL_HOST_IN_JAIL, host_buf);
    ntop->getRedis()->set(redis_host_key, "1" /* Just a placeholder, TTL is what matters */,  DROP_HOST_POOL_EXPIRATION_TIME);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Refreshing TTL %s", redis_host_key);
#endif
    
    /* Refresh the alert */
    if(alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool DangerousHost::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    score_threshold = json_object_get_int64(json_threshold);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %u", json_object_to_json_string(config), p2p_bytes_threshold);

  return(true);
}

/* ***************************************************** */

