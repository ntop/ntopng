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

/* ********************************************************** */

/**
 * Constructor: initialized the bitmask
 * @param num_tot_elems The bitmask size in number of bit.
 */
Bitmask::Bitmask(u_int32_t num_tot_elems) {  
  tot_elems = num_tot_elems;
  num_elems = tot_elems/8;

  if(num_elems == 0 || tot_elems != num_elems*8) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unexpected bitmask length. Leaving...");
    exit(-1);
  }

  bits = (u_int32_t *) malloc(num_elems);

  if (!bits) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory. Leaving...");
    exit(-1);
  }

  memset(bits, 0, num_elems);
}

/* ********************************************************** */

/**
 * Destructor. 
 */
Bitmask::~Bitmask() {
  if(bits) free(bits);
}

/* ********************************************************** */

/**
 * Prints the content of the bitmask.
 */
void Bitmask::print() {
  u_int32_t len = 8 * sizeof(bits);
    
  ntop->getTrace()->traceEvent(TRACE_INFO, "Matches: ");

  for(u_int32_t i=0; i<len; i++)
    if(is_set_bit(i)) ntop->getTrace()->traceEvent(TRACE_INFO, "[%d]", i);
 
   printf("\n");
}

/* ********************************************************** */

void Bitmask::bitmask_set(u_int32_t n) {
  u_int32_t idx = (n >> 5);

  if(idx >= num_elems) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: Bitmask::bitmask_set(%u) out of range (%u >= %u)", n, idx, num_elems);
    return;
  }

  bits[idx] |=  (1 << (n & 0x1F));
}

/* ********************************************************** */

void Bitmask::bitmask_clr(u_int32_t n) {
  u_int32_t idx = (n >> 5);

  if(idx >= num_elems) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: Bitmask::bitmask_clr(%u) out of range (%u >= %u)", n, idx, num_elems);
    return;
  }

  bits[idx] &= ~(1 << (n & 0x1F));
}

/* ********************************************************** */

bool Bitmask::bitmask_isset(u_int32_t n) {
  u_int32_t idx = (n >> 5);

  if(idx >= num_elems) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: Bitmask::bitmask_isset(%u) out of range (%u >= %u)", n, idx, num_elems);
    return(false);
  }

  return(((bits[idx] & (1 << (n & 0x1F)))) ? true : false);
}
