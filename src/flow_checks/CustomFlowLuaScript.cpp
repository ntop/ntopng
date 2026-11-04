/*
 *
 * (C) 2013-24 - ntop.org
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
#include "flow_checks_includes.h"

/*
  Custom flow scripts: every .lua file of CUSTOM_FLOW_SCRIPTS_DIR returns a table

    return {
      title   = "My alert",                 -- optional, default: the file name
      score   = 50,                         -- optional, default score of its alerts
      hooks   = { "detected", "periodic", "end" },  -- optional, default: all
      filter  = { ip = { "10.0.0.0/8" }, srv_port = { 502 }, l4_proto = { "TCP" }, l7_proto = { "Modbus" } },
      exclude = { ... },                    -- optional, same fields: flows to skip
      check   = function(flow) ... flow.triggerAlert("message") end,
    }

  In check: flow.* (flow.json_info(): the fields sent by the probe) and counter.* (see below).

  Filter fields (AND between fields, OR between the values of a field, a value or a list):
  cli_ip, srv_ip, ip (client or server): IP or CIDR; cli_port, srv_port, port (client or server);
  l4_proto: name (TCP, UDP, ICMP...) or number; l7_proto: nDPI name or id (app or master protocol).
  The filters are evaluated in C, the VM runs only for the matching flows.
*/

/* ********************************************** */

/* Values of a field of the table on top of the stack: a single value or a list */
static bool getList(lua_State* L, const char* field, std::vector<std::string>* out,
                    std::string* err) {
  bool ok = true;

  lua_getfield(L, -1, field);

  if (lua_isnil(L, -1)) {
    /* Not set: any value */
  } else if (lua_type(L, -1) == LUA_TSTRING || lua_type(L, -1) == LUA_TNUMBER) {
    out->push_back(lua_tostring(L, -1));
  } else if (lua_istable(L, -1)) {
    lua_Integer n = (lua_Integer)lua_rawlen(L, -1);

    for (lua_Integer i = 1; i <= n; i++) {
      lua_rawgeti(L, -1, i);
      if (lua_type(L, -1) == LUA_TSTRING || lua_type(L, -1) == LUA_TNUMBER)
        out->push_back(lua_tostring(L, -1));
      else
        *err = std::string("'") + field + "': strings or numbers expected", ok = false;
      lua_pop(L, 1);
      if (!ok) break;
    }
  } else
    *err = std::string("'") + field + "': a value or a list expected", ok = false;

  lua_pop(L, 1);
  return (ok);
}

/* ********************************************** */

/* Integer value in [min, max] */
static bool toInt(const std::string& v, long min, long max, long* res) {
  char* end;
  long n = strtol(v.c_str(), &end, 10);

  if (v.empty() || *end != '\0' || n < min || n > max) return (false);
  *res = n;
  return (true);
}

/* ********************************************** */

/* Keys of the table on top of the stack must be in allowed (catches typos) */
static bool checkKeys(lua_State* L, const char* const* allowed, const char* what,
                      std::string* err) {
  bool ok = true;

  lua_pushnil(L);
  while (lua_next(L, -2) != 0) {
    bool found = false;

    if (lua_type(L, -2) == LUA_TSTRING) {
      const char* k = lua_tostring(L, -2);

      for (int i = 0; allowed[i] != NULL; i++)
        if (strcmp(k, allowed[i]) == 0) found = true;

      if (!found) *err = std::string(what) + ": unknown key '" + k + "'";
    } else
      *err = std::string(what) + ": only named keys are allowed";

    lua_pop(L, 1); /* value */
    if (!found) {
      lua_pop(L, 1); /* key */
      ok = false;
      break;
    }
  }

  return (ok);
}

/* ********************************************** */

/*
  Helpers available to every script (global `counter`), defined before the script runs.
  counter.inc(key, window_secs [, n]): adds n (default 1) to key in the current window of
  window_secs seconds (default 60) and returns the count; a new window starts when it expires.
  counter.get(key): the count of the current window (0 when expired); counter.reset(key).
  Expired keys are removed every 1000 calls: memory follows the active keys only.
*/
static const char* CUSTOM_FLOW_SCRIPT_HELPERS = R"LUA(
counter = (function()
  local windows = {}
  local calls = 0
  local M = {}

  local function sweep(now)
    for k, w in pairs(windows) do
      if now - w.start >= w.window then windows[k] = nil end
    end
  end

  function M.inc(key, window_secs, n)
    local now = os.time()
    window_secs = tonumber(window_secs) or 60
    calls = calls + 1
    if calls % 1000 == 0 then sweep(now) end

    local w = windows[key]
    if (w == nil) or (now - w.start >= w.window) then
      w = { start = now, count = 0, window = window_secs }
      windows[key] = w
    end

    w.count = w.count + (tonumber(n) or 1)
    return w.count
  end

  function M.get(key)
    local w = windows[key]
    if w and (os.time() - w.start < w.window) then return w.count end
    return 0
  end

  function M.reset(key)
    windows[key] = nil
  end

  return M
end)()
)LUA";

/* ********************************************** */

CustomFlowScriptFilter::CustomFlowScriptFilter() {
  cli_ip = srv_ip = ip = NULL, empty = true;
}

/* ********************************************** */

CustomFlowScriptFilter::~CustomFlowScriptFilter() {
  if (cli_ip) delete cli_ip;
  if (srv_ip) delete srv_ip;
  if (ip) delete ip;
}

/* ********************************************** */

bool CustomFlowScriptFilter::parseIPs(lua_State* L, const char* field,
                                      AddressTree** tree, std::string* err) {
  std::vector<std::string> values;

  if (!getList(L, field, &values, err)) return (false);
  if (values.empty()) return (true);

  /* Read only after the load: no locking */
  if ((*tree = new (std::nothrow) AddressTree(true, NULL, false)) == NULL) {
    *err = "out of memory";
    return (false);
  }

  for (const std::string& v : values) {
    if (!(*tree)->addAddress(v.c_str())) {
      *err = std::string("'") + field + "': invalid IP or network '" + v + "'";
      return (false);
    }
  }

  return (true);
}

/* ********************************************** */

bool CustomFlowScriptFilter::parsePorts(lua_State* L, const char* field,
                                        std::set<u_int16_t>* ports,
                                        std::string* err) {
  std::vector<std::string> values;

  if (!getList(L, field, &values, err)) return (false);

  for (const std::string& v : values) {
    long n;

    if (!toInt(v, 0, 65535, &n)) {
      *err = std::string("'") + field + "': invalid port '" + v + "'";
      return (false);
    }
    ports->insert((u_int16_t)n);
  }

  return (true);
}

/* ********************************************** */

bool CustomFlowScriptFilter::parseL4(lua_State* L, std::string* err) {
  static const struct {
    const char* name;
    u_int8_t proto;
  } names[] = {{"tcp", IPPROTO_TCP},   {"udp", IPPROTO_UDP},  {"icmp", IPPROTO_ICMP},
               {"icmpv6", 58},         {"igmp", 2},           {"gre", 47},
               {"esp", 50},            {"sctp", 132},         {NULL, 0}};
  std::vector<std::string> values;

  if (!getList(L, "l4_proto", &values, err)) return (false);

  for (const std::string& v : values) {
    long n;
    bool found = false;

    if (toInt(v, 0, 255, &n))
      found = true;
    else {
      for (int i = 0; names[i].name != NULL; i++)
        if (strcasecmp(v.c_str(), names[i].name) == 0)
          n = names[i].proto, found = true;
    }

    if (!found) {
      *err = "'l4_proto': unknown protocol '" + v + "'";
      return (false);
    }
    l4_proto.insert((u_int8_t)n);
  }

  return (true);
}

/* ********************************************** */

bool CustomFlowScriptFilter::parseL7(lua_State* L, NetworkInterface* iface,
                                     std::string* err) {
  std::vector<std::string> values;

  if (!getList(L, "l7_proto", &values, err)) return (false);

  for (const std::string& v : values) {
    long n;

    if (!toInt(v, 0, 65535, &n)) {
      n = iface->getnDPIProtoByName(v.c_str());

      if (n == NDPI_PROTOCOL_UNKNOWN && strcasecmp(v.c_str(), "Unknown") != 0) {
        *err = "'l7_proto': unknown protocol '" + v + "'";
        return (false);
      }
    }
    l7_proto.insert((u_int16_t)n);
  }

  return (true);
}

/* ********************************************** */

bool CustomFlowScriptFilter::parse(lua_State* L, NetworkInterface* iface,
                                   std::string* err) {
  static const char* const keys[] = {"cli_ip",   "srv_ip",   "ip",       "cli_port", "srv_port",
                                     "port",     "l4_proto", "l7_proto", NULL};

  if (!lua_istable(L, -1)) {
    *err = "a table expected";
    return (false);
  }

  if (!checkKeys(L, keys, "filter", err) || !parseIPs(L, "cli_ip", &cli_ip, err) ||
      !parseIPs(L, "srv_ip", &srv_ip, err) || !parseIPs(L, "ip", &ip, err) ||
      !parsePorts(L, "cli_port", &cli_port, err) ||
      !parsePorts(L, "srv_port", &srv_port, err) || !parsePorts(L, "port", &port, err) ||
      !parseL4(L, err) || !parseL7(L, iface, err))
    return (false);

  empty = !(cli_ip || srv_ip || ip || !cli_port.empty() || !srv_port.empty() ||
            !port.empty() || !l4_proto.empty() || !l7_proto.empty());

  return (true);
}

/* ********************************************** */

static inline bool matchIP(AddressTree* tree, IpAddress* a) {
  return (a && tree->match(a, a->isIPv4() ? 32 : 128) != NULL);
}

/* ********************************************** */

bool CustomFlowScriptFilter::match(Flow* f) {
  IpAddress *cli = f->get_cli_ip_addr(), *srv = f->get_srv_ip_addr();
  u_int16_t cport = f->get_cli_port(), sport = f->get_srv_port();

  if (empty) return (true);

  if (!l4_proto.empty() && l4_proto.find(f->get_protocol()) == l4_proto.end())
    return (false);

  if (!l7_proto.empty() && l7_proto.find(f->getUpperProtocol()) == l7_proto.end() &&
      l7_proto.find(f->getLowerProtocol()) == l7_proto.end())
    return (false);

  if (!cli_port.empty() && cli_port.find(cport) == cli_port.end()) return (false);
  if (!srv_port.empty() && srv_port.find(sport) == srv_port.end()) return (false);
  if (!port.empty() && port.find(cport) == port.end() && port.find(sport) == port.end())
    return (false);

  if (cli_ip && !matchIP(cli_ip, cli)) return (false);
  if (srv_ip && !matchIP(srv_ip, srv)) return (false);
  if (ip && !matchIP(ip, cli) && !matchIP(ip, srv)) return (false);

  return (true);
}

/* ********************************************** */

CustomFlowScript::CustomFlowScript() {
  lua = NULL, check_ref = LUA_NOREF, error_reported = false;
  score = CUSTOM_FLOW_SCRIPT_DEFAULT_SCORE, hooks = CUSTOM_FLOW_SCRIPT_HOOK_ALL;
}

/* ********************************************** */

CustomFlowScript::~CustomFlowScript() {
  if (lua) delete lua;
}

/* ********************************************** */

/* The table returned by the script is on top of the stack */
bool CustomFlowScript::parseDefinition(NetworkInterface* iface) {
  static const char* const keys[] = {"title", "score", "hooks", "filter", "exclude", "check", NULL};
  lua_State* L = lua->getState();
  std::string err;
  std::vector<std::string> hook_names;

  if (!lua_istable(L, -1)) {
    err = "the script must return a table";
    goto error;
  }

  if (!checkKeys(L, keys, "script", &err)) goto error;

  lua_getfield(L, -1, "check");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    err = "'check' must be a function";
    goto error;
  }
  check_ref = luaL_ref(L, LUA_REGISTRYINDEX); /* Pops the function */

  lua_getfield(L, -1, "title");
  if (lua_type(L, -1) == LUA_TSTRING)
    title = lua_tostring(L, -1);
  else if (!lua_isnil(L, -1))
    err = "'title' must be a string";
  lua_pop(L, 1);
  if (!err.empty()) goto error;

  lua_getfield(L, -1, "score");
  if (lua_isinteger(L, -1) && lua_tointeger(L, -1) >= 1 && lua_tointeger(L, -1) <= 255)
    score = (u_int8_t)lua_tointeger(L, -1);
  else if (!lua_isnil(L, -1))
    err = "'score' must be an integer between 1 and 255";
  lua_pop(L, 1);
  if (!err.empty()) goto error;

  if (!getList(L, "hooks", &hook_names, &err)) goto error;
  if (!hook_names.empty()) {
    hooks = 0;
    for (const std::string& h : hook_names) {
      if (h == "detected") hooks |= CUSTOM_FLOW_SCRIPT_HOOK_DETECTED;
      else if (h == "periodic") hooks |= CUSTOM_FLOW_SCRIPT_HOOK_PERIODIC;
      else if (h == "end") hooks |= CUSTOM_FLOW_SCRIPT_HOOK_END;
      else {
        err = "'hooks': unknown hook '" + h + "' (detected, periodic, end)";
        goto error;
      }
    }
  }

  lua_getfield(L, -1, "filter");
  if (!lua_isnil(L, -1) && !filter.parse(L, iface, &err)) err = "'filter': " + err;
  lua_pop(L, 1);
  if (!err.empty()) goto error;

  lua_getfield(L, -1, "exclude");
  if (!lua_isnil(L, -1) && !exclude.parse(L, iface, &err)) err = "'exclude': " + err;
  lua_pop(L, 1);
  if (!err.empty()) goto error;

  return (true);

error:
  ntop->getTrace()->traceEvent(TRACE_ERROR, "Custom flow script %s disabled: %s",
                               name.c_str(), err.c_str());
  return (false);
}

/* ********************************************** */

bool CustomFlowScript::load(const char* path, NetworkInterface* iface) {
  const char* slash = strrchr(path, '/');
  lua_State* L;
  bool ok;

  name = slash ? slash + 1 : path;
  title = name.substr(0, name.size() > 4 ? name.size() - 4 : name.size()); /* Without .lua */

  try {
    lua = new LuaEngine();
  } catch (std::bad_alloc& ba) {
    lua = NULL;
  }

  if (lua == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start Lua interpreter.");
    return (false);
  }

  /* NetworkInterface filled later via lua->setFlow(f) */
  if (lua->load_script((char*)path, lua_engine_mode_callback, NULL) != 0) return (false);

  L = lua->getState();

  /* Helpers first (the chunk stays on top of the stack) */
  if (luaL_dostring(L, CUSTOM_FLOW_SCRIPT_HELPERS) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Custom flow script %s: helpers: %s", name.c_str(),
                                 lua_isstring(L, -1) ? lua_tostring(L, -1) : "");
    return (false);
  }

  /* Run the chunk once: it returns the definition */
  if (lua_pcall(L, 0, 1, 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Custom flow script %s disabled: %s",
                                 name.c_str(), lua_isstring(L, -1) ? lua_tostring(L, -1) : "");
    lua_settop(L, 0);
    return (false);
  }

  ok = parseDefinition(iface);
  lua_settop(L, 0);

  return (ok);
}

/* ********************************************** */

bool CustomFlowScript::run(Flow* f) {
  lua_State* L = lua->getState();
  bool triggered;

  /* Filters first: the VM runs only for the flows of the script */
  if (!filter.match(f) || (!exclude.isEmpty() && exclude.match(f))) return (false);

  m.lock(__FILE__, __LINE__);

  lua->setFlow(f);
  f->resetCustomFlowAlert();

  lua_rawgeti(L, LUA_REGISTRYINDEX, check_ref);
  lua_getglobal(L, "flow"); /* check(flow) */

  if (lua_pcall(L, 1, 0, 0) != 0) {
    /* Once per script: the same error would repeat on every flow */
    if (!error_reported) {
      const char* msg = lua_tostring(L, -1);

      ntop->getTrace()->traceEvent(TRACE_ERROR, "Custom flow script %s: %s", name.c_str(),
                                   msg ? msg : "");
      if (msg) ntop->getRedis()->lpush(ALERT_TRACE_ERRORS, msg, 50 /* No Trim */);
      error_reported = true;
    }
    lua_pop(L, 1);
  }

  triggered = f->isCustomFlowAlertTriggered();

  m.unlock(__FILE__, __LINE__);

  return (triggered);
}

/* ********************************************** */

CustomFlowScripts::CustomFlowScripts(NetworkInterface* iface) {
  std::vector<std::string> paths;
  DIR* dir;

  /* User scripts, in name order */
  if ((dir = opendir(CUSTOM_FLOW_SCRIPTS_DIR)) != NULL) {
    struct dirent* ent;

    while ((ent = readdir(dir)) != NULL) {
      size_t len = strlen(ent->d_name);

      if (len > 4 && ent->d_name[0] != '.' && strcmp(&ent->d_name[len - 4], ".lua") == 0)
        paths.push_back(std::string(CUSTOM_FLOW_SCRIPTS_DIR) + "/" + ent->d_name);
    }

    closedir(dir);
    std::sort(paths.begin(), paths.end());
  } else
    /* The check is enabled but there is nothing to run: say where the scripts are expected */
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "No custom flow scripts loaded on %s: unable to open %s (%s)",
                                 iface->get_name(), CUSTOM_FLOW_SCRIPTS_DIR, strerror(errno));

  for (const std::string& p : paths) {
    CustomFlowScript* s = new (std::nothrow) CustomFlowScript();

    if (s && s->load(p.c_str(), iface)) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loaded custom flow script %s [title: %s] on %s",
                                   s->getName().c_str(), s->getTitle().c_str(), iface->get_name());
      scripts.push_back(s);
    } else if (s)
      delete s;
  }

  if (!scripts.empty())
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loaded %u custom flow script(s) on %s",
                                 (unsigned)scripts.size(), iface->get_name());
}

/* ********************************************** */

CustomFlowScripts::~CustomFlowScripts() {
  for (CustomFlowScript* s : scripts) delete s;
}

/* ********************************************** */

CustomFlowLuaScript::CustomFlowLuaScript()
    : FlowCheck(ntopng_edition_community, false /* All interfaces */,
                false /* Don't exclude for nEdge */,
                false /* NOT only for nEdge */,
                true /* has_protocol_detected */,
                true /* has_periodic_update */, true /* has_flow_end */) {}

/* ********************************************** */

CustomFlowLuaScript::~CustomFlowLuaScript() {
  for (int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
    NetworkInterface* iface;

    if ((iface = ntop->getInterface(i)) != NULL) {
      CustomFlowScripts* s = iface->getCustomFlowScripts();

      if (s != NULL) {
        iface->setCustomFlowScripts(NULL /* remove VMs */);
        delete s;
      }
    }
  }
}

/* ********************************************** */

void CustomFlowLuaScript::runScripts(Flow* f, u_int8_t hook) {
  NetworkInterface* iface;
  CustomFlowScripts* scripts;

  if (f == NULL) return;

  iface = f->getInterface();

  /* Loaded once per interface (also when there is no script: no rescan per flow) */
  if ((scripts = iface->getCustomFlowScripts()) == NULL) {
    if ((scripts = new (std::nothrow) CustomFlowScripts(iface)) == NULL) return;
    iface->setCustomFlowScripts(scripts);
  }

  for (CustomFlowScript* s : scripts->get()) {
    CustomFlowLuaScriptAlert* alert;
    const char* msg;
    u_int8_t score;

    if (!s->hasHook(hook) || !s->run(f)) continue;

    /* flow.triggerAlert(msg) without score: the score of the script */
    score = f->getCustomFlowAlertScore() ? f->getCustomFlowAlertScore() : s->getScore();
    msg = f->getCustomFlowAlertMessage() ? f->getCustomFlowAlertMessage() : "";

    /* One alert per type and flow (Flow::setAlertsMap): the next scripts join the existing one */
    alert = static_cast<CustomFlowLuaScriptAlert*>(f->getTriggeredAlert(flow_alert_custom_lua_script));

    if (alert) {
      if (!alert->addScript(s->getName(), s->getTitle(), msg)) continue; /* Already in it */

      if (score > alert->getAlertScore()) alert->setAlertScore(score);
      f->refreshAlert(flow_alert_custom_lua_script); /* Rebuild its JSON */

      /* Already stored by a previous hook: store it again, with the new script too */
      if (!f->hasPendingAlerts()) f->setPendingAlerts();
    } else if ((alert = new (std::nothrow) CustomFlowLuaScriptAlert(this, f)) != NULL) {
      u_int8_t c_score, s_score;

      alert->addScript(s->getName(), s->getTitle(), msg);
      alert->setAlertScore(score);
      computeCliSrvScore(alert->getAlertScore(), CLIENT_FAIR_RISK_PERCENTAGE, &c_score,
                         &s_score);
      alert->setCliSrvScores(c_score, s_score);
      f->triggerAlert(alert);
    }
  }
}

/* ********************************************** */

void CustomFlowLuaScript::protocolDetected(Flow* f) {
  runScripts(f, CUSTOM_FLOW_SCRIPT_HOOK_DETECTED);
}

void CustomFlowLuaScript::periodicUpdate(Flow* f) {
  runScripts(f, CUSTOM_FLOW_SCRIPT_HOOK_PERIODIC);
}

void CustomFlowLuaScript::flowEnd(Flow* f) {
  runScripts(f, CUSTOM_FLOW_SCRIPT_HOOK_END);
}

/* ********************************************** */

bool CustomFlowLuaScript::loadConfiguration(json_object* config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /* Parse additional parameters */

  return (true);
}

/* ***************************************************** */
