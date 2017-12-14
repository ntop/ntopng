

// ---------------- Automatic pool table update code ------------------------

function pool_table_setID (row) {
  var index = 0;
  var pool_key = row.find("td").eq(0).text();

  // Set the row index to the pool key
  row.attr('id', pool_key);

  row.find("td").eq(index++).attr('id', pool_key+"_key");
  row.find("td").eq(index++).attr('id', pool_key+"_id");
  // pool_stats_top
  row.find("td").eq(index++).attr('id', pool_key+"_chart");
  row.find("td").eq(index++).attr('id', pool_key+"_hosts");
  row.find("td").eq(index++).attr('id', pool_key+"_num_flows");
  row.find("td").eq(index++).attr('id', pool_key+"_num_dropped_flows");
  row.find("td").eq(index++).attr('id', pool_key+"_alerts");
  row.find("td").eq(index++).attr('id', pool_key+"_since");

  // pool_stats_bottom
  row.find("td").eq(index++).attr('id', pool_key+"_breakdown");
  row.find("td").eq(index++).attr('id', pool_key+"_throughput");
  row.find("td").eq(index++).attr('id', pool_key+"_traffic");

  return row;

}

function pool_row_update(pool_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=pool_id&pool="+pool_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+pool_key+'_hosts').html(data.column_hosts);
      $("#"+pool_key+'_num_flows').html(data.column_num_flows);
      $("#"+pool_key+'_num_dropped_flows').html(data.column_num_dropped_flows);
      $("#"+pool_key+'_alerts').html(data.column_alerts);
      $("#"+pool_key+'_since').html(data.column_since);
      $("#"+pool_key+'_breakdown').html(data.column_breakdown);
      $("#"+pool_key+'_throughput').html(data.column_thpt);
      $("#"+pool_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function pool_table_update () {

  var $dt = $("#table-pool").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var pool_key = rows[row][0].id;
    pool_row_update(pool_key);
  }
}

// Refresh Interval (10 sec)
var pool_table_interval = window.setInterval(pool_table_update, 10000);
// ---------------- End automatic table update code ------------------------
