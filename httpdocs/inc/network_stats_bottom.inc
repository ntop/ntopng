			     {
			     title: "Breakdown",
				 field: "column_breakdown",
				 sortable: false,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "Throughput",
				 field: "column_thpt",
				 sortable: true,
	 	             css: { 
			        textAlign: 'right'
			     }
				 },
			     {
			     title: "Traffic",
				 field: "column_traffic",
				 sortable: true,
	 	             css: { 
			        textAlign: 'right'
			     }
				 }
			     ]
	       });


       </script>


NOTE: In case you have defined overlapping networks:<ol>
<li>You will see both network entries in the above table. 
<li>The broader network will not include hosts defined in smaller networks.
</ol>