OBJECTS=ntopng.min.css heatmap.min.css rickshaw.min.css bootstrap-orange.min.css dark-mode.min.css tempusdominus.min.css

minify: $(OBJECTS)

clean:
	rm -f $(OBJECTS)

%.min.css:
	cleancss $^ -O2 > minified/$@

ntopng.min.css: ntopng.css sidebar.css
heatmap.min.css: heatmap.css cal-heatmap.css
rickshaw.min.css: rickshaw.css
dark-mode.min.css: dark-mode.css
tempusdominus.min.css: ../tempusdominus/css/tempusdominus-bootstrap-4.css
