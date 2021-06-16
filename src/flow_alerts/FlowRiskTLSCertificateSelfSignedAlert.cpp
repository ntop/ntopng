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

#include "flow_checks_includes.h"

ndpi_serializer* FlowRiskTLSCertificateSelfSignedAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();
  char *s;
  
  if(!serializer) return(NULL);

  FlowRiskTLSAlert::getAlertJSON(serializer);

  if((s = f->getTLSCertificateIssuerDN()) != NULL)
    ndpi_serialize_string_string(serializer, "protos.tls.issuerDN", s);

  if((s = f->getTLSCertificateSubjectDN()) != NULL)
    ndpi_serialize_string_string(serializer, "protos.tls.subjectDN", s);

  return(serializer);
}

