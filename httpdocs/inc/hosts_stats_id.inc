

// ---------------- Automatic table update code ------------------------
// Use the host_rows_option object in order to simplify the option setting from lua script.

var host_rows_option = {};
host_rows_option["ip"] = false;
host_rows_option["vlan"] = false;


function host_table_setID (row) {
  var index = 0;
  var host_key = row.find("td").eq(0).text();
  
  // Set the row index to the host key
  row.attr('id', host_key);

  row.find("td").eq(index++).attr('id', host_key+"_key");
  row.find("td").eq(index++).attr('id', host_key+"_info");
  //custom
  if (host_rows_option["ip"]) row.find("td").eq(index++).attr('id', host_key+"_ip");
  if (host_rows_option["vlan"]) row.find("td").eq(index++).attr('id', host_key+"_vlan");

  // hosts_stats_top
  row.find("td").eq(index++).attr('id', host_key+"_num_flows");
  row.find("td").eq(index++).attr('id', host_key+"_num_dropped_flows");
  row.find("td").eq(index++).attr('id', host_key+"_custom");
  row.find("td").eq(index++).attr('id', host_key+"_name");
  row.find("td").eq(index++).attr('id', host_key+"_since");
  
  // hosts_stats_bottom
  row.find("td").eq(index++).attr('id', host_key+"_score");
  row.find("td").eq(index++).attr('id', host_key+"_breakdown");
  row.find("td").eq(index++).attr('id', host_key+"_throughput");
  row.find("td").eq(index++).attr('id', host_key+"_traffic");
  
  //console.log(row);
  return row;

}

function get_row_key(host_key) {
  var hostInfo = NtopUtils.hostkey2hostInfo(host_key);

  let host_key_lua = hostInfo[0];

  var vlan = "";
  if (hostInfo[1]) {
    host_key_lua += "@" + hostInfo[1];
  }
  
  return host_key_lua;
}

function row_update(host_key, data) {
  if (!data) return;
  $('td[id="'+host_key+'_since"]').html(data.column_since);
  $('td[id="'+host_key+'_score"]').html(data.column_score);
  $('td[id="'+host_key+'_breakdown"]').html(data.column_breakdown);
  $('td[id="'+host_key+'_throughput"]').html(data.column_thpt);
  $('td[id="'+host_key+'_traffic"]').html(data.column_traffic);
  $('td[id="'+host_key+'_num_flows"]').html(data.column_num_flows);
  $('td[id="'+host_key+'_num_dropped_flows"]').html(data.column_num_dropped_flows);
  $('td[id="'+host_key+'_custom"]').html(data.column_custom);
}

// Updating function
function host_table_update () {

  var $dt = $("#table-hosts").data("datatable");
  var rows = $dt.rows;

  var custom_column = "";
  if(host_rows_option["custom_column"])
    custom_column = "custom_column=" + host_rows_option["custom_column"];

  let url = "@HTTP_PREFIX@/lua/get_hosts_stats.lua?" + custom_column + "&hosts=";

  for (var row in rows) {
    let host_key = rows[row][0].id;
    let host_key_lua = get_row_key(host_key);
    url += host_key_lua + ",";
  }

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(data) {
      for (var row in rows) {
         let host_key = rows[row][0].id;
         let host_key_lua = get_row_key(host_key);
         row_update(host_key, data[host_key_lua]);
      }
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Refresh Interval (10 sec)
var host_table_interval = window.setInterval(host_table_update, 10000);
// ---------------- End automatic table update code ------------------------

