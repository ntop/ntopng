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
local active_monitoring_pools = require("active_monitoring_pools")
local am_pool = active_monitoring_pools:create()

local graph_utils = require("graph_utils")
local alert_utils = require("alert_utils")
local user_scripts = require("user_scripts")

local ts_creation = plugins_utils.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_system_view(true)
page_utils.set_active_menu_entry(page_utils.menu_entries.active_monitor)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local host = _GET["am_host"]
local measurement = _GET["measurement"]
local base_url = plugins_utils.getUrl("active_monitoring_stats.lua") .. "?ifid=" .. getInterfaceId(ifname)
local url = base_url
local info = ntop.getInfo()
local measurement_info

if(not user_scripts.isSystemScriptEnabled("active_monitoring")) then
  -- The active monitoring is disabled
  print[[<div class="alert alert-warning" role="alert">]]
  print(i18n("host_config.active_monitor_enable", {
    url=ntop.getHttpPrefix() .. '/lua/admin/edit_configset.lua?confset_id=0&subdir=system&user_script=active_monitoring#all'
  }))
  print[[</div>]]

  dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

  return
end

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
			      hidden = not isAdministrator() or not plugins_utils.hasAlerts(getSystemInterfaceId(), {entity = alert_consts.alertEntity("am_host")}),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then

  -- Create a filter list to use inside the overview page
  -- to filter the datatable
  local pool_filters = {}
  for key, value in pairs(am_pool:get_all_pools()) do

    pool_filters[#pool_filters + 1] = {
      key = "pool-" .. key,
      label = value.name,
      regex = key
    }

  end


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
    template.gen("pages/modals/scripts_config/import_modal.html", {
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
          <div id="am-alert" class="alert alert-success" style="display: none" role="alert">
            <strong>]] .. i18n("success") .. [[</strong> <span class="alert-body"></span>
            <button type="button" class="close" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
        </div>
      </div>
      <div class='row'>
        <div class='col-md-12 col-12'>
        <div class='card'>
          <div class='card-body'>
          <div class="table-responsive">

          <table class="table w-100 table-striped table-hover table-bordered" id="am-table">
            <thead>
              <tr>
                <th>]].. i18n("flow_details.url") ..[[</th>
                <th>]].. i18n("chart") ..[[</th>
                <th>]].. i18n("threshold") .. [[</th>
                <th>]].. i18n("active_monitoring.24h") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.last_measurement") .. [[</th>
                <th>]].. i18n("system_stats.last_ip") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.measurement") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.alerted") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.pool") .. [[</th>
                <th>]].. i18n("active_monitoring_stats.jitter") .. [[</th>
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

    page_utils.print_notes({
      i18n("active_monitoring_stats.note3", {product=info.product}),
      i18n("active_monitoring_stats.note_alert"),
      i18n("active_monitoring_stats.note_availability")
    })

    print([[
    </div>
      </div>
    </div>]])

    print(plugins_utils.renderTemplate("active_monitoring", "am_edit_host_modal.html", {
      pools = am_pool,
      dialog = {
        measurement = i18n("active_monitoring_stats.measurement"),
        edit_measurement_select = generate_select("select-edit-measurement", "measurement", true, false, {}, "measurement-select"),
        am_host = i18n("about.host_callbacks_directory"),
        periodicity = i18n("internals.periodicity"),
        edit_granularity_select = generate_select("select-edit-granularity", "granularity", true, false, {}, "measurement-granularity"),
        edit_record = i18n("active_monitoring_stats.edit_record"),
        notes = i18n("notes"),
        note_icmp = i18n("active_monitoring_stats.am_note_icmp"),
        note_http = i18n("active_monitoring_stats.am_note_http"),
        note_alert = i18n("active_monitoring_stats.note_alert"),
        note_periodicity_change = i18n("active_monitoring_stats.note_periodicity_change"),
        reset = i18n("reset"),
        apply = i18n("apply"),
        cancel = i18n("cancel"),
        threshold = i18n("threshold"),
      }
    }))

    print(plugins_utils.renderTemplate("active_monitoring", "am_add_host_modal.html", {
      pools = am_pool,
      dialog = {
        add_record = i18n("active_monitoring_stats.add_record"),
        measurement = i18n("active_monitoring_stats.measurement"),
        add_measurement_select = generate_select("select-add-measurement", "measurement", true, false, {}, "measurement-select"),
        am_host = i18n("about.host_callbacks_directory"),
        periodicity = i18n("internals.periodicity"),
        add_granularity_select = generate_select("select-add-granularity", "granularity", true, false, {}, "measurement-granularity"),
        threshold = i18n("threshold"),
        notes = i18n("notes"),
        note_icmp = i18n("active_monitoring_stats.am_note_icmp"),
        note_http = i18n("active_monitoring_stats.am_note_http"),
        note_alert = i18n("active_monitoring_stats.note_alert"),
        cancel = i18n("cancel"),
        add = i18n("add"),
      }
    }))

    print(plugins_utils.renderTemplate("active_monitoring", "am_delete_host_modal.html", {
      dialog = {
	confirm_delete = i18n("active_monitoring_stats.confirm_delete"),
	delete = i18n("delete"),
	cancel = i18n("cancel"),
      }
    }))

    print([[
    <div class='mb-2'>

	<form class="form-inline" method="POST" id="reset-form">
	  <input type="hidden" name="csrf" value="]].. ntop.getRandomCSRFValue() ..[["/>
	  <input type="hidden" name="action" value="reset_config"/>
	  <button type="button" id="reset-modal-btn" data-toggle="modal" data-target="#reset-modal" class="btn btn-secondary"><span><i class="fas fa-undo"></i> ]] .. i18n('config_scripts.config_reset') .. [[</span></button>
  </form>
  <a class="btn-link btn" href="]]..ntop.getHttpPrefix()..[[/lua/admin/import_export_config.lua?item=active_monitoring">]] .. i18n("import_export.import_export") ..[[</a>

    </div>

  ]])

  local measurements_info = {}

  -- This information is required in active_monitoring_utils.js in order to properly
  -- render the template
  for key, info in pairs(active_monitoring_utils.getMeasurementsInfo()) do
    measurements_info[key] = {
      label = i18n(info.i18n_label) or info.i18n_label,
      granularities = active_monitoring_utils.getAvailableGranularities(key),
      operator = info.operator,
      unit = i18n(info.i18n_unit) or info.i18n_unit,
      force_host = info.force_host,
      max_threshold = info.max_threshold,
      default_threshold = info.default_threshold,
    }
  end

  print([[
    <link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet"/>
    <script type="text/javascript">

      i18n.pools = "]].. i18n("pools.pools") ..[[";
      i18n.showing_x_to_y_rows = "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[";
      i18n.search = "]].. i18n("search") ..[[:";
      i18n.msec = "]] .. i18n("active_monitoring_stats.msec") .. [[";
      i18n.edit = "]] .. i18n("users.edit") .. [[";
      i18n.success = "]] .. i18n("success") .. [[";
      i18n.delete = "]] .. i18n("delete") .. [[";
      i18n.expired_csrf = "]] .. i18n("expired_csrf") .. [[";
      i18n.all = "]] .. i18n("all") .. [[";
      i18n.measurement = "]] .. i18n("active_monitoring_stats.measurement") .. [[";
      i18n.alert_status = "]].. i18n("active_monitoring_stats.alert_status") ..[[";
      i18n.alerted = "]].. i18n("active_monitoring_stats.alerted") ..[[";
      i18n.not_alerted = "]].. i18n("active_monitoring_stats.not_alerted") ..[[";

      let get_host = "]].. (_GET["host"] ~= nil and _GET["host"] or "") ..[[";
      let am_csrf = "]].. ntop.getRandomCSRFValue() ..[[";
      let import_csrf = "]].. ntop.getRandomCSRFValue() ..[[";
      const measurements_info = ]] .. json.encode(measurements_info) .. [[;
      const poolsFilter = ]].. json.encode(pool_filters) ..[[;

    </script>
    <script type='text/javascript' src=']].. plugins_utils.getHttpdocsDir("active_monitoring") ..[[/active_monitoring_utils.js?]] ..(ntop.getStartupEpoch()) ..[['></script>
  ]])


elseif((page == "historical") and (host ~= nil) and (measurement_info ~= nil)) then

  local suffix = "_" .. host.granularity
  local schema = _GET["ts_schema"] or ("am_host:val" .. suffix)
  local selected_epoch = _GET["epoch"] or ""
  local tags = {ifid=getSystemInterfaceId(), host=host.host, metric=host.measurement --[[ note: measurement is a reserved InfluxDB keyword ]]}
  local am_ts_label
  local am_metric_label
  local notes = {
    i18n("graphs.red_line_unreachable")
  }

  if measurement_info.i18n_am_ts_label then
    am_ts_label = i18n(measurement_info.i18n_am_ts_label) or measurement_info.i18n_am_ts_label
  else
    -- Fallback
    am_ts_label = i18n("graphs.num_ms_rtt")
  end

  if measurement_info.i18n_am_ts_metric then
    am_metric_label = i18n(measurement_info.i18n_am_ts_metric) or measurement_info.i18n_am_ts_metric
  else
    am_metric_label = i18n("flow_details.round_trip_time")
  end

  url = url.."&page=historical"

  local timeseries = {
    { schema="am_host:val" .. suffix, label=am_ts_label,
      value_formatter=measurement_info.value_js_formatter or "NtopUtils.fmillis",
      metrics_labels={am_metric_label},
      show_unreachable = true, -- Show the unreachable host status as a red line
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
   _GET["entity"] = alert_consts.alertEntity("am_host")

   if host then
      _GET["entity_val"] = active_monitoring_utils.getAmHostKey(host.host, host.measurement)
   end

   alert_utils.drawAlerts()

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
