OBJECTS=minified/fontawesome-custom.min.css minified/ntopng.min.css minified/heatmap.min.css \
					minified/rickshaw.min.css minified/bootstrap-orange.min.css minified/dark-mode.min.css \
					minified/tempusdominus.min.css

minify: $(OBJECTS)

clean:
	rm -f $(OBJECTS)

%.min.css:
	cleancss -o $@ $^ -O2

minified/fontawesome-custom.min.css: ../fontawesome-free-5.11.2-web/css/fontawesome.css \
					../fontawesome-free-5.11.2-web/css/brands.css ../fontawesome-free-5.11.2-web/css/solid.css

minified/ntopng.min.css: ntopng.css sidebar.css
minified/heatmap.min.css: heatmap.css cal-heatmap.css
minified/rickshaw.min.css: rickshaw.css
minified/bootstrap-orange.min.css: ../bootstrap-custom/ntopng-theme.css
minified/dark-mode.min.css: dark-mode.css
minified/tempusdominus.min.css: ../tempusdominus/css/tempusdominus-bootstrap-4.css
