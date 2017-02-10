

// ---------------- Automatic HTTP servers table update code ------------------------

function http_table_setID (row) {
  var index = 0;
  var http_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', http_key);

  row.find("td").eq(index++).attr('id', http_key+"_key");
  row.find("td").eq(index++).attr('id', http_key+"_http_virtual_host");
  row.find("td").eq(index++).attr('id', http_key+"_server_ip");
  row.find("td").eq(index++).attr('id', http_key+"_hosts_to_server");
  row.find("td").eq(index++).attr('id', http_key+"_bytes_sent");
  row.find("td").eq(index++).attr('id', http_key+"_bytes_rcvd");
  row.find("td").eq(index++).attr('id', http_key+"_http_requests");
  row.find("td").eq(index++).attr('id', http_key+"_act_num_http_requests");

  return row;

}

function http_row_update(http_key) {
   var url = "@HTTP_PREFIX@/lua/get_http_hosts_data.lua?host="+http_key.split("___").join("."); /* Needed as JQuery does not like . in id= field */
   
  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);

      if(data.data.length > 0) {
       $("#"+http_key+'_bytes_sent').html(data.data[0].column_bytes_sent);
       $("#"+http_key+'_bytes_rcvd').html(data.data[0].column_bytes_rcvd);
       $("#"+http_key+'_http_requests').html(data.data[0].column_http_requests);
       $("#"+http_key+'_act_num_http_requests').html(data.data[0].column_act_num_http_requests);
      }
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function http_table_update () {

  var $dt = $("#table-http").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var http_key = rows[row][0].id;
    http_row_update(http_key);
  }
}

// Refresh Interval (7 sec)
var http_table_interval = window.setInterval(http_table_update, 7000);
// ---------------- End automatic table update code ------------------------
