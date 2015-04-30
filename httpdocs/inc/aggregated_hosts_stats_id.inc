

// ---------------- Automatic table update code ------------------------
// Use the aggregated_host_rows_option object in order to simplify the option setting from lua script.
var aggregated_host_rows_option = {};
var aggregated_host_debug = false;

function aggregated_host_table_setID (row) {
  var index = 0;
  var aggregated_host_key = row.find("td").eq(0).text();
  if (aggregated_host_debug) console.log(aggregated_host_key);
  // Set the row index to the host key
  row.attr('id', aggregated_host_key);

  row.find("td").eq(index++).attr('id', aggregated_host_key+"_key");
  //hosts_stats_top
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_ip");
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_family");
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_aggregation");
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_since");
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_last");
  row.find("td").eq(index++).attr('id', aggregated_host_key+"_queries");

  // console.log(row);
  return row;
}

function hostkey2hostInfo(aggregated_host_key) {
    var hostinfo = aggregated_host_key.replace(/_/g,".");
    return (hostinfo);
} 


function row_update(aggregated_host_key) {
   // custom script to update a single row
   var host = hostkey2hostInfo(aggregated_host_key);
   var url = "@HTTP_PREFIX@/lua/get_host_data.lua?aggregated=1&host="+host;
   if (aggregated_host_debug) console.log(url);
  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      if (aggregated_host_debug) console.log(data);
      $("#"+aggregated_host_key+'_since').html(data.column_since);
      $("#"+aggregated_host_key+'_last').html(data.column_last);
      $("#"+aggregated_host_key+'_queries').html(data.column_queries);
    },
    error: function(content) {
      console.log("error");
    }
  });

}

// Updating function
function aggregated_host_table_update () {

  var $dt = $("#table-hosts").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var aggregated_host_key = rows[row][0].id;
    row_update(aggregated_host_key);
  }
}

// Refresh Interval (10 sec)
var aggregated_host_table_interval = window.setInterval(aggregated_host_table_update, 10000);
// ---------------- End automatic table update code ------------------------

