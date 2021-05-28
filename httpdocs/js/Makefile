
JQUERY_BOOTSTRAP_MIN_JS=jquery_bootstrap.min.js
JQUERY_BOOTSTRAP_MIN_JS_SRC=jquery.js jquery-ui.js \
			    bootstrap-datatable.js bootstrap3-typeahead.js\
			    d3.v3.js jquery.peity.js sidebar.js bootstrap-slider.js jquery.dataTables.min.js

DEP_MIN_JS=deps.min.js
DEP_MIN_JS_SRC=ie_fix.js rickshaw.js pie-chart.js gauge.js \
		  crossfilter.js validator.js validator.js \
		  dc.js cal-heatmap.js nv.d3.js jquery.are-you-sure.js \
		  moment.js ASAP.js binary-indicators.js

NTOP_MIN_JS=ntop.min.js
NTOP_MIN_JS_SRC=utils/are-you-sure-utils.js utils/string-utils.js utils/ntop-utils.js utils/graph-utils.js \
		  utils/ebpf-utils.js utils/ntopng-validators-utils.js \
		  utils/modal-utils.js utils/bootstrap-datatable-utils.js utils/sprymedia-datatable-utils.js utils/toast-utils.js

minify: $(JQUERY_BOOTSTRAP_MIN_JS) $(DEP_MIN_JS) $(NTOP_MIN_JS)

UGLIFY_OPTIONS_V2=--source-map $@.map
UGLIFY_OPTIONS_V3=--source-map url=$@.map

ifeq ($(UGLIFY_VERSION),3)
  UGLIFY_OPTIONS=$(UGLIFY_OPTIONS_V3)
else
  UGLIFY_OPTIONS=$(UGLIFY_OPTIONS_V2)
endif

$(JQUERY_BOOTSTRAP_MIN_JS): $(JQUERY_BOOTSTRAP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ $(UGLIFY_OPTIONS) -- $(JQUERY_BOOTSTRAP_MIN_JS_SRC)

$(DEP_MIN_JS): $(DEP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ $(UGLIFY_OPTIONS) -- $(DEP_MIN_JS_SRC)

$(NTOP_MIN_JS): $(NTOP_MIN_JS_SRC) Makefile
	uglifyjs -o $@ $(UGLIFY_OPTIONS) -- $(NTOP_MIN_JS_SRC)

clean:
	rm -f $(JQUERY_BOOTSTRAP_MIN_JS) $(DEP_MIN_JS) $(NTOP_MIN_JS) *.map
