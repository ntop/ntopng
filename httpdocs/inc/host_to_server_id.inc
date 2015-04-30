

// ---------------- Automatic HTTP servers table update code ------------------------

function http_table_setID (row,j) {
  var index = 0;
    var http_key = row.find("td").eq(0).text();
 
  http_key = http_key.split(".").join("_")
  j = j.split(".").join("_")
  
  row.attr('id', http_key+"__"+j);
  
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_key");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_http_virtual_host");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_server_ip");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_proto");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_bytes_sent");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_bytes_rcvd");
  row.find("td").eq(index++).attr('id', http_key+"__"+j+"_duration");
  

  return row;

}

function http_row_update(http_key, host_key) {
	
   var url = "@HTTP_PREFIX@/lua/get_filter_host.lua?host="+host_key+"&key="+http_key;
   
  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      console.log ( data);
      
      
       $("#"+http_key.split(".").join("_") +"__"+host_key.split(".").join("_") +'_bytes_sent').html(data.column_bytes_sent);
       $("#"+http_key.split(".").join("_") +"__"+host_key.split(".").join("_") +'_bytes_rcvd').html(data.column_bytes_rcvd);
       $("#"+http_key.split(".").join("_") +"__"+host_key.split(".").join("_") +'_duration').html(data.column_duration);
      
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
    
	 console.log ( rows[row][0].id );
	 var temp = new Array();

 	 temp = http_key.split("__");
	 temp[0] = temp[0].split("_").join(".") 
	 temp[1] = temp[1].split("_").join(".")
    http_row_update(temp[0], temp[1]);
    
  }
}

// Refresh Interval (7 sec)
var http_table_interval = window.setInterval(http_table_update, 7000);
// ---------------- End automatic table update code ------------------------
