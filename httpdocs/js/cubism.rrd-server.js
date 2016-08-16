/* Adapted from https://github.com/cliffeh/cubism-rrdserver */

cubism.rrdserver = function(context) {
  var source = {};

  var getMetric = function(rrd, name, showbg, cf) {
    cf = cf || 'AVERAGE';

    var metric = context.metric(function(start, stop, step, callback) {
      // make sure we're working with ints (and seconds)
      start = +start/1000, stop = +stop/1000, step = +step/1000;

      d3.json(rrd
	      + '&cf=' + cf
	      + '&start=' + start
	      + '&stop=' + stop
	      + '&step=' + step,
		function(data) {
      var datastep = data['step'] * 1000;
      var up = data['up'];
      var down = data['down'];
      var bg = data['bg'];
      var datasize = bg.length;

      var k = Math.ceil(step / datastep);
      var res = [];
      var val = 0;
      var i;

      // aggregate data
      for (i=0; i<datasize; i++) {
        val = val + showbg ? bg[i] : up[i] - down[i];

        if (i % k == k-1) {
          res.push(val);
          val = 0;
        }
      }
      
      callback(null, res);
		});
    }, name);
    return metric;
  }
  
  source.metric = function(rrd, name, cf) {
    return getMetric(rrd, name, cf);
  }

  source.toString = function() {
    return "cubism.rrd-server";
  };
  
  return source;
}
