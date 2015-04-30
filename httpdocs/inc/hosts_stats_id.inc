

// ---------------- Automatic table update code ------------------------
// Use the host_rows_option object in order to simplify the option setting from lua script.

var host_rows_option = {};
host_rows_option["ip"] = false;
host_rows_option["categorization"] = false;
host_rows_option["httpbl"] = false;
host_rows_option["vlan"] = false;


function host_table_setID (row) {
  var index = 0;
  var host_key = row.find("td").eq(0).text();
  
  // Set the row index to the host key
  row.attr('id', host_key);

  row.find("td").eq(index++).attr('id', host_key+"_key");
  //custom
  if (host_rows_option["ip"]) row.find("td").eq(index++).attr('id', host_key+"_ip");
  if (host_rows_option["vlan"]) row.find("td").eq(index++).attr('id', host_key+"_vlan");
  // hosts_stats_top
  row.find("td").eq(index++).attr('id', host_key+"_location");
  row.find("td").eq(index++).attr('id', host_key+"_alerts");
  row.find("td").eq(index++).attr('id', host_key+"_name");
  row.find("td").eq(index++).attr('id', host_key+"_since");
  row.find("td").eq(index++).attr('id', host_key+"_asn");
  
  //custom
  if (host_rows_option["categorization"]) row.find("td").eq(index++).attr('id', host_key+"_category");
  if (host_rows_option["httpbl"]) row.find("td").eq(index++).attr('id', host_key+"_httpbl");
  
  // hosts_stats_bottom
  row.find("td").eq(index++).attr('id', host_key+"_breakdown");
  row.find("td").eq(index++).attr('id', host_key+"_throughput");
  row.find("td").eq(index++).attr('id', host_key+"_traffic");
  
  // console.log(row);
  return row;

}

function hostkey2hostInfo(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/____/g, ":");
    host_key = host_key.replace(/___/g, "/");
    host_key = host_key.replace(/__/g, ".");
    host_key = host_key.replace(/@/g, ".");

    info = host_key.split("@");
    return(info);
} 

function row_update(host_key) {
   var hostInfo = hostkey2hostInfo(host_key);
   var url = "@HTTP_PREFIX@/lua/get_host_data.lua?host="+hostInfo[0]+"&vlan=" + hostInfo[1];

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      // console.log(url);
      // console.log(data);
      $("#"+host_key+'_since').html(data.column_since);
      $("#"+host_key+'_breakdown').html(data.column_breakdown);
      $("#"+host_key+'_throughput').html(data.column_thpt);
      $("#"+host_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function host_table_update () {

  var $dt = $("#table-hosts").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var host_key = rows[row][0].id;
    row_update(host_key);
  }
}

// Refresh Interval (10 sec)
var host_table_interval = window.setInterval(host_table_update, 10000);
// ---------------- End automatic table update code ------------------------

