// Only if it's not already included
if (typeof ripestat != 'object') {
    var STAT_WIDGET_API_URL = 'https://stat.ripe.net/widgets/';
    var STAT_DATA_API_URL = 'https://stat.ripe.net/data/';
    var STAT_OTHER_API_URL = 'https://stat.ripe.net/api/';
    var STAT_HOME = "https://stat.ripe.net/";
    // DOM class for auto linking to div element
    var STAT_DOM_CLASS_NAME = 'statwdgtauto';
    // how many seconds to wait for scripts to load
    // 0 ... disables the timeout
    var STAT_REQUIRE_TIMEOUT = 120;

    document.write('<script src="' + STAT_HOME + 'widget-api-config' +
        '?nocache=' + Math.random() + '"></script>');
	
    document.write('<script src="' + STAT_WIDGET_API_URL + 'js/version.js' +
        '?nocache=' + Math.random() + '"></script>');
    
    document.write('<script src="' + STAT_WIDGET_API_URL + 'js/widget_api_main.js' + 
        '?nocache=' + Math.random() + '"></script>');
}
