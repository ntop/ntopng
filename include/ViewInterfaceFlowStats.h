/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _VIEW_INTERFACE_FLOW_STATS_
#define _VIEW_INTERFACE_FLOW_STATS_

class ViewInterfaceFlowStats {
 private:
   PartializableFlowTrafficStats partializable_stats;

   /* NOTE: these pointers cannot be normally accessed by the subinterfaces
    * as the same host may be used by more subinterfaces at the same time
    * (hosts belong to the ViewInterface). */
   Host *unsafe_cli;
   Host *unsafe_srv;

 public:
   ViewInterfaceFlowStats() {
     unsafe_cli = unsafe_srv = NULL;
   }

   inline void setClientHost(Host *host) 			 { unsafe_cli = host; };
   inline void setServerHost(Host *host) 			 { unsafe_srv = host; };
   inline PartializableFlowTrafficStats* getPartializableStats() { return(&partializable_stats); };
   inline Host* getViewSharedClient() 				 { return(unsafe_cli); };
   inline Host* getViewSharedServer() 				 { return(unsafe_srv); };
};

#endif
