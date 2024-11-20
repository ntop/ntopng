/*
 *
 * (C) 2013-24 - ntop.org
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

void TCPProbingAttempt::flowEnd(Flow *f){
    if((f->get_protocol() == IPPROTO_TCP) && (!f->isThreeWayHandshakeOK())) {
        FlowAlertType alert_type = TCPProbingAttemptAlert::getClassType();
        u_int8_t c_score, s_score;
        risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;

        if(f->get_ndpi_flow())
            ndpi_set_risk(f->get_ndpi_flow(), NDPI_PROBING_ATTEMPT, (char*) "TCP Probing");        
        
        f->setRisk(f->getRiskBitmap() | NDPI_PROBING_ATTEMPT);

        computeCliSrvScore(ntop->getFlowAlertScore(alert_type.id), cli_score_pctg, &c_score, &s_score);
        f->triggerAlertAsync(alert_type, c_score, s_score);
    }
}

FlowAlert* TCPProbingAttempt::buildAlert(Flow *f){
    TCPProbingAttemptAlert *alert = new (std::nothrow) TCPProbingAttemptAlert(this, f);
    return alert;
}