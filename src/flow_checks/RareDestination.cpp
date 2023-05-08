/*
 *
 * (C) 2013-23 - ntop.org
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
#include "flow_checks_includes.h"

#define TODO_HERE 1
#define rareDestEpoch 100  /* placeholder value */

/* ***************************************************** */

bool getDestinationHash(Flow *f, u_int32_t *hash) {
  Host * dest = f->get_srv_host();
  if (f->isLocalToLocal()) {
    char buf[64];
    if (!dest->isMulticastHost() && dest->isDHCPHost()) {
      char *mac = dest->getMac()->print(buf,sizeof(buf));
      *hash = Utils::hashString(mac);
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination MAC %u - %s", *hash, mac); */
      return (true);
    }
    
    if (dest->isIPv6() || dest->isIPv4()) {
      char *ip = dest->get_ip()->print(buf,sizeof(buf));
      *hash = Utils::hashString(ip);
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination IPv6/IPv4 %u - %s", *hash, ip); */
      return (true);
    }
  }
  if (f->isLocalToRemote()) {
    char name_buf[128];
    char *domain = dest->get_name(name_buf, sizeof(name_buf), false);
    *hash = Utils::hashString(domain);
    /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare remote destination %u - %s", *hash, domain); */
    return (true);
  }
  return (false);
}

/* ***************************************************** */

/*
  ndpi_bitmap_xor(ndpi_bitmap*, ndpi_bitmap*) defined in ndpi_api.h
*/

void RareDestination::protocolDetected(Flow *f) {
  bool is_rare_destination = false;

  /* TODO: check if this is a real rare destination */
  if(f->getFlowServerInfo() != NULL) {
#ifdef TODO_HERE
    u_int32_t hash = 0;
    if(!getDestinationHash(f,&hash)) { return; }
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare destination hash %u", hash);

    time_t timeNow = time(nullptr);
    Host *cliHost = f->get_cli_host();
    ndpi_bitmap *rare_dest = cliHost->getRareDestBMap();
    ndpi_bitmap *rare_dest_revise = cliHost->getRareDestReviseBMap();

    if (!ndpi_bitmap_cardinality(rare_dest)) {
      cliHost->setOngoingRareDestTraining(true);
      cliHost->clearSeenRareDestTraining();
      cliHost->setStartRareDestTraining(timeNow);
    }
    if (cliHost->isOngoingRareDestTraining() && cliHost->getSeenRareDestTraining() >= cliHost->getToSeeRareDestTraining() && timeNow - cliHost->getStartRareDestTraining() >= cliHost->getDurationRareDestTraining())
      cliHost->setOngoingRareDestTraining(false);

    if (!cliHost->isOngoingRareDestTraining() && timeNow - cliHost->getRareDestLastEpoch() >= rareDestEpoch) {
      if (timeNow - cliHost->getRareDestLastEpoch() >= 2*rareDestEpoch) {
        ndpi_bitmap_clear(rare_dest);
        ndpi_bitmap_clear(rare_dest_revise);
      } else {
        ndpi_bitmap_xor(rare_dest_revise, rare_dest);  // updates rare_dest_revise
        ndpi_bitmap_and(rare_dest, rare_dest_revise); // makes rare_dest = rare_dest_revise
      }
      cliHost->setRareDestLastEpoch(timeNow);
    }

    if (!hash) {
      if (ndpi_bitmap_isset(rare_dest, hash)
        ndpi_bitmap_unset(rare_dest_revise, hash);
      else {
        ndpi_bitmap_set(rare_dest, hash);
        if (!cliHost->isOngoingRareDestTraining()) is_rare_destination = true;
        else cliHost->incrementSeenRareDestTrainig();
      }
    }
    /* error: hashing not possible */

    //is_rare_destination = true;
#endif
  }
  
  if(is_rare_destination) {
    FlowAlertType alert_type = RareDestinationAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE; 
    
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
    
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert* RareDestination::buildAlert(Flow *f) {
  return new RareDestinationAlert(this, f);
}

/* ***************************************************** */
