// Only if it's not already included
if (typeof ripestat != 'object') { 
    
    if (typeof STAT_WIDGET_API_URL != 'string'){
        // Allow external specification of API location
        var STAT_WIDGET_API_URL = 'https://stat.ripe.net/widgets/';
    }
    
    /* WIDGET API DEBUG FEATURE
     * 
     * To redirect the loaded RIPEstat widget API use:
     * 
     * .../?widget_api_domain=https://stat-dev.ripe.net/widgets/
     * 
     **/
    var STAT_WIDGET_DEBUG = false;
    var apiDomainParameterName = "widget_api_domain";
    var enableDebugParameterName = "widget_api_debug";
    var searchString = location.search;
    if ( searchString && searchString.length > 0 ) {
        searchString = searchString.substr(1); // removing the question mark
        var keyValuePairs = searchString.split("&");
        for ( var i = 0, n = keyValuePairs.length; i < n; i++) {
            var keyValuePair = keyValuePairs[i].split("=");
            if ( keyValuePair[0] === apiDomainParameterName ) {
                STAT_WIDGET_API_URL = decodeURIComponent( keyValuePair[1] ) + "/widgets/";
                console.log("STAT_WIDGET_API_URL: " + STAT_WIDGET_API_URL);
            }
            if ( keyValuePair[0] === enableDebugParameterName && 
                 keyValuePair[1] === "true") {
                STAT_WIDGET_DEBUG = true;
                console.log("STAT_WIDGET_DEBUG enabled");
            }
        }
    }

    if (typeof STAT_DATA_API_URL != 'string') {
        // Allow external specification of API location
        var STAT_DATA_API_URL = 'https://stat.ripe.net/data/';
    }

    if (typeof STAT_OTHER_API_URL != 'string') {
        // non-data API location
        var STAT_OTHER_API_URL = 'https://stat.ripe.net/api/';
    }

    if (typeof STAT_HOME != 'string') {
        // base target for link
        var STAT_HOME = "https://stat.ripe.net/";
    }

    if (typeof STAT_DOM_CLASS_NAME != 'string') {
        // DOM class for auto linking to div element
        var STAT_DOM_CLASS_NAME = 'statwdgtauto';
    }

    if (typeof STAT_REQUIRE_TIMEOUT != 'number') {
        // how many seconds to wait for scripts to load
        // 0 ... disables the timeout
        var STAT_REQUIRE_TIMEOUT = 120;
    }
    
    document.write('<script src="' + STAT_HOME + 'widget-api-config' +
        '?nocache=' + Math.random() + '"></script>');
	
    document.write('<script src="' + STAT_WIDGET_API_URL + 'js/version.js' +
        '?nocache=' + Math.random() + '"></script>');
    
    document.write('<script src="' + STAT_WIDGET_API_URL + 'js/widget_api_main.js' + 
        '?nocache=' + Math.random() + '"></script>');
    
}

