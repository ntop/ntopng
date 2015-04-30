

// ---------------- Automatic VLAN table update code ------------------------

function vlan_table_setID (row) {
  var index = 0;
  var vlan_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', vlan_key);

  row.find("td").eq(index++).attr('id', vlan_key+"_key");
  row.find("td").eq(index++).attr('id', vlan_key+"_number");
  // vlan_stats_top
  row.find("td").eq(index++).attr('id', vlan_key+"_hosts");
  row.find("td").eq(index++).attr('id', vlan_key+"_alerts");
  row.find("td").eq(index++).attr('id', vlan_key+"_name");
  row.find("td").eq(index++).attr('id', vlan_key+"_since");

  // vlan_stats_bottom
  row.find("td").eq(index++).attr('id', vlan_key+"_breakdown");
  row.find("td").eq(index++).attr('id', vlan_key+"_throughput");
  row.find("td").eq(index++).attr('id', vlan_key+"_traffic");

  return row;

}

function vlan_row_update(vlan_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=vlan&vlan="+vlan_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+vlan_key+'_hosts').html(data.column_hosts);
      $("#"+vlan_key+'_alerts').html(data.column_alerts);
      $("#"+vlan_key+'_since').html(data.column_since);
      $("#"+vlan_key+'_breakdown').html(data.column_breakdown);
      $("#"+vlan_key+'_throughput').html(data.column_thpt);
      $("#"+vlan_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function vlan_table_update () {

  var $dt = $("#table-vlan").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var vlan_key = rows[row][0].id;
    vlan_row_update(vlan_key);
  }
}

// Refresh Interval (10 sec)
var vlan_table_interval = window.setInterval(vlan_table_update, 10000);
// ---------------- End automatic table update code ------------------------
