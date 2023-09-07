/*
 *
 * (C) 2013-23 - ntop.org
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

Redis::Redis(const char *redis_host /* = NULL */,
             const char *redis_password /* = NULL */,
             u_int16_t redis_port /* = 0 */, u_int8_t _redis_db_id /* = 0 */,
             bool giveup_on_failure /* = false */) {
    this->redisVersion = "RedisStub";
    this->localToResolve =
        std::make_unique<StringFifoQueue>(MAX_NUM_QUEUED_ADDRS);
    this->remoteToResolve =
        std::make_unique<StringFifoQueue>(MAX_NUM_QUEUED_ADDRS);

    memset(&stats, 0, sizeof(stats));
}

bool Redis::checkList(std::string key) {
    return (this->store.find(key) == this->store.end() &&
            this->setStore.find(key) == this->setStore.end());
}

bool Redis::checkSet(std::string key) {
    return (this->store.find(key) == this->store.end() &&
            this->listStore.find(key) == this->listStore.end());
}

char *Redis::getVersion() { return (char *)this->redisVersion.c_str(); }

u_int32_t Redis::getNumVersion() { return 1; }

bool Redis::haveRedisDump() { return false; }

void Redis::setDefaults() {}

bool Redis::isOperational() { return true; }

void Redis::setInitializationComplete() {}

int Redis::info(char *rsp, u_int rsp_len) {
    if (rsp_len == 0) return -1;

    stats.num_other++;
    if(rsp_len == 0)
      return -1;
    
    rsp[0] = 0;
    return 0;
}

u_int Redis::dbsize() {
    stats.num_other++;
    return this->store.size();
}

int Redis::expire(char *key, u_int expire_sec) {
    stats.num_expire++;
    return 0;
}

int Redis::get(char *key, char *rsp, u_int rsp_len,
               bool cache_it /* = false */) {
    if (rsp_len == 0) return -1;

    stats.num_get++;
    std::string strKey(key);
    if (this->store.find(strKey) == this->store.end() ||
        snprintf(rsp, rsp_len, "%s", this->store[strKey].c_str()) < 0) {
        rsp[0] = 0;
        return -1;
    }

    return 0;
}

int Redis::hashGet(const char *key, const char *member, char *const rsp,
                   u_int rsp_len) {
    if (rsp_len == 0) return -1;

    std::stringstream ss;
    ss << key << "@" << member;
    std::string strKey = ss.str();
    if (this->store.find(strKey) == this->store.end() ||
        snprintf(rsp, rsp_len, "%s", this->store[strKey].c_str()) < 0) {
        rsp[0] = 0;
        return -1;
    }

    return 0;
}

int Redis::hashDel(const char *key, const char *field) {
    std::stringstream ss;
    ss << key << "@" << field;
    std::string strKey = ss.str();
    this->store.erase(strKey);
    return 0;
}

int Redis::hashSet(const char *key, const char *field, const char *value) {
    std::stringstream ss;
    ss << key << "@" << field;
    std::string strKey = ss.str();
    this->store[strKey] = std::string(value);
    return 0;
}

int Redis::set(const char *key, const char *value,
               u_int expire_secs /* = 0 */) {
    std::string strKey(key);
    this->store[strKey] = std::string(value);
    return 0;
}

/* setnx = set if not existing */
int Redis::setnx(const char *key, const char *value,
                 u_int expire_secs /* = 0 */) {
    std::string strKey(key);
    if (this->store.find(strKey) != this->store.end()) return -1;

    this->store[strKey] = std::string(value);
    return 0;
}

int Redis::keys(const char *pattern, char ***keys_p) {
    *keys_p = (char **)malloc(0);
    return 0;
}

int Redis::hashKeys(const char *pattern, char ***keys_p) {
    *keys_p = (char **)malloc(0);
    return 0;
}

int Redis::hashGetAll(const char *key, char ***keys_p, char ***values_p) {
    *keys_p = NULL;
    return 0;
}

int Redis::del(char *key) {
    std::string strKey(key);
    stats.num_del++;
    this->store.erase(strKey);
    return 0;
}

int Redis::pushHostToResolve(char *hostname, bool dont_check_for_existence,
                             bool localHost) {
    if (!ntop->getPrefs()->is_dns_resolution_enabled()) return 0;
    if (hostname == NULL) return -1;

    if (!Utils::shouldResolveHost(hostname)) return -1;

    std::stringstream ss;
    ss << DNS_CACHE << "." << hostname;
    std::string strKey = ss.str();

    /* Add only if the address has not been resolved yet */
    if (dont_check_for_existence ||
        this->store.find(strKey) == this->store.end()) {
        auto &q = localHost ? localToResolve : remoteToResolve;
        q->enqueue(hostname);

        return 0;
    }

    return -1;
}

int Redis::popHostToResolve(char *hostname, u_int hostname_len) {
    char *item = localToResolve->dequeue();
    int rv = -1;

    if (!item) item = remoteToResolve->dequeue();

    if (item) {
        strncpy(hostname, item, hostname_len);
        hostname[hostname_len - 1] = 0;
        free(item);
        rv = 0;
    }

    return rv;
}

int Redis::getAddress(char *numeric_ip, char *rsp, u_int rsp_len,
                      bool queue_if_not_found) {
    if (rsp_len == 0) return -1;

    int rc;
    char key[CONST_MAX_LEN_REDIS_KEY];
    bool already_in_bloom;

    rsp[0] = 0;
    snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, numeric_ip);

    if (!ntop->getResolutionBloom()->isSetBit(numeric_ip)) {
        already_in_bloom = false;
        rc = -1; /* No way to find it */
    } else {
        already_in_bloom = true;
        rc = this->get(key, rsp, rsp_len);
    }

    if (rc != 0) {
        if (queue_if_not_found) {
            if (already_in_bloom)
                ntop->getResolutionBloom()->unsetBit(
                    numeric_ip); /* Expired key ? */

            this->pushHostToResolve(numeric_ip, true, false);
        }
    } else {
        /* We need to extend expire */
        if (!already_in_bloom)
            ntop->getResolutionBloom()->setBit(
                numeric_ip); /* Previously cached ? */

        this->expire(key, DNS_CACHE_DURATION /* expire */);
    }

    return rc;
}

int Redis::setResolvedAddress(char *numeric_ip, char *symbolic_ip) {
    char key[CONST_MAX_LEN_REDIS_KEY], numeric[256], *w, *h;
    int rc = 0;

    snprintf(numeric, sizeof(numeric), "%s", numeric_ip);

    h = strtok_r(numeric, ";", &w);

    while (h != NULL) {
        snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, h);
        ntop->getResolutionBloom()->setBit(h);
        rc = this->set(key, symbolic_ip, DNS_CACHE_DURATION);
        h = strtok_r(NULL, ";", &w);
    }

    return rc;
}

int Redis::sadd(const char *set_name, char *item) {
    std::string strKey(set_name);
    if (!this->checkSet(strKey)) return -1;
    if (this->setStore.find(strKey) == this->setStore.end())
        this->setStore[strKey] = std::set<std::string>();

    auto result = this->setStore[strKey].insert(std::string(item));
    return (result.second ? 1 : 0);
}

int Redis::srem(const char *set_name, char *item) {
    std::string strKey(set_name);
    if (!this->checkSet(strKey)) return -1;
    if (this->setStore.find(strKey) == this->setStore.end()) return 0;

    return this->setStore[strKey].erase(std::string(item));
}

int Redis::smembers(lua_State *vm, char *setName) {
    stats.num_other++;
    std::string strKey(setName);
    if (!this->checkSet(strKey)) return -1;
    if (this->setStore.find(strKey) == this->setStore.end()) return 0;

    int k = 0;
    const auto &values = this->setStore[strKey];
    for (const auto &val : values) {
        lua_pushstring(vm, val.c_str());
        lua_rawseti(vm, -2, k + 1);
        ++k;
    }

    return 0;
}

int Redis::smembers(const char *set_name, char ***members) {
    std::string strKey(set_name);
    if (this->setStore.find(strKey) == this->setStore.end()) {
        *members = NULL;
        return -1;
    }

    int k = 0;
    const auto &values = this->setStore[strKey];
    if ((*members = (char **)malloc(values.size() * sizeof(char *))) != NULL)
        for (auto val : values) (*members)[k++] = strdup(val.c_str());

    return values.size();
}

bool Redis::sismember(const char *set_name, const char *member) {
    stats.num_other++;
    std::string strKey(set_name);
    if (this->setStore.find(strKey) == this->setStore.end()) return false;

    return (this->setStore[strKey].find(std::string(member)) ==
            this->setStore[strKey].end());
}

int Redis::lpush(const char *queue_name, const char *msg, u_int queue_trim_size,
                 bool trace_errors /* = true */) {
    stats.num_lpush_rpush++;
    std::string strKey(queue_name);
    if (!this->checkList(strKey)) return -1;

    if (this->listStore.find(strKey) == this->listStore.end())
        this->listStore[strKey] = std::vector<std::string>();

    this->listStore[strKey].insert(this->listStore[strKey].begin(),
                                   std::string(msg));

    if (queue_trim_size > 0) {
        stats.num_trim++;
        if (this->ltrim(queue_name, -queue_trim_size, -1) == -1) return -1;
    }

    return this->listStore[strKey].size();
}

int Redis::rpush(const char *queue_name, const char *msg,
                 u_int queue_trim_size) {
    stats.num_lpush_rpush++;
    std::string strKey(queue_name);
    if (!this->checkList(strKey)) return -1;

    if (this->listStore.find(strKey) == this->listStore.end())
        this->listStore[strKey] = std::vector<std::string>();

    this->listStore[strKey].push_back(std::string(msg));

    if (queue_trim_size > 0) {
        stats.num_trim++;
        if (this->ltrim(queue_name, -queue_trim_size, -1) == -1) return -1;
    }

    return this->listStore[strKey].size();
}

int Redis::lindex(const char *queue_name, int idx, char *buf, u_int buf_len) {
    if (buf_len == 0) return -1;
    stats.num_other++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) {
        buf[0] = 0;
        return -1;
    }

    const auto &list = this->listStore[strKey];

    if (idx < 0) idx += (int)list.size();
    if (idx < 0 || idx >= (int)list.size()) {
        buf[0] = 0;
        return -1;
    }

    snprintf(buf, buf_len, "%s", list[idx].c_str());

    return 0;
}

int Redis::ltrim(const char *queue_name, int start_idx, int end_idx) {
    stats.num_other++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) return -1;

    auto &list = this->listStore[strKey];
    if (start_idx < 0) start_idx += list.size();
    if (end_idx < 0) end_idx += list.size();
    int k = 0;
    for (auto it = list.begin(); it != list.end(); ++k) {
        if (k < start_idx || k > end_idx)
            list.erase(it);
        else
            ++it;
    }

    return 0;
}

u_int Redis::hstrlen(const char *key, const char *value) {
    stats.num_other++;
    std::stringstream ss;
    ss << key << "@" << value;
    std::string strKey = ss.str();
    if (this->store.find(strKey) == this->store.end()) return 0;

    return this->store[strKey].size();
}

u_int Redis::len(const char *key) {
    std::string strKey(key);
    if (this->store.find(strKey) == this->store.end()) return 0;

    return this->store[strKey].size();
}

u_int Redis::llen(const char *queue_name) {
    stats.num_llen++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) return 0;

    return this->listStore[strKey].size();
}

int Redis::lset(const char *queue_name, u_int32_t idx, const char *value) {
    return -1;
}

int Redis::lrem(const char *queue_name, const char *value) {
    stats.num_other++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) return 0;

    for (auto it = this->listStore[strKey].begin();
         it != this->listStore[strKey].end();) {
        if (strncmp(it->c_str(), value, it->size()) == 0)
            this->listStore[strKey].erase(it);
        else
            ++it;
    }
    return 0;
}

int Redis::lrange(const char *list_name, char ***elements, int start_offset,
                  int end_offset) {
    stats.num_other++;
    std::string strKey(list_name);
    if (this->listStore.find(strKey) == this->listStore.end()) return 0;

    auto &list = this->listStore[strKey];
    if (start_offset < 0) start_offset += list.size();
    if (end_offset < 0) end_offset += list.size();
    int k = 0;
    vector<std::string> retList;
    for (auto it = list.begin(); it != list.end(); ++k, ++it) {
        if (k >= start_offset && k <= end_offset) retList.push_back(*it);
    }

    *elements = (char **)malloc(retList.size() * sizeof(char *));
    for (int i = 0; i < (int)retList.size(); ++i)
        (*elements)[i] = strdup(retList[i].c_str());

    return retList.size();
}

int Redis::lpop(const char *queue_name, char *buf, u_int buf_len) {
    stats.num_lpop_rpop++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) {
        buf[0] = 0;
        return -1;
    }

    if (this->listStore[strKey].size() == 0) {
        buf[0] = 0;
        return -1;
    }

    snprintf(buf, buf_len, "%s", this->listStore[strKey].front().c_str());
    this->listStore[strKey].erase(this->listStore[strKey].begin());

    return 0;
}

int Redis::rpop(const char *queue_name, char *buf, u_int buf_len) {
    stats.num_lpop_rpop++;
    std::string strKey(queue_name);
    if (this->listStore.find(strKey) == this->listStore.end()) {
        buf[0] = 0;
        return -1;
    }

    if (this->listStore[strKey].size() == 0) {
        buf[0] = 0;
        return -1;
    }

    snprintf(buf, buf_len, "%s", this->listStore[strKey].back().c_str());
    this->listStore[strKey].pop_back();

    return 0;
}

int Redis::incr(const char *key, int amount) {
    std::string strKey(key);
    if (this->store.find(strKey) == this->store.end()) return 0;

    const auto &val = this->store[strKey];
    try {
        long l = std::stol(val);
        l += amount;
        std::stringstream ss;
        ss << l;
        this->store[strKey] = ss.str();
        return l;
    } catch (std::exception const &e) {
        return 0;
    }
}

int Redis::flushDb() {
    stats.num_other++;
    this->store.clear();
    return 0;
}

void Redis::flushCache() {}

void Redis::lua(lua_State *vm) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "num_expire", stats.num_expire);
    lua_push_uint64_table_entry(vm, "num_get", stats.num_get);
    lua_push_uint64_table_entry(vm, "num_ttl", stats.num_ttl);
    lua_push_uint64_table_entry(vm, "num_del", stats.num_del);
    lua_push_uint64_table_entry(vm, "num_hget", stats.num_hget);
    lua_push_uint64_table_entry(vm, "num_hset", stats.num_hset);
    lua_push_uint64_table_entry(vm, "num_hdel", stats.num_hdel);
    lua_push_uint64_table_entry(vm, "num_set", stats.num_set);
    lua_push_uint64_table_entry(vm, "num_expire", stats.num_expire);
    lua_push_uint64_table_entry(vm, "num_keys", stats.num_keys);
    lua_push_uint64_table_entry(vm, "num_hkeys", stats.num_hkeys);
    lua_push_uint64_table_entry(vm, "num_hgetall", stats.num_hgetall);
    lua_push_uint64_table_entry(vm, "num_trim", stats.num_trim);
    lua_push_uint64_table_entry(vm, "num_reconnections",
                                stats.num_reconnections);
    lua_push_uint64_table_entry(vm, "num_lpush_rpush", stats.num_lpush_rpush);
    lua_push_uint64_table_entry(vm, "num_lpop_rpop", stats.num_lpop_rpop);
    lua_push_uint64_table_entry(vm, "num_llen", stats.num_llen);
    lua_push_uint64_table_entry(vm, "num_strlen", stats.num_strlen);
    lua_push_uint64_table_entry(vm, "num_other", stats.num_other);

    /* Address resolution */
    lua_push_uint64_table_entry(vm, "num_resolver_saved_lookups",
                                stats.num_saved_lookups);
    lua_push_uint64_table_entry(vm, "num_resolver_get_address",
                                stats.num_get_address);
    lua_push_uint64_table_entry(vm, "num_resolver_set_address",
                                stats.num_set_resolved_address);
}

char *Redis::dump(char *key) {
    stats.num_other++;
    char *ret = (char *)malloc(1);
    ret[0] = 0;
    return ret;
}

int Redis::restore(char *key, char *buf) { return 0; }
