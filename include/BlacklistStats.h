/*
 *
 * (C) 2019-22 - ntop.org
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

#ifndef _BLACKLIST_STATS_H_
#define _BLACKLIST_STATS_H_


class BlacklistStats {
 private:
  std::unordered_map<std::string, BlacklistUsageStats> stats;

 public:
  BlacklistStats() { ; }

#ifdef FULL_BL_STATS
  void inc(std::string name, u_int32_t tp, u_int32_t fp, u_int32_t fn, u_int32_t tn);
#endif

  void      incHits(std::string name);
  u_int32_t getNumHits(std::string name);
  void      lua(lua_State* vm);
};

#endif /* _BLACKLIST_STATS_H_ */
