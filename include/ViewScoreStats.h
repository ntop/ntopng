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

#ifndef _NTOP_VIEW_SCORE_STATS_H_
#define _NTOP_VIEW_SCORE_STATS_H_

class ViewScoreStats : public ScoreStats {
 private:
  Mutex m;
  u_int32_t cli_dec[MAX_NUM_SCORE_CATEGORIES], srv_dec[MAX_NUM_SCORE_CATEGORIES];
  
 public:
  ViewScoreStats();
  ~ViewScoreStats() {};

  /* Total Getters */
  u_int64_t getClient() const { return(sum(cli_score) - sum(cli_dec)); };
  u_int64_t getServer() const { return(sum(srv_score) - sum(srv_dec)); };

  /* Getters by category */
  u_int32_t getClient(ScoreCategory sc) const { return(cli_score[sc] - cli_dec[sc]); };
  u_int32_t getServer(ScoreCategory sc) const { return(srv_score[sc] - srv_dec[sc]); };

  u_int16_t decValue(u_int16_t score, ScoreCategory score_category, bool as_client);
};

#endif
