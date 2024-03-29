

// ---------------- Automatic mac table update code ------------------------

function mac_table_setID (row) {
  var index = 0;
  var mac_key = row.find("td").eq(0).text();

  // Set the row index to the mac key
  row.attr('id', mac_key);

  row.find("td").eq(index++).attr('id', mac_key+"_key");
  row.find("td").eq(index++).attr('id', mac_key+"_mac");
  row.find("td").eq(index++).attr('id', mac_key+"_manufacturer");
  row.find("td").eq(index++).attr('id', mac_key+"_device_type");
  row.find("td").eq(index++).attr('id', mac_key+"_name");

  row.find("td").eq(index++).attr('id', mac_key+"_hosts");
  row.find("td").eq(index++).attr('id', mac_key+"_arp_total");

  row.find("td").eq(index++).attr('id', mac_key+"_since");
  row.find("td").eq(index++).attr('id', mac_key+"_breakdown");
  row.find("td").eq(index++).attr('id', mac_key+"_throughput");
  row.find("td").eq(index++).attr('id', mac_key+"_traffic");

  return row;

}

function get_row_key(mac_key) {
  var hostInfo = NtopUtils.hostkey2hostInfo(mac_key);

  let host_key_lua = hostInfo[0];

  var vlan = "";
  if (hostInfo[1]) {
    host_key_lua += "@" + hostInfo[1];
  }
  
  return host_key_lua;
}

function mac_row_update(mac_key, data) {
  $("#"+mac_key+'_hosts').html(data.column_hosts);
  $("#"+mac_key+'_arp_total').html(data.column_arp_total);
  $("#"+mac_key+'_device_type').html(data.column_device_type);
  $("#"+mac_key+'_name').html(data.column_name);

  $("#"+mac_key+'_since').html(data.column_since);
  $("#"+mac_key+'_breakdown').html(data.column_breakdown);
  $("#"+mac_key+'_throughput').html(data.column_thpt);
  $("#"+mac_key+'_traffic').html(data.column_traffic);
}

// Updating function
function mac_table_update () {

  var $dt = $("#table-mac").data("datatable");
  var rows = $dt.rows;

  let url = "@HTTP_PREFIX@/lua/get_macs_stats.lua?hosts=";

  for (var row in rows) {
    let mac_key = rows[row][0].id;
    let mac_key_lua = get_row_key(mac_key);
    url += mac_key_lua + ",";
  }

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);

      for (var row in rows){
        var mac_key = rows[row][0].id;
        let mac_key_lua = get_row_key(mac_key);
        mac_row_update(mac_key, data[mac_key_lua]);
      }
    },
    error: function(content) {
      console.log("error");
    }
  });

}

// Refresh Interval (10 sec)
var mac_table_interval = window.setInterval(mac_table_update, 10000);
// ---------------- End automatic table update code ------------------------
