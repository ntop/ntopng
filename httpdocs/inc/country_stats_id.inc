

// ---------------- Automatic Country table update code ------------------------

function country_table_setID (row) {
  var index = 0;
  var country_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', country_key);

  row.find("td").eq(index++).attr('id', country_key+"_key");
  row.find("td").eq(index++).attr('id', country_key+"_number");
  // skip chart column
  index++;
  // country_stats_top
  row.find("td").eq(index++).attr('id', country_key+"_hosts");
  row.find("td").eq(index++).attr('id', country_key+"_alerts");

  row.find("td").eq(index++).attr('id', country_key+"_since");

  // country_stats_bottom
  row.find("td").eq(index++).attr('id', country_key+"_breakdown");
  row.find("td").eq(index++).attr('id', country_key+"_throughput");
  row.find("td").eq(index++).attr('id', country_key+"_traffic");

  return row;

}

function country_row_update(country_key) {
   var url = "@HTTP_PREFIX@/lua/get_grouped_hosts_data.lua?grouped_by=country&country="+country_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+country_key+'_hosts').html(data.column_hosts);
      $("#"+country_key+'_alerts').html(data.column_alerts);
      $("#"+country_key+'_since').html(data.column_since);
      $("#"+country_key+'_breakdown').html(data.column_breakdown);
      $("#"+country_key+'_throughput').html(data.column_thpt);
      $("#"+country_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function country_table_update () {

  var $dt = $("#table-country").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var country_key = rows[row][0].id;
    country_row_update(country_key);
  }
}

// Refresh Interval (10 sec)
var country_table_interval = window.setInterval(country_table_update, 10000);
// ---------------- End automatic table update code ------------------------
