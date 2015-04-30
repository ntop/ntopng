

// ---------------- Automatic network table update code ------------------------

function network_table_setID (row) {
  var index = 0;
  var network_key = row.find("td").eq(0).text();

  // Set the row index to the network key
  row.attr('id', network_key);

  row.find("td").eq(index++).attr('id', network_key+"_key");
  row.find("td").eq(index++).attr('id', network_key+"_number");
  // network_stats_top
  row.find("td").eq(index++).attr('id', network_key+"_hosts");
  row.find("td").eq(index++).attr('id', network_key+"_alerts");
  row.find("td").eq(index++).attr('id', network_key+"_since");

  // network_stats_bottom
  row.find("td").eq(index++).attr('id', network_key+"_breakdown");
  row.find("td").eq(index++).attr('id', network_key+"_throughput");
  row.find("td").eq(index++).attr('id', network_key+"_traffic");

  return row;

}

function network_row_update(network_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=local_network_id&network="+network_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+network_key+'_hosts').html(data.column_hosts);
      $("#"+network_key+'_alerts').html(data.column_alerts);
      $("#"+network_key+'_since').html(data.column_since);
      $("#"+network_key+'_breakdown').html(data.column_breakdown);
      $("#"+network_key+'_throughput').html(data.column_thpt);
      $("#"+network_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function network_table_update () {

  var $dt = $("#table-network").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var network_key = rows[row][0].id;
    network_row_update(network_key);
  }
}

// Refresh Interval (10 sec)
var network_table_interval = window.setInterval(network_table_update, 10000);
// ---------------- End automatic table update code ------------------------
