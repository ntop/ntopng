

// ---------------- Automatic table update code ------------------------
// Use the flow_rows_option object in order to simplify the option setting from lua script.

var flow_rows_option = {};
flow_rows_option["type"] = "flow";
flow_rows_option["vlan"] = false;
flow_rows_option["categorization"] = false;
flow_rows_option["sprobe"] = false;

function flow_table_setID (row) {
  var index = 0;
  var flow_key = row.find("td").eq(0).text();
  var type = flow_rows_option["type"];
  
  // Set the row index to the flow key
  row.attr('id', flow_key);

  if (!flow_rows_option["sprobe"]) {
    
    // flows_stats_top
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_key");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_info");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_application");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_l4");
    if (((type == 'flow') || (type == 'host')) 
        && (flow_rows_option["vlan"])) row.find("td").eq(index++).attr('id', flow_key+"_vlan");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_client");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_server");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_duration");
    //custom
    if ((type == 'flow') && (flow_rows_option["categorization"])) row.find("td").eq(index++).attr('id', flow_key+"_category");
    // flows_stats_bottom
    if (type == 'flow') row.find("td").eq(index++).attr('id', flow_key+"_breakdown");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_throughput");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_bytes");
  
  } else {

    // flows_stats_top
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_key");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_info");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_application");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_l4");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_cliproc");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_client");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_srvproc");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_server");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_duration");
    
    // flows_stats_bottom
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_breakdown");
    if ((type == 'flow') || (type == 'host')) row.find("td").eq(index++).attr('id', flow_key+"_bytes");

  }
  
  //console.log(row);
  return row;

}


function row_update(flow_key) {
   var url = "@HTTP_PREFIX@/lua/get_flow_data.lua?flow_key="+flow_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      // console.log(url);
      // console.log(data);
      $("#"+flow_key+'_duration').html(data.column_duration);
      $("#"+flow_key+'_breakdown').html(data.column_breakdown);
      $("#"+flow_key+'_throughput').html(data.column_thpt);
      $("#"+flow_key+'_bytes').html(data.column_bytes);

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

  for (var row in rows){
    var flow_key = rows[row][0].id;
    row_update(flow_key);
  }
}

// Refresh Interval (10 sec)
var flow_table_interval = window.setInterval(flow_table_update, 10000);
// ---------------- End automatic table update code ------------------------


