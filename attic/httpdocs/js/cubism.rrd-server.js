/*
 * This file provides cubism.js data. Two modes are available:
 *  - RRD: get data from RRD.
 *  - LIVE: get data live counters.
 * 
 */


cubism.rrdserver = function(context, resolution) {
  /*
   * live window keeps previous values of each live counter to work with cubism.js queries.
   * This should be as near to resolution as possible.
   * High values decrese performance but also increase data retention across mode change.
   */
  var LIVE_WINDOW_SIZE = Math.floor(resolution * 0.7);

  function getRelevantValue(up, down, bg, showbg) {
    if (showbg)
      return bg;
    return up >= down ? -up : down;
  }
  
  var LiveCounter = function (step, isbg) {
    this.reset = function(step, isbg) {
      this.up = 0;
      this.down = 0;
      this.bg = 0;
      this.lastpoll = -1;
      this.step = step;
      this.live_window = new Array(LIVE_WINDOW_SIZE).fill(0);
      this.isbg = isbg;
    }

    this.isValidTime = function(stop) {
      return this.lastpoll==-1 ? true : (stop - this.lastpoll >= this.step);
    }

    this.update = function(stop, up, down, bg) {
      if (this.lastpoll != -1) {
        // adjust the window
        this.scrollWindow(stop);
        this.live_window[LIVE_WINDOW_SIZE-1] = getRelevantValue(up-this.up, down-this.down, bg-this.bg, this.isbg)
      }

      this.up = up;
      this.down = down;
      this.bg = bg;
      this.lastpoll = stop;
    }

    this.scrollWindow = function(stop) {
      var scroll = (stop - this.lastpoll) / this.step;
      var i;
      
      for (i=0; i+scroll<LIVE_WINDOW_SIZE; i++)
        this.live_window[i] = this.live_window[i+scroll];
      for (; i<LIVE_WINDOW_SIZE; i++)
        this.live_window[i] = 0;

      this.lastpoll = stop;
    }

    this.getAt = function(i) {
      return this.live_window[i];
    }

    this.reset(step, isbg);
  }

  /* active and background counters */
  var live_counters = [{},{}];
  var live_window = [];
  var live_step = -1;
  
  var source = {};

  var getMetric = function(rrd, name, showbg, cf) {
    cf = cf || 'AVERAGE';

    var metric = context.metric(function(start, stop, step, callback) {
      // make sure we're working with ints (and seconds)
      start = +start/1000, stop = +stop/1000, step = +step/1000;

      d3.json(rrd
	      + '&cf=' + cf
	      + '&epoch_begin=' + start
	      + '&epoch_end=' + stop
	      + '&step=' + step,
		function(data) {
      var datasize = (data && data.bg) ? data.bg.length : 0;
      if (datasize == 0)
        return;
      
      var datastep = data['step'] * 1000;
      var up = data['up'];
      var down = data['down'];
      var bg = data['bg'];
      var livemode = data['live'];
      var res = [];

      if (livemode) {
        if (live_step != step) {
          live_step = step;

          for (var i=0; i<2; i++)
            for (var k in live_counters[i])
              live_counters[i][k].reset(live_step, i===1);
        }        

        for (var i=0; i<2; i++) {
          if (! live_counters[i].hasOwnProperty(name))
            live_counters[i][name] = new LiveCounter(live_step, i===1);

          if (live_counters[i][name].isValidTime(stop))
            live_counters[i][name].update(stop, up[0], down[0], bg[0]);
        }

        var counter = live_counters[showbg ? 1 : 0][name];

        // fill the gaps with saved values or zeroes
        var points = (stop - start) / step;
        for (var i=0; i<points; i++) {
          var j = LIVE_WINDOW_SIZE - points + i;
          if (j >= 0)
            res.push(counter.getAt(j));
          else
            res.push(0);
        }
      } else {
        for (var i=0; i<datasize; i++)
          res.push(getRelevantValue(up[i], down[i], bg[i], showbg));
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
