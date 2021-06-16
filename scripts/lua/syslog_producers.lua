--
-- (C) 2019-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
require "lua_utils"
local checks = require "checks"
local template = require "template_utils"

if not isAdministrator() then
  return
end

local ifid = interface.getId()
if tonumber(_GET["ifid"]) ~= nil then
  ifid = _GET["ifid"]
elseif not ifid then
  error("Missing interface index")
end

local producer_types = {};
local syslog_plugins = checks.listScripts(checks.script_types.syslog, "syslog")
for k,v in pairs(syslog_plugins) do
  table.insert(producer_types, { title = i18n(v.."_collector.title"), value = v  })
end

-- #######################################################

-- Title
print([[
<hr>
<h2>]] .. i18n("syslog.producers") .. [[</h2>
]])

-- Table
print([[
    <div class='container-fluid my-3'>
      <div class='row'>
        <div class="col-md-12">
          <div id="syslog-producers-alert" class="alert alert-success" style="display: none" role="alert">
            <strong>Success!</strong> <span class="alert-body"></span>
            <button type="button" class="close" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
        </div>
      </div>
      <div class='row'>
        <div class='col-md-12 col-12'>
          <table class="table w-100 table-striped table-hover table-bordered" id="syslog-producers-table">
            <thead>
              <tr>
                <th>]].. i18n("syslog.producer_type") ..[[</th>
                <th>]].. i18n("syslog.producer_host") .. [[</th>
                <th>]].. i18n("actions") .. [[</th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
        </div>
      </div>
    </div>
]])

-- Edit Modal
print([[
    <div id='syslog-producers-edit-modal' class="modal fade" tabindex="-1" role="dialog">
      <form method="post" id='syslog-producers-edit-form'>
        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("syslog.edit") .. [[</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body container-fluid">
              <div class="form-group mb-3 row">
                <label class="col-sm-3 col-form-label">]] .. i18n("syslog.producer_type") .. [[</label>
                <div class="col-sm-5">
                  ]].. generate_select("select-edit-producer", "syslog_producer_type", true, false, producer_types) ..[[
                </div>
              </div>
              <div class="form-group mb-3 row">
                <label class="col-sm-3 col-form-label">]] .. i18n("syslog.producer_host") .. [[</label>
                <div class="col-sm-5">
                  <input placeholder="]] .. i18n("syslog.ip_or_device") .. [[" required id="input-edit-host" type="text" name="host" class="form-control" />
                </div>
              </div>
              <small>]] .. i18n("syslog.ip_or_device_note") .. [[</small>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button id="btn-reset-defaults" type="button" class="btn btn-danger me-auto">]] .. i18n("reset") .. [[</button>
              <button type="submit" class="btn btn-primary">]] .. i18n("apply") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>
]])

-- Add Modal
print([[
    <div id='syslog-producers-add-modal' class="modal fade" tabindex="-1" role="dialog">
      <form method="post" id='syslog-producers-add-form'>
        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("syslog.add") .. [[</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body container-fluid">
              <div class="form-group mb-3 row">
                <label class="col-sm-3 col-form-label">]] .. i18n("syslog.producer_type") .. [[</label>
                <div class="col-sm-5">
                  ]] .. generate_select("select-add-producer", "producer", true, false, producer_types) ..[[
                </div>
              </div>
              <div class="form-group mb-3 row">
                <label class="col-sm-3 col-form-label">]] .. i18n("syslog.producer_host") .. [[</label>
                <div class="col-sm-5">
                  <input placeholder="]] .. i18n("syslog.ip_or_device") .. [[" required id="input-add-host" type="text" name="host" class="form-control" />
                </div>
              </div>
              <small>]] .. i18n("syslog.ip_or_device_note") .. [[</small>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button type="submit" class="btn btn-primary">]] .. i18n("add") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>
]])

-- Delete Modal
print([[
    <div id='syslog-producers-delete-modal' class="modal fade" tabindex="-1" role="dialog">
      <form id='syslog-producers-delete-form'>
        <div class="modal-dialog modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("delete") .. [[: <span id="delete-host"></span></h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <p>
		              ]] .. i18n("syslog.confirm_delete") .. [[
              </p>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button id="btn-delete-producer" type="submit" class="btn btn-danger">]] .. i18n("delete") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>
]])

-- Notes
--print([[
--    <div>
--      ]].. i18n("notes") .. [[<ul>
--	<li></li>
--      </ul>
--    </div>
--]])

-- Table Data
print([[
    <link href="]].. ntop.getHttpPrefix() ..[[/css/dataTables.bootstrap5.min.css" rel="stylesheet"/>
    <script type="text/javascript">

      i18n.showing_x_to_y_rows = "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[";
      i18n.search = "]].. i18n("search") ..[[:";
      i18n.edit = "]] .. i18n("users.edit") .. [[";
      i18n.delete = "]] .. i18n("delete") .. [[";
      i18n.expired_csrf = "]] .. i18n("expired_csrf") .. [[";

      let get_host = "]].. (_GET["host"] ~= nil and _GET["host"] or "") ..[[";
      let syslog_producers_csrf = "]].. ntop.getRandomCSRFValue() ..[[";

    </script>
    <script type='text/javascript' src=']].. ntop.getHttpPrefix() ..[[/js/syslog/syslog-producers-utils.js?]] ..(ntop.getStartupEpoch()) ..[['></script>
]])

