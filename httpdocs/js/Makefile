
JQUERY_BOOTSTRAP_MIN_JS=jquery_bootstrap.min.js
JQUERY_BOOTSTRAP_MIN_JS_SRC=jquery.js jquery-ui.js bootstrap.js\
			    bootstrap-datatable.js bootstrap3-typeahead.js\
			    d3.v3.js jquery.peity.js bootstrap-slider.js			    

DEP_MIN_JS=deps.min.js
DEP_MIN_JS_SRC=rickshaw.js pie-chart.js gauge.js \
		  crossfilter.js validator.js validator.js \
		  dc.js cal-heatmap.js nv.d3.js \
		  jquery.bootstrap-duallistbox.js jquery.are-you-sure.js \
		  moment.js bootstrap-datetimepicker.js

NTOP_MIN_JS=ntop.min.js
NTOP_MIN_JS_SRC=springy-ntop.js springyui-ntop.js datatable_utils.js\
		  ays_utils.js ntopng_utils.js




minify: $(JQUERY_BOOTSTRAP_MIN_JS) $(DEP_MIN_JS) $(NTOP_MIN_JS)

$(JQUERY_BOOTSTRAP_MIN_JS): $(JQUERY_BOOTSTRAP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ --source-map $@.map -- $(JQUERY_BOOTSTRAP_MIN_JS_SRC)

$(DEP_MIN_JS): $(DEP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ --source-map $@.map -- $(DEP_MIN_JS_SRC)

$(NTOP_MIN_JS): $(NTOP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ --source-map $@.map -- $(NTOP_MIN_JS_SRC)

clean:
	rm -f $(JQUERY_BOOTSTRAP_MIN_JS) $(DEP_MIN_JS) $(NTOP_MIN_JS) *.map
