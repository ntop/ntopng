/*
 *
 * (C) 2017-23 - ntop.org
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

/* ******************************************************** */

void FrequentStringItems::add(char *key, u_int32_t value) {
  std::map<std::string, u_int32_t>::iterator it;

  m.lock(__FILE__, __LINE__);

  it = q.find(std::string(key));

  if (it != q.end())
    it->second += value;
  else {
    if (q.size() > max_items_threshold) prune();

    q[std::string(key)] = value;
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

static bool sortByVal(const pair<u_int32_t, std::string> &a,
                      const pair<u_int32_t, std::string> &b) {
  return (a.first < b.first);
}

void FrequentStringItems::prune() {
  /* No lock here */
  u_int32_t num = 0;
  std::vector<std::pair<u_int32_t, std::string>> vec;

  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  for (std::map<std::string, u_int32_t>::iterator it1 = q.begin();
       it1 != q.end(); ++it1)
    vec.push_back(std::make_pair(it1->second, it1->first));

  sort(vec.begin(), vec.end(), sortByVal);

  for (std::vector<std::pair<u_int32_t, std::string>>::iterator it2 =
           vec.begin();
       it2 != vec.end(); ++it2) {
    if (++num < max_items) {
      /*
      u_int32_t id  = it2.first;
      std::string k = it2->second;
      q.erase(k);
      */
    } else
      break;
  }
}

/* ******************************************************** */

/*
  Entries are sorted first and only the top X (by value)
  are serialized to JSON
*/
char *FrequentStringItems::json(u_int32_t max_num_items) {
  json_object *j;
  char *rsp;
  vector<pair<std::string, u_int32_t>> vec;

  if ((j = json_object_new_object()) == NULL) return (NULL);

  m.lock(__FILE__, __LINE__);

  for (std::map<std::string, u_int32_t>::iterator it = q.begin(); it != q.end();
       ++it)
    vec.push_back(make_pair(it->first, it->second));

  m.unlock(__FILE__, __LINE__);

  std::sort(vec.begin(), vec.end(),
            [](const pair<std::string, u_int32_t> &a,
               const pair<std::string, u_int32_t> &b) {
              /* Sort by value (top to bottom) */
              return (a.second > b.second);
            });

  for (u_int i = 0; i < vec.size(); i++) {
    if (i == max_num_items) break;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s = %u",
    // vec[i].first.c_str(), vec[i].second);

    json_object_object_add(j, vec[i].first.c_str(),
                           json_object_new_int64(vec[i].second));
  }

  rsp = strdup(json_object_to_json_string(j));

  json_object_put(j); /* Free memory */

  return (rsp);
}

/* ******************************************* */

#ifdef TESTME

void testme() {
  FrequentStringItems *f = new (std::nothrow) FrequentStringItems(8);

  for (int i = 0; i < 256; i++) {
    char buf[32];

    snprintf(buf, sizeof(buf), "%u", i % 24);
    f->add(buf, rand());
  }

  f->print();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", f->json());

  exit(0);
}

#endif
