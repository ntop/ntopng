--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Read information about RX-only hosts (i.e. hosts that have received traffic but not tranmitted anything)
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0"}' http://localhost:3000/lua/rest/v2/get/host/no_tx_peers
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- =============================

local ifid = _GET["ifid"]
interface.select(ifid)

local rsp = {}

rsp.rx_only = {}

rsp.rx_only.local_hosts = {}
rsp.rx_only.local_hosts.hosts_with_ports_count  = interface.getRxOnlyHostsList(true, false)
rsp.rx_only.local_hosts.host_peers              = interface.getRxOnlyHostsList(true, true)

rsp.rx_only.remote_hosts = {}
rsp.rx_only.remote_hosts.hosts_with_ports_count = interface.getRxOnlyHostsList(false, false)
rsp.rx_only.remote_hosts.host_peers             = interface.getRxOnlyHostsList(false, true)

rest_utils.answer(rest_utils.consts.success.ok, rsp) 
