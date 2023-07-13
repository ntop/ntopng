/*
 *
 * (C) 2019-23 - ntop.org
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

#ifndef _PORT_DETAILS_H_
#define _PORT_DETAILS_H_

#include "ntop_includes.h"

class PortDetails {
    private: 
        ndpi_protocol protocol;
        u_int64_t h_count;
    public:
        PortDetails(){
            h_count = 1;
        };
        ~PortDetails(){};

        void inc_h_count() { h_count++;};
        u_int64_t get_h_count() { return(h_count);};
        void set_protocol(ndpi_protocol _p) {protocol = _p;};
        ndpi_protocol get_protocol() {return(protocol);};

};

#endif /* _PORT_DETAILS_H_ */