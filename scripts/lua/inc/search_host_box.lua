--
-- (C) 2013 - ntop.org
--

print [[
	 <li><form action="/lua/host_details.lua" id="search-host-form" data-toggle="validator">
]]

-- FIX: show notifications to the user
--        print('<a class="btn" href="#"><i class="fa fa-bell fa-lg"></i></a>')

print [[

	 <div class="control-group" style="width:15em;">
           <div class="input-group">
             <span class="input-group-btn">
               <button class="btn btn-default" type="submit" id="search-submit">
                 <span class="glyphicon glyphicon-search"></span>
               </button>
             </span>
             <input id="search_host_ip" type="hidden" name="host"/>
	     <input id="search_typeahead" type="text" data-minlength="1" class="form-control search-query span2" placeholder="Search Host" data-provide="typeahead" autocomplete="off"></input>
	   </div>
         </div>
	 </form>

	 </li>

	 <script type='text/javascript'>
	 $('#search_typeahead').typeahead({
	     source: function (query, process) {
	             return $.get(']]
print (ntop.getHttpPrefix())
print [[/lua/find_host.lua', { query: query }, function (data) {
		                 return process(data.results);
		});
	 }, afterSelect: function(item) {
      $("#search_host_ip").val(item.ip);
	 }
	});


  $('#search-submit').click(function(e) {
    if ($('#search_host_ip').val() === '') {
      /* No typeahead result has been selected by the user */
      if($('#search_typeahead').val() === '') {
        /* Do not submit if also the typeahead content is empty */
        e.preventDefault();
      } else {
        /* Populate the search host ip with the user submitted values */
        $("#search_host_ip").val($('#search_typeahead').val())
      }
    }
});

	</script>

   ]]

