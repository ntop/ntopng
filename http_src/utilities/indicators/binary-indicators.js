/* Adapted from https://github.com/binary-com/binary-indicators */
'use strict';

function intoSequence(n) {
    if((Array.prototype.from) && (Array.prototype.keys)) {
        // Not compatible with IE9
        return Array.from(Array(n).keys());
    } else {
        var arr = Array(n);

        for(i=0; i<n; i++)
            arr[i] = i;

        return(arr);
    }
}

var _math = {};

_math.takeField = function takeField(arr, field) {
    return arr.map(function (x) {
        return field ? x[field] : x;
    });
};

_math.takeLast = function takeLast(arr, n, field) {
    return _math.takeField(arr.slice(n > arr.length ? 0 : arr.length - n, arr.length), field);
};

_math.sum = function sum(data) {
    return data.reduce(function (acc, x) {
        return acc + x;
    });
};

_math.weightingMultiplier = function weightingMultiplier(periods) {
    return 2 / (periods + 1);
};

_math.mean = function mean(data) {
    return data.reduce(function (a, b) {
        return a + b;
    }) / data.length;
};

_math.stddev = function stddev(data) {
    var dataMean = _math.mean(data);
    var sqDiff = data.map(function (n) {
        return Math.pow(n - dataMean, 2);
    });
    var avgSqDiff = _math.mean(sqDiff);
    return Math.sqrt(avgSqDiff);
};

function bollingerBands(data, config) {
    var _config$periods = config.periods,
        periods = _config$periods === undefined ? 20 : _config$periods,
        field = config.field,
        _config$stdDevUp = config.stdDevUp,
        stdDevUp = _config$stdDevUp === undefined ? 2 : _config$stdDevUp,
        _config$stdDevDown = config.stdDevDown,
        stdDevDown = _config$stdDevDown === undefined ? 2 : _config$stdDevDown,
        _config$pipSize = config.pipSize,
        pipSize = _config$pipSize === undefined ? 2 : _config$pipSize;

    var vals = (0, _math.takeLast)(data, periods, field);
    var middle = (0, simpleMovingAverage)(vals, { periods: periods });
    var stdDev = (0, _math.stddev)(vals);
    var upper = middle + stdDev * stdDevUp;
    var lower = middle - stdDev * stdDevDown;

    return [+middle.toFixed(pipSize), +upper.toFixed(pipSize), +lower.toFixed(pipSize)];
};

function bollingerBandsArray(data, config) {
    var periods = config.periods;

    return (0, intoSequence)(data.length - periods + 1).map(function (x, i) {
        return bollingerBands(data.slice(i, i + periods), config);
    });
};

function ema(vals, periods) {
    if (vals.length === 1) {
        return vals[0];
    }

    var prev = ema(vals.slice(0, vals.length - 1), periods);

    return (vals.slice(-1)[0] - prev) * (0, _math.weightingMultiplier)(periods) + prev;
};

function exponentialMovingAverage(data, config) {
    var periods = config.periods,
        field = config.field;


    if (data.length < periods) {
        throw new Error('Periods longer than data length');
    }

    var vals = (0, _math.takeLast)(data, periods, field);

    return ema(vals, periods);
};

function exponentialMovingAverageArray(data, config) {
    var periods = config.periods,
        _config$pipSize = config.pipSize,
        pipSize = _config$pipSize === undefined ? 2 : _config$pipSize;

    return (0, intoSequence)(data.length - periods + 1).map(function (x, i) {
        return +exponentialMovingAverage(data.slice(i, i + periods), config).toFixed(pipSize);
    });
};

function calcGain(q1, q2) {
    return q2 > q1 ? q2 - q1 : 0;
};
function calcLoss(q1, q2) {
    return q2 < q1 ? q1 - q2 : 0;
};

function calcFirstAvgDiff(vals, comp, periods) {
    var prev = void 0;
    return vals.reduce(function (r, q, i) {
        if (i === 1) {
            prev = r;
        }
        var diff = comp(prev, q);
        prev = q;
        return diff + (i === 1 ? 0 : r);
    }) / periods;
};

function calcSecondAvgDiff(vals, comp, periods, initAvg) {
    var prev = void 0;
    if (vals.length === 1) {
        // There is no data to calc avg
        return initAvg;
    }
    return vals.reduce(function (r, q, i) {
        if (i === 1) {
            prev = r;
        }
        var diff = comp(prev, q);
        prev = q;
        var prevAvg = i === 1 ? initAvg : r;
        return (prevAvg * (periods - 1) + diff) / periods;
    });
};

function relativeStrengthIndex(data, config) {
    var memoizedDiff = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : null;
    var periods = config.periods,
        field = config.field;


    if (data.length < periods) {
        throw new Error('Periods longer than data length');
    }

    if (data.length === periods) {
        return 0;
    }

    var vals = (0, _math.takeField)(data.slice(0, periods + 1), field);

    var restSeq = void 0;
    var initAvgGain = void 0;
    var initAvgLoss = void 0;

    if (memoizedDiff && 'gain' in memoizedDiff) {
        restSeq = (0, _math.takeField)(data.slice(-2), field);

        initAvgGain = memoizedDiff.gain;
        initAvgLoss = memoizedDiff.loss;
    } else {
        // include last element from above to calc diff
        restSeq = (0, _math.takeField)(data.slice(periods, data.length), field);

        initAvgGain = calcFirstAvgDiff(vals, calcGain, periods);
        initAvgLoss = calcFirstAvgDiff(vals, calcLoss, periods);
    }

    var avgGain = calcSecondAvgDiff(restSeq, calcGain, periods, initAvgGain);
    var avgLoss = calcSecondAvgDiff(restSeq, calcLoss, periods, initAvgLoss);

    if (memoizedDiff) {
        memoizedDiff.gain = avgGain;
        memoizedDiff.loss = avgLoss;
    }

    // FIX: avgGain == 0 and avgLoss == 0 -> RSI = 50
/*
    if (avgGain === 0) {
        return 0;
    } else if (avgLoss === 0) {
        return 100;
    }
*/
    var RS = (avgGain+1) / (avgLoss+1);

    return 100 - 100 / (1 + RS);
};

function relativeStrengthIndexArray(data, config) {
    var periods = config.periods,
        _config$pipSize = config.pipSize,
        pipSize = _config$pipSize === undefined ? 2 : _config$pipSize;

    var memoizedDiff = {};
    return (0, intoSequence)(data.length - periods).map(function (x, i) {
        return +relativeStrengthIndex(data.slice(0, i + periods + 1), config, memoizedDiff).toFixed(pipSize);
    });
};

function simpleMovingAverage(data, config) {
    var periods = config.periods,
        field = config.field;


    if (data.length < periods) {
        throw new Error('Periods longer than data length');
    }

    var vals = (0, _math.takeLast)(data, periods, field);

    return (0, _math.sum)(vals) / periods;
};

function simpleMovingAverageArray(data, config) {
    var periods = config.periods,
        _config$pipSize = config.pipSize,
        pipSize = _config$pipSize === undefined ? 2 : _config$pipSize;

    return (0, intoSequence)(data.length - periods + 1).map(function (x, i) {
        return +simpleMovingAverage(data.slice(i, i + periods), config).toFixed(pipSize);
    });
};
