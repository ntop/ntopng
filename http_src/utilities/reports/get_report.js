/* This page is not currently used */

var page = new WebPage(), idx = 0, loadInProgress = false;
var system = require('system');

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onLoadStarted = function() {
  loadInProgress = true;
};

page.onLoadFinished = function() {
  loadInProgress = false;
};

page.onError = function(msg, trace) {
};

var args = system.args;
if (args.length < 6) {
  console.log("USAGE: phantomjs get_report.js <port> <output_pdf> <username> <password> <num_hours>")
  phantom.exit(1);
}
var port = args[1];
var output = args[2];
var user = args[3];
var password = args[4];
var num_hours = args[5];
var address = "http://localhost:"+port+"/lua/login.lua";

var steps = [
  function(address, output) {
    page.open(address);
  },
  function(address, output, user, password, num_hours) {
    page.evaluate(function(user, password, num_hours) {
      var arr = document.getElementsByClassName("form-control");
      var i;

      for (i = 0 ; i < arr.length ; i++) {
	console.log(arr[i].name);
        if (arr[i].name == "user") arr[i].value = user;
        if (arr[i].name == "password") arr[i].value = password;
	if (arr[i].name == "referer") arr[i].value = "/lua/pro/report.lua?numhours="+num_hours+"&printable=true";
        //if (arr[i].name == "referer") arr[i].value = "/lua/flows_stats.lua";
      }
    }, user, password, num_hours);
  },
  function() {
    page.evaluate(function() {
      var arr = document.getElementsByClassName("form-signin");
      var i;

      for (i = 0 ; i < arr.length ; i++) {
        if (arr[i].getAttribute('method') == "POST") {
          console.log(arr[i].action);
          arr[i].submit();
          return;
        }
      }

    });
  },
  function(address, output) {
    var size = { format: "A4", orientation: 'portrait', margin: '1cm' };
    page.viewportSize = { width: 1920, height: 1080 };
    //page.viewportSize = { width: 600, height: 600 };
    page.paperSize = size;
    page.render(output);
  },
  function() {
    phantom.exit();
  }
];


interval = setInterval(function() {
  if (!loadInProgress && typeof steps[idx] == "function") {
    steps[idx](address, output, user, password, num_hours);
    idx++;
  }
}, 1000);
