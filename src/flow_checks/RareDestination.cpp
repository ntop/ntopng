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

/* ***************************************************** */

u_int32_t RareDestination::getDestinationHash(Flow *f) {
  u_int32_t hash = 0;
  Host *dest = f->get_srv_host();

  if (f->isLocalToLocal()) {
    char buf[64];
    if (!dest->isMulticastHost() && dest->isDHCPHost()) {
      /* u_int32_t mac = dest->getMac()->key();
      hash = mac; */

      char *mac = dest->getMac()->print(buf,sizeof(buf));
      hash = Utils::hashString(mac);

      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination MAC %u - %s", hash, mac);
    }
    else if (dest->isIPv6() || dest->isIPv4()) {
      //hash = dest->key();

      char *ip = dest->get_ip()->print(buf,sizeof(buf));
      hash = Utils::hashString(ip);

      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination IPv6/IPv4 %u - %s", hash, ip);
    }
  } else if (f->isLocalToRemote()) {
    char name_buf[128];
    char *domain = dest->get_name(name_buf, sizeof(name_buf), false);
    hash = Utils::hashString(domain);

    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare remote destination %u - %s - %s", hash, domain, dest->getServerName(name_buf, sizeof(name_buf)));
  }

  return hash;
}

/* ***************************************************** */

void RareDestination::protocolDetected(Flow *f) {

  bool is_rare_destination = false;

  if(f->getFlowServerInfo() != NULL) {
    if(!f->get_cli_host()->isLocalHost()) return;
    
    LocalHost *cli_lhost = (LocalHost*)f->get_cli_host();
    ndpi_bitmap *rare_dest = cli_lhost->getRareDestBitmap();
    
    /* char hostbuf[64], *host_id;
    host_id = cli_lhost->get_hostkey(hostbuf, sizeof(hostbuf)); */

    time_t t_now = time(NULL);

    /* check if training has to start */
    if (!cli_lhost->getStartRareDestTraining()) {
      cli_lhost->startRareDestTraining();
      cli_lhost->setStartRareDestTraining(t_now);
      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Training On at %ld ~ %s", t_now, host_id );
    }

    /* if host is training */
    if (cli_lhost->isTrainingRareDest()) {
      u_int32_t hash = getDestinationHash(f);
      /* if(hash == 0) return; */

      /* update */
      if ( hash && !ndpi_bitmap_isset(rare_dest, hash)) {
        ndpi_bitmap_set(rare_dest, hash);
        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Hash %s added ~ %s", f->getFlowServerInfo(), host_id );
      }

      /* check if training has to end */
      if (t_now - cli_lhost->getStartRareDestTraining() >= 300 /* 1h RARE_DEST_DURATION_TRAINING */ )
      {
        cli_lhost->stopRareDestTraining();
        cli_lhost->setLastRareDestTraining(t_now);
        
        cli_lhost->addRareDestBitmaps();
        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Training Off at %ld ~ %s", t_now, host_id );
      }
      
      return;
    }

    if ( t_now - cli_lhost->getLastRareDestTraining() > 600 /* 10min RARE_DEST_LAST_TRAINING_GAP */ )
    {
      cli_lhost->mergeRareDestBitmaps();
      cli_lhost->setStartRareDestTraining(0);
      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Merged Bitmaps %s", host_id );
      return;
    }
    
    
    u_int32_t hash = getDestinationHash(f);
    /* if(hash == 0) return; */

    /* update */
    if (hash && !ndpi_bitmap_isset(rare_dest, hash)){
      ndpi_bitmap_set(rare_dest, hash); // Fire an alarm only once
      is_rare_destination = true;
    }

  }

  if (is_rare_destination) {
    FlowAlertType alert_type = RareDestinationAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;

    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *RareDestination::buildAlert(Flow *f) {
  return new RareDestinationAlert(this, f);
}

/* ***************************************************** */
