--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"
local auth_sessions_utils = require "auth_sessions_utils"
local os_utils = require "os_utils"

-- ##############################################

local function harvestUnusedDir(path, min_epoch)
    local files = ntop.readdir(path)

    -- print("Reading "..path.."<br>\n")

    for k, v in pairs(files) do
        if (v ~= nil) then
            local p = os_utils.fixPath(path .. "/" .. v)
            if (ntop.isdir(p)) then
                harvestUnusedDir(p, min_epoch)
            else
                local when = ntop.fileLastChange(path)

                if ((when ~= -1) and (when < min_epoch)) then
                    os.remove(p)
                end
            end
        end
    end
end

-- ##############################################

local when = os.time() - 86400 * 30 -- 30 days

local ifnames = interface.getIfNames()
for _, ifname in pairs(ifnames) do
    interface.select(ifname)
    local _ifstats = interface.getStats()
    local dirs = ntop.getDirs()
    local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. _ifstats.id)

    harvestUnusedDir(os_utils.fixPath(basedir .. "/top_talkers"), when)
    harvestUnusedDir(os_utils.fixPath(basedir .. "/flows"), when)
end

-- Delete user session
auth_sessions_utils.midnightCheck()

-- Reset host/mac statistics
if scripts_triggers.midnightStatsResetEnabled() then
    ntop.resetStats()
end
