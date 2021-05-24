--                                                                                                                                                                                                                
-- (C) 2013-21 - ntop.org                                                                                                                                                                                         
--                                                                                                                                                                                                                
                                                                                                                                                                                                                  
local dirs = ntop.getDirs()                                                                                                                                                                                       
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path                                                                                                                                   
                                                                                                                                                                                                                  
require "lua_utils"                                                                                                                                                                                               
local json = require "dkjson"                                                                                                                                                                                     
local alert_severities = require "alert_severities"                                                                                                                                                               
local rest_utils = require "rest_utils"
local rc = rest_utils.consts.success.ok
local res = {}
res[1]=15
res[2]="TCP"
res[3]="192.168.1.5"
res[4]="82.43.64.14"
rest_utils.answer(rc, res)
