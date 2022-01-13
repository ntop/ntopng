.. _ClickHouse:

Historical Flow Analysis Endpoint Example
-----------------------------------------
.. code:: bash

    --
    -- (C) 2013-21 - ntop.org
    --

    local dirs = ntop.getDirs()

    package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/flow_db/?.lua;" .. package.path
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/analysis_db/?.lua;" .. package.path

    local auth = require "auth"
    local rest_utils = require "rest_utils"
    local db_search_manager = require "db_search_manager"
    local historical_chart_formatter = require "historical_chart_formatter"

    local ifid = _GET["ifid"]
    local chart_id = _GET["chart_id"]

    local rc = rest_utils.consts.success.ok
    --
    -- Read flows data (timeseries)
    -- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/pro/rest/v2/get/db/ts.lua
    --
    -- NOTE: in case of invalid login, no error is returned but redirected to login
    --

    if isEmptyString(ifid) then
        rc = rest_utils.consts.err.invalid_interface
        rest_utils.answer(rc)
        return
    end

    interface.select(ifid)

    local res, preset = db_search_manager.get_charts_query(chart_id)
    res = historical_chart_formatter.format_default_preset_chart(res, preset)

    rest_utils.answer(rc, res)
