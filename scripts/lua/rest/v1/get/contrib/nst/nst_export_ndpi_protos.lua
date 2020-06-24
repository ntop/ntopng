--
-- ###################################################################################
-- nst_export_ndpi_protos.lua (v1.01)
--
-- NST - 2017, 2020:
--      Dump all known Ntopng nDPI protocols in JSON format including any custom
--      defined protocols in an nDPI protocol file.
--
-- Usage Example:
--   curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_ndpi_protos.lua";
--
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

--
-- Grap known protos from Ntopng...
protos = interface.getnDPIProtocols()

--
-- Start JSON Output...
print ("{")

num = 0
--
-- Add a JSON member for each protocol...
for proto_name, proto_id in pairs(protos) do
  if (num > 0) then
    print ","
  end
  print('"' .. proto_name .. '":' .. proto_id)
  --
  num = num + 1
end

--
-- End JSON Output...
print ("}")
