

// ---------------- Automatic OS table update code ------------------------

function os_table_setID (row) {
  var index = 0;
  var os_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', os_key);

  row.find("td").eq(index++).attr('id', os_key+"_key");
  row.find("td").eq(index++).attr('id', os_key+"_number");
  // os_stats_top
  row.find("td").eq(index++).attr('id', os_key+"_hosts");
  row.find("td").eq(index++).attr('id', os_key+"_alerts");

  row.find("td").eq(index++).attr('id', os_key+"_since");

  // os_stats_bottom
  row.find("td").eq(index++).attr('id', os_key+"_breakdown");
  row.find("td").eq(index++).attr('id', os_key+"_throughput");
  row.find("td").eq(index++).attr('id', os_key+"_traffic");

  return row;

}

function os_row_update(os_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=os&os="+os_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $('td[id="' + os_key + '_hosts"]').html(data.column_hosts);
      $('td[id="' + os_key + '_alerts"]').html(data.column_alerts);
      $('td[id="' + os_key + '_since"]').html(data.column_since);
      $('td[id="' + os_key + '_breakdown"]').html(data.column_breakdown);
      $('td[id="' + os_key + '_throughput"]').html(data.column_thpt);
      $('td[id="' + os_key + '_traffic"]').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function os_table_update () {
  var $dt = $("#table-os").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var os_key = rows[row][0].id;
    os_row_update(os_key);
  }
}

// Refresh Interval (10 sec)
var os_table_interval = window.setInterval(os_table_update, 10000);
// ---------------- End automatic table update code ------------------------
