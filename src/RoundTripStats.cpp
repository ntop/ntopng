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

/* **************************************** */

RoundTripStats::RoundTripStats() {
    stats_it = 9; /* Last Item */
    memset(stats, 0, sizeof(stats));
}

/* **************************************** */

RoundTripStats::~RoundTripStats() {}
    
/* **************************************** */

// Add a point to the rt stats 
void RoundTripStats::addPoint(u_int32_t data) {
    stats_it = (stats_it + 1) % 10; // Max num entry is 10
    stats[stats_it] = data;
}

/* **************************************** */

void RoundTripStats::luaRTStats(lua_State* vm, const char *stats_name) {
    u_int8_t stats_it_shadow = stats_it; // Two threads could access this variable at the same time

    lua_newtable(vm);
        
    for (int i = 10; i > 0; i--) {
        int j = (stats_it_shadow + i) % 10;
        lua_pushinteger(vm, stats[j]);
        lua_rawseti(vm, -2, i);
    }

    lua_pushstring(vm, stats_name);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
}

/* **************************************** */

void RoundTripStats::sum(RoundTripStats *_stats) {
    u_int32_t *_viewed_stats = _stats->getStats();

    for (int i = 0; i < 10; i++)
        _viewed_stats[i] += stats[i];
}

/* **************************************** */
