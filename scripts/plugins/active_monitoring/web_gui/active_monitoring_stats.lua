--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local alert_consts = require("alert_consts")
local plugins_utils = require("plugins_utils")
local template = require("template_utils")
local json = require("dkjson")
local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

local graph_utils = require("graph_utils")
local alert_utils = require("alert_utils")

local ts_creation = plugins_utils.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.active_monitor)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local host = _GET["am_host"]
local measurement = _GET["measurement"]
local base_url = plugins_utils.getUrl("active_monitoring_stats.lua") .. "?ifid=" .. getInterfaceId(ifname)
local url = base_url
local info = ntop.getInfo()
local measurement_info

if(not isEmptyString(host) and not isEmptyString(measurement)) then
  host = active_monitoring_utils.getHost(host, measurement)
  measurement_info = active_monitoring_utils.getMeasurementInfo(host.measurement)
else
  host = nil
end

if host then
  url = url .. "&am_host=" .. host.host .. "&measurement=" .. host.measurement
end

local title = i18n("graphs.active_monitoring")

if((host ~= nil) and (page ~= "overview")) then
   title = title..": " .. host.label
end

if isAdministrator() then
  if(_POST["action"] == "reset_config") then
    active_monitoring_utils.resetConfig()
  end
end

page_utils.print_navbar(title, url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-lg fa-home\"></i>",
			      url = base_url,
			   },
			   {
			      hidden = not host or not ts_creation,
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = not isAdministrator() or not plugins_utils.hasAlerts(getSystemInterfaceId(), {entity = alert_consts.alertEntity("pinged_host")}),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
  print(template.gen("modal_confirm_dialog.html", {
      dialog={
	  id      = "reset-modal",
	  action  = "$('#reset-form').submit()",
	  title   = i18n("config_scripts.config_reset"),
	  message = i18n("active_monitoring_stats.config_reset_confirm"),
	  confirm = i18n("reset")
       }
  }))

  print(
    template.gen("config_list_components/import_modal.html", {
      dialog={
	id      = "import-modal",
	title   = i18n("host_pools.config_import"),
	label   = "",
	message = i18n("host_pools.config_import_message"),
	cancel  = i18n("cancel"),
	apply   = i18n("apply"),
      }
    })
  )

  print([[
    <div class='container-fluid my-3'>
      <div class='row'>
        <div class="col-md-12">
          <div id="rtt-alert" class="alert alert-success" style="display: none" role="alert">
            <strong>]] .. i18n("success") .. [[</strong> <span class="alert-body"></span>
            <button type="button" class="close" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
        </div>
      </div>
      <div class='row'>
        <div class='col-md-12 col-12'>
          <table class="table w-100 table-striped table-hover table-bordered" id="rtt-table">
            <thead>
              <tr>
                <th>]].. i18n("flow_details.url") ..[[</th>
                <th>]].. i18n("chart") ..[[</th>
                <th>]].. i18n("threshold") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.last_measurement") .. [[</th>
                <th>]].. i18n("system_stats.last_ip") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.measurement") .. [[</th>
                <th>]].. i18n("actions") .. [[</th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div id='rtt-edit-modal' class="modal fade" tabindex="-1" role="dialog">
      <form method="post" id='rtt-edit-form'>
        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("active_monitoring_stats.edit_record") .. [[</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body container-fluid">
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("active_monitoring_stats.measurement") .. [[</label>
                <div class="col-sm-5">
                  ]].. generate_select("select-edit-measurement", "measurement", true, false, active_monitoring_utils.getAvailableMeasurements(), "measurement-select") ..[[
                </div>
              </div>
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("about.host_callbacks_directory") .. [[</label>
                <div class="col-sm-5">
                  <input placeholder="yourhostname.org" required id="input-edit-host" type="text" name="host" class="form-control measurement-host" />
                </div>
              </div>
	      <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("internals.periodicity") .. [[</label>
                <div class="col-sm-5">
                  ]].. generate_select("select-edit-granularity", "granularity", true, false, {}, "measurement-granularity") ..[[
                </div>
              </div>
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("threshold") .. [[</label>
                <div class="col-sm-5">
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text measurement-operator"></span>
                    </div>
                    <input placeholder="100" required id="input-edit-threshold" name="threshold" type="number" class="form-control rounded-right" min="10" max="10000">
                    <span class="my-auto ml-1 measurement-unit"></span>
                  </div>
                </div>
              </div>
              <div id='script-description' class='alert alert-light' role='alert'>
              ]] .. i18n("notes") ..[[
              <ul>
                <li>]] .. i18n("active_monitoring_stats.rtt_note_icmp") ..[[</li>
                <li>]] .. i18n("active_monitoring_stats.rtt_note_http") ..[[</li>
                <li>]] .. i18n("active_monitoring_stats.note_alert") ..[[</li>
		<li>]] .. i18n("active_monitoring_stats.note_periodicity_change") ..[[</li>
              </ul>
              </div>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button id="btn-reset-defaults" type="button" class="btn btn-danger mr-auto">]] .. i18n("reset") .. [[</button>
              <button type="button" class="btn btn-secondary" data-dismiss="modal">]] .. i18n("cancel") .. [[</button>
              <button type="submit" class="btn btn-primary">]] .. i18n("apply") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>

    <div id='rtt-add-modal' class="modal fade" tabindex="-1" role="dialog">
      <form method="post" id='rtt-add-form'>
        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("active_monitoring_stats.add_record") .. [[</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body container-fluid">
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("active_monitoring_stats.measurement") .. [[</label>
                <div class="col-sm-5">
                  ]] .. generate_select("select-add-measurement", "measurement", true, false, active_monitoring_utils.getAvailableMeasurements(), "measurement-select") ..[[
                </div>
              </div>
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("about.host_callbacks_directory") .. [[</label>
                <div class="col-sm-5">
                  <input placeholder="yourhostname.org" required id="input-add-host" type="text" name="host" class="form-control measurement-host" />
                </div>
              </div>
	      <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("internals.periodicity") .. [[</label>
                <div class="col-sm-5">
                  ]].. generate_select("select-add-granularity", "granularity", true, false, {}, "measurement-granularity") ..[[
                </div>
              </div>
              <div class="form-group row">
                <label class="col-sm-3 col-form-label">]] .. i18n("threshold") .. [[</label>
                <div class="col-sm-5">
                  <div class="input-group">
                    <div class="input-group-prepend">
                      <span class="input-group-text measurement-operator"></span>
                    </div>
                    <input placeholder="100" required id="input-add-threshold" value="100" name="threshold" type="number" class="form-control rounded-right" min="1" max="10000">
                    <span class="my-auto ml-1 measurement-unit"></span>
                  </div>
                </div>
              </div>
              <div id='script-description' class='alert alert-light' role='alert'>
              ]] .. i18n("notes") ..[[
              <ul>
                <li>]] .. i18n("active_monitoring_stats.rtt_note_icmp") ..[[</li>
                <li>]] .. i18n("active_monitoring_stats.rtt_note_http") ..[[</li>
                <li>]] .. i18n("active_monitoring_stats.note_alert") ..[[</li>
              </ul>
              </div>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">]] .. i18n("cancel") .. [[</button>
              <button type="submit" class="btn btn-primary">]] .. i18n("add") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>

    <div id='rtt-delete-modal' class="modal fade" tabindex="-1" role="dialog">
      <form id='rtt-delete-form'>
        <div class="modal-dialog modal-dialog-centered" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">]] .. i18n("delete") .. [[: <span id="delete-host"></span></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <p>
		              ]] .. i18n("active_monitoring_stats.confirm_delete") .. [[
              </p>
              <span class="invalid-feedback"></span>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">]] .. i18n("cancel") .. [[</button>
              <button id="btn-delete-rtt" type="submit" class="btn btn-danger">]] .. i18n("delete") .. [[</button>
            </div>
          </div>
        </div>
      </form>
    </div>

    <div style="margin-bottom: 1rem">
        <form action="]] .. ntop.getHttpPrefix() .. [[/plugins/get_active_monitoring_config.lua" class="form-inline" method="GET">
            <button type="submit" class="btn btn-secondary"><span>]] .. i18n('config_scripts.config_export') .. [[</span></button>
        </form><button id="import-modal-btn" data-toggle="modal" data-target="#import-modal" class="btn btn-secondary"><span>]] .. i18n('config_scripts.config_import') .. [[</span></button>
	<form class="form-inline" method="POST" id="reset-form">
	  <input type="hidden" name="csrf" value="]].. ntop.getRandomCSRFValue() ..[["/>
	  <input type="hidden" name="action" value="reset_config"/>
	  <button type="button" id="reset-modal-btn" data-toggle="modal" data-target="#reset-modal" class="btn btn-secondary"><span>]] .. i18n('config_scripts.config_reset') .. [[</span></button>
	</form>
    </div>

    <div>
      ]].. i18n("notes") .. [[<ul>
	<li>]].. i18n("active_monitoring_stats.note1", {product=info.product}) ..[[</li>
	<li>]].. i18n("active_monitoring_stats.note2") ..[[</li>
	<li>]].. i18n("active_monitoring_stats.note_alert") ..[[</li>
      </ul>
    </div>
  ]])

  local measurements_info = {}

  -- This information is required in rtt-utils.js in order to properly
  -- render the template
  for key, info in pairs(active_monitoring_utils.getMeasurementsInfo()) do
    measurements_info[key] = {
      granularities = active_monitoring_utils.getAvailableGranularities(key),
      operator = info.operator,
      unit = i18n(info.i18n_unit) or info.i18n_unit,
      force_host = info.force_host,
    }
  end

  print([[
    <link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet"/>
    <script type="text/javascript">

      i18n.showing_x_to_y_rows = "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[";
      i18n.search = "]].. i18n("search") ..[[:";
      i18n.msec = "]] .. i18n("active_monitoring_stats.msec") .. [[";
      i18n.edit = "]] .. i18n("users.edit") .. [[";
      i18n.delete = "]] .. i18n("delete") .. [[";
      i18n.expired_csrf = "]] .. i18n("expired_csrf") .. [[";

      let get_host = "]].. (_GET["host"] ~= nil and _GET["host"] or "") ..[[";
      let rtt_csrf = "]].. ntop.getRandomCSRFValue() ..[[";
      let import_csrf = "]].. ntop.getRandomCSRFValue() ..[[";
      let measurements_info = ]] .. json.encode(measurements_info) .. [[;

    </script>
    <script type='text/javascript' src=']].. plugins_utils.getHttpdocsDir("active_monitoring") ..[[/active_monitoring_utils.js?]] ..(ntop.getStartupEpoch()) ..[['></script>
  ]])


elseif((page == "historical") and (host ~= nil) and (measurement_info ~= nil)) then

  local suffix = "_" .. host.granularity
  local schema = _GET["ts_schema"] or ("am_host:rtt" .. suffix)
  local selected_epoch = _GET["epoch"] or ""
  local tags = {ifid=getSystemInterfaceId(), host=host.host, measure=host.measurement --[[ note: measurement is a reserved InfluxDB keyword ]]}
  local rtt_ts_label
  local rtt_metric_label
  local notes = {}

  if measurement_info.i18n_rtt_ts_label then
    rtt_ts_label = i18n(measurement_info.i18n_rtt_ts_label) or measurement_info.i18n_rtt_ts_label
  else
    rtt_ts_label = i18n("graphs.num_ms_rtt")
  end

  if measurement_info.i18n_rtt_ts_metric then
    rtt_metric_label = i18n(measurement_info.i18n_rtt_ts_metric) or measurement_info.i18n_rtt_ts_metric
  else
    rtt_metric_label = i18n("flow_details.round_trip_time")
  end

  url = url.."&page=historical"

  local timeseries = {
    { schema="am_host:rtt" .. suffix, label=rtt_ts_label,
      value_formatter=(measurement_info.value_js_formatter or "fmillis"),
      metrics_labels={rtt_metric_label},
    },
  }

  for _, note in ipairs(measurement_info.i18n_chart_notes or {}) do
    notes[#notes + 1] = i18n(note) or note
  end

  for _, ts_info in ipairs(measurement_info.additional_timeseries or {}) do
    -- Add the per-granularity suffix (e.g. _min)
    ts_info.schema = ts_info.schema .. suffix

    timeseries[#timeseries + 1] = ts_info
  end

  graph_utils.drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
    timeseries = timeseries,
    notes = notes,
  })

elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   local ts_utils = require("ts_utils")
   local influxdb = ts_utils.getQueryDriver()

   -- NOTE: system interface must be manually sected and then unselected
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity"] = alert_consts.alertEntity("pinged_host")

   if host then
      _GET["entity_val"] = active_monitoring_utils.getRttHostKey(host.host, host.measurement)
   end

   alert_utils.drawAlerts()

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
