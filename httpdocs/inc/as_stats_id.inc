

// ---------------- Automatic AS table update code ------------------------

function as_table_setID (row) {
  var index = 0;
  var as_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', as_key);

  row.find("td").eq(index++).attr('id', as_key+"_key");

  row.find("td").eq(index++).attr('id', as_key+"_asn");
  row.find("td").eq(index++).attr('id', as_key+"_chart");

  row.find("td").eq(index++).attr('id', as_key+"_hosts");
  row.find("td").eq(index++).attr('id', as_key+"_alerts");

  row.find("td").eq(index++).attr('id', as_key+"_asname");

  row.find("td").eq(index++).attr('id', as_key+"_since");
  row.find("td").eq(index++).attr('id', as_key+"_breakdown");
  row.find("td").eq(index++).attr('id', as_key+"_throughput");
  row.find("td").eq(index++).attr('id', as_key+"_traffic");

  return row;

}

function as_row_update(as_key) {
   var url = "@HTTP_PREFIX@/lua/get_as_data.lua?asn="+as_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+as_key+'_asn').html(data.column_asn);
      $("#"+as_key+'_chart').html(data.column_chart);

      $("#"+as_key+'_hosts').html(data.column_hosts);
      $("#"+as_key+'_alerts').html(data.column_alerts);

      $("#"+as_key+'_asname').html(data.column_asname);

      $("#"+as_key+'_since').html(data.column_since);
      $("#"+as_key+'_breakdown').html(data.column_breakdown);
      $("#"+as_key+'_throughput').html(data.column_thpt);
      $("#"+as_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function as_table_update () {
  var $dt = $("#table-as").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var as_key = rows[row][0].id;
    as_row_update(as_key);
  }
}

// Refresh Interval (10 sec)
var as_table_interval = window.setInterval(as_table_update, 10000);
// ---------------- End automatic table update code ------------------------
