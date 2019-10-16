// ---------------- Automatic table update code ------------------------
// Use the flow_rows_option object in order to simplify the option setting from lua script.

var flow_rows_option = {};
flow_rows_option["type"] = "flow";
flow_rows_option["vlan"] = false;
flow_rows_option["process"] = false;

function flow_table_rowID(flow_key, flow_hash_id) {
  return flow_key + "_" + flow_hash_id;
}

function flow_table_setID (row) {
  var index = 3;
  var flow_key = row.find("td").eq(0).text();
  var flow_hash_id = row.find("td").eq(1).text();
  var row_id = flow_table_rowID(flow_key, flow_hash_id);
  var type = flow_rows_option["type"];
  
  // Set the row index to the flow key
  row.attr('id', flow_key);
  row.attr('flow_key', flow_key);
  row.attr('flow_hash_id', flow_hash_id);

  // flows_stats_top
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_application");
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_l4");
  if (((type == 'flow') || (type == 'host')) 
      && (flow_rows_option["vlan"])) row.find("td").eq(index++).attr('id', row_id + "_vlan");
  if (((type == 'flow') || (type == 'host'))
      && (flow_rows_option["process"])) {
    row.find("td").eq(index++).attr('id', row_id + "_cli_process");
    row.find("td").eq(index++).attr('id', row_id + "_srv_process");
  }
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_client");
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_server");
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_duration");
  // flows_stats_bottom
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_breakdown");
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_throughput");
  if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', row_id + "_bytes");
  
  return row;
}


function row_update(flow_key, flow_hash_id) {
   var url = "@HTTP_PREFIX@/lua/get_flow_data.lua?flow_key=" + flow_key + "&flow_hash_id=" + flow_hash_id;
   var row_id = flow_table_rowID(flow_key, flow_hash_id);

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      // console.log(url);
      // console.log(data);
      $("#"+ row_id +'_duration').html(data.column_duration);
      $("#"+ row_id +'_breakdown').html(data.column_breakdown);
      $("#"+ row_id +'_throughput').html(data.column_thpt);
      $("#"+ row_id +'_bytes').html(data.column_bytes);

    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function flow_table_update () {

  var $dt = $("#table-flows").data("datatable"); 
  // var currentPage = $dt.options.currentPage;
  // var perPage = $dt.options.perPage;
  var rows = $dt.rows;

  $(rows).each(function(i, row){
      row_update(row.attr("flow_key"), row.attr("flow_hash_id"));
  });
}

// Refresh Interval (10 sec)
var flow_table_interval = window.setInterval(flow_table_update, 10000);
// ---------------- End automatic table update code ------------------------


