

// ---------------- Automatic mac table update code ------------------------

function mac_table_setID (row) {
  var index = 0;
  var mac_key = row.find("td").eq(0).text();

  // Set the row index to the mac key
  row.attr('id', mac_key);

  row.find("td").eq(index++).attr('id', mac_key+"_key");
  row.find("td").eq(index++).attr('id', mac_key+"_number");
  // mac_stats_top
  row.find("td").eq(index++).attr('id', mac_key+"_hosts");
  row.find("td").eq(index++).attr('id', mac_key+"_alerts");
  row.find("td").eq(index++).attr('id', mac_key+"_since");

  // mac_stats_bottom
  row.find("td").eq(index++).attr('id', mac_key+"_breakdown");
  row.find("td").eq(index++).attr('id', mac_key+"_throughput");
  row.find("td").eq(index++).attr('id', mac_key+"_traffic");

  return row;

}

function mac_row_update(mac_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=mac&mac="+mac_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+mac_key+'_hosts').html(data.column_hosts);
      $("#"+mac_key+'_alerts').html(data.column_alerts);
      $("#"+mac_key+'_since').html(data.column_since);
      $("#"+mac_key+'_breakdown').html(data.column_breakdown);
      $("#"+mac_key+'_throughput').html(data.column_thpt);
      $("#"+mac_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function mac_table_update () {

  var $dt = $("#table-mac").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var mac_key = rows[row][0].id;
    mac_row_update(mac_key);
  }
}

// Refresh Interval (10 sec)
var mac_table_interval = window.setInterval(mac_table_update, 10000);
// ---------------- End automatic table update code ------------------------
