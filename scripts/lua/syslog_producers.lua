--
-- (C) 2019-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path

require "lua_utils"

local checks = require "checks"

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
local syslog_scripts = checks.listScripts(checks.script_types.syslog, "syslog")
for k,v in pairs(syslog_scripts) do
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
    <script type="text/javascript">

      i18n.showing_x_to_y_rows = "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[";
      i18n.search = "]].. i18n("search") ..[[:";
      i18n.edit = "]] .. i18n("users.edit") .. [[";
      i18n.delete = "]] .. i18n("delete") .. [[";
      i18n.expired_csrf = "]] .. i18n("expired_csrf") .. [[";

      let get_host = "]].. (_GET["host"] ~= nil and _GET["host"] or "") ..[[";
      let syslog_producers_csrf = "]].. ntop.getRandomCSRFValue() ..[[";

      let syslog_producers_alert_timeout = null;
  
      $("#syslog-producers-add-form").on('submit', function(event) {
  
          event.preventDefault();
  
          const host = $("#input-add-host").val(), producer = $("#select-add-producer").val();
  
          perform_request(make_data_to_send('add', host, producer, syslog_producers_csrf));
  
      });
  
      $('#syslog-producers-table').on('click', `a[href='#syslog-producers-delete-modal']`, function(e) {
  
          const row_data = get_syslog_producers_data($syslog_producers_table, $(this));
          $("#delete-host").html(`<b>${row_data.url}</b>`);
          $(`#syslog-producers-delete-modal span.invalid-feedback`).hide();
  
          $('#syslog-producers-delete-form').off('submit').on('submit', function(e) {
  
              e.preventDefault();
              perform_request({
                  action: 'delete',
                  syslog_producer_host: row_data.host,
                  syslog_producer: row_data.producer,
                  csrf: syslog_producers_csrf
              })
          });
  
  
      });
  
      $('#syslog-producers-table').on('click', `a[href='#syslog-producers-edit-modal']`, function(e) {
  
          const fill_form = (data) => {
  
              const DEFAULT_PRODUCER = "";
              const DEFAULT_HOST     = "";
  
              // fill input boxes
              $('#select-edit-producer').val(data.producer || DEFAULT_PRODUCER);
              $('#input-edit-host').val(data.host || DEFAULT_HOST);
          }
  
          const data = get_syslog_producers_data($syslog_producers_table, $(this));
  
          // bind submit to form for edits
          $("#syslog-producers-edit-form").off('submit').on('submit', function(event) {
  
              event.preventDefault();
  
              const host = $("#input-edit-host").val(), producer = $("#select-edit-producer").val();
              const data_to_send = {
                  action: 'edit',
                  syslog_producer_host: host,
                  syslog_producer: producer,
                  old_syslog_producer_host: data.host,
                  old_syslog_producer: data.producer,
                  csrf: syslog_producers_csrf
              };
  
              perform_request(data_to_send);
  
          });
  
          // create a closure for reset button
          $('#btn-reset-defaults').off('click').on('click', function() {
              fill_form(data);
          });
  
          fill_form(data);
          $(`#syslog-producers-edit-modal span.invalid-feedback`).hide();
  
      });
  
      const make_data_to_send = (action, syslog_producer_host, syslog_producers_measure, csrf) => {
          return {
              action: action,
              syslog_producer_host: syslog_producer_host,
              syslog_producer: syslog_producers_measure,
              csrf: csrf
          }
      }
  
      const perform_request = (data_to_send) => {
  
          const {action} = data_to_send;
          if (action != 'add' && action != 'edit' && action != "delete") {
              console.error("The requested action is not valid!");
              return;
          }
  
          $(`#syslog-producers-${action}-modal span.invalid-feedback`).hide();
          $('#syslog-producers-alert').hide();
          $(`form#syslog-producers-${action}-modal button[type='submit']`).attr("disabled", "disabled");
  
          $.post(`${http_prefix}/lua/edit_syslog_producer.lua`, data_to_send)
          .then((data, result, xhr) => {
  
              $(`form#syslog-producers-${action}-modal button[type='submit']`).removeAttr("disabled");
              $('#syslog-producers-alert').addClass('alert-success').removeClass('alert-danger');
  
              if (data.success) {
  
                  if (!syslog_producers_alert_timeout) clearTimeout(syslog_producers_alert_timeout);
                  syslog_producers_alert_timeout = setTimeout(() => {
                      $('#syslog-producers-alert').fadeOut();
                  }, 1000)
  
                  $('#syslog-producers-alert .alert-body').text(data.message);
                  $('#syslog-producers-alert').fadeIn();
                  $(`#syslog-producers-${action}-modal`).modal('hide');
                  $syslog_producers_table.ajax.reload();
                  return;
              }
  
              const error_message = data.error;
              $(`#syslog-producers-${action}-modal span.invalid-feedback`).html(error_message).show();
  
          })
          .fail((status) => {
              $('#syslog-producers-alert').removeClass('alert-success').addClass('alert-danger');
              $('#syslog-producers-alert .alert-body').text(i18n.expired_csrf);
          });
      }
  
      const get_syslog_producers_data = ($syslog_producers_table, $button_caller) => {
  
          const row_data = $syslog_producers_table.row($button_caller.parent()).data();
          return row_data;
      }
  
      const $syslog_producers_table = $("#syslog-producers-table").DataTable({
          pagingType: 'full_numbers',
          lengthChange: false,
          stateSave: true,
          dom: 'lfBrtip',
          language: {
              info: i18n.showing_x_to_y_rows,
              search: i18n.search,
              infoFiltered: "",
              paginate: {
                  previous: '&lt;',
                  next: '&gt;',
                  first: '«',
                  last: '»'
              }
          },
          initComplete: function() {
  
              if (get_host != "") {
                  $syslog_producers_table.search(get_host).draw(true);
                  $syslog_producers_table.state.clear();
              }
  
              setInterval(() => {
                  $syslog_producers_table.ajax.reload()
              }, 15000);
          },
          ajax: {
              url: `${http_prefix}/lua/rest/v2/get/syslog/producer/list.lua`,
              type: 'get',
              dataSrc: ''
          },
          buttons: {
              buttons: [
                  {
                      text: '<i class="fas fa-plus"></i>',
                      className: 'btn-link',
                      action: function(e, dt, node, config) {
                          $('#input-add-host').val('');
                          $(`#syslog-producers-add-modal span.invalid-feedback`).hide();
                          $('#syslog-producers-add-modal').modal('show');
                      }
                  }
              ],
              dom: {
                  button: {
                      className: 'btn btn-link'
                  }
              }
          },
          columns: [
              {
                  data: 'producer_title'
              },
              {
                  data: 'host',
                  className: 'dt-body-right dt-head-center'
              },
              {
                  targets: -1,
                  data: null,
                  sortable: false,
                  name: 'actions',
                  class: 'text-center',
                  render: function() {
                      return `
                          <a class="badge bg-info" data-bs-toggle="modal" href="#syslog-producers-edit-modal">${i18n.edit}</a>
                          <a class="badge bg-danger" data-bs-toggle="modal" href="#syslog-producers-delete-modal">${i18n.delete}</a>
                      `;
                  }
              }
          ]
      });    
    </script>
]])

