--
-- (C) 2013 - ntop.org
--

print [[
	 <li><form action="/lua/host_details.lua">
]]

-- FIX: show notifications to the user
--        print('<a class="btn" href="#"><i class="fa fa-bell fa-lg"></i></a>')

print [[


	 <div class="control-group" style="width:15em;">
          <div class="input-group"><span class="input-group-addon"><span class="glyphicon glyphicon-search"></span></span>
	 <input id="search_typeahead" type="text" name="host" class="form-control search-query span2" placeholder="Search Host" data-provide="typeahead" autocomplete="off"></input>
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
	 }
	});
	</script>

   ]]

