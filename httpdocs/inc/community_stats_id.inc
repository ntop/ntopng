

// ---------------- Automatic table update code ------------------------

var community_rows_option = {};

function community_table_setID (row) {
  var index = 0;
  var community_key = row.find("td").eq(0).text();
  
  // Set the row index to the community key
  row.attr('id', community_key);

  row.find("td").eq(index++).attr('id', community_key+"_key");
  // community_stats_top
  row.find("td").eq(index++).attr('id', community_key+"_index");
  
  // console.log(row);
  return row;

}

function row_update(community_key) {
   var url = "@HTTP_PREFIX@/lua/get_community_data.lua?id="+community_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function community_table_update () {

  var $dt = $("#table-communities").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var community_key = rows[row][0].id;
    row_update(community_key);
  }
}

// Refresh Interval (10 sec)
var community_table_interval = window.setInterval(community_table_update, 10000);
// ---------------- End automatic table update code ------------------------

