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

#ifndef _UNEXPECTED_HOST_H_
#define _UNEXPECTED_HOST_H_

#include "ntop_includes.h"

class UnexpectedServer : public FlowCheck {
 private:
  ndpi_ptree_t *whitelist;

  virtual FlowAlertType getAlertType() const = 0;

protected:
  bool isAllowedHost(const IpAddress *p);

  virtual bool isAllowedProto(Flow *f)          { return(false); }
  virtual const IpAddress* getServerIP(Flow *f) { return(f->get_srv_ip_addr()); }

public:
  UnexpectedServer() : FlowCheck(ntopng_edition_community,
				  false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */,
				  true /* has_protocol_detected */, false /* has_periodic_update */, false /* has_flow_end */) {
    if((whitelist = ndpi_ptree_create()) == NULL)
      throw "Out of memory";
  };

  ~UnexpectedServer() {
    if(whitelist)
      ndpi_ptree_destroy(whitelist);
  };

  void protocolDetected(Flow *f);
  bool loadConfiguration(json_object *config);
};

#endif /* _UNEXPECTED_HOST_H_ */
