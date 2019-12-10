/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { CancellationTokenSource } from './cancellation.js';
import * as errors from './errors.js';
import { toDisposable } from './lifecycle.js';
export function isThenable(obj) {
    return obj && typeof obj.then === 'function';
}
export function createCancelablePromise(callback) {
    var source = new CancellationTokenSource();
    var thenable = callback(source.token);
    var promise = new Promise(function (resolve, reject) {
        source.token.onCancellationRequested(function () {
            reject(errors.canceled());
        });
        Promise.resolve(thenable).then(function (value) {
            source.dispose();
            resolve(value);
        }, function (err) {
            source.dispose();
            reject(err);
        });
    });
    return new /** @class */ (function () {
        function class_1() {
        }
        class_1.prototype.cancel = function () {
            source.cancel();
        };
        class_1.prototype.then = function (resolve, reject) {
            return promise.then(resolve, reject);
        };
        class_1.prototype.catch = function (reject) {
            return this.then(undefined, reject);
        };
        class_1.prototype.finally = function (onfinally) {
            return promise.finally(onfinally);
        };
        return class_1;
    }());
}
export function raceCancellation(promise, token, defaultValue) {
    return Promise.race([promise, new Promise(function (resolve) { return token.onCancellationRequested(function () { return resolve(defaultValue); }); })]);
}
/**
 * A helper to delay execution of a task that is being requested often.
 *
 * Following the throttler, now imagine the mail man wants to optimize the number of
 * trips proactively. The trip itself can be long, so he decides not to make the trip
 * as soon as a letter is submitted. Instead he waits a while, in case more
 * letters are submitted. After said waiting period, if no letters were submitted, he
 * decides to make the trip. Imagine that N more letters were submitted after the first
 * one, all within a short period of time between each other. Even though N+1
 * submissions occurred, only 1 delivery was made.
 *
 * The delayer offers this behavior via the trigger() method, into which both the task
 * to be executed and the waiting period (delay) must be passed in as arguments. Following
 * the example:
 *
 * 		const delayer = new Delayer(WAITING_PERIOD);
 * 		const letters = [];
 *
 * 		function letterReceived(l) {
 * 			letters.push(l);
 * 			delayer.trigger(() => { return makeTheTrip(); });
 * 		}
 */
var Delayer = /** @class */ (function () {
    function Delayer(defaultDelay) {
        this.defaultDelay = defaultDelay;
        this.timeout = null;
        this.completionPromise = null;
        this.doResolve = null;
        this.task = null;
    }
    Delayer.prototype.trigger = function (task, delay) {
        var _this = this;
        if (delay === void 0) { delay = this.defaultDelay; }
        this.task = task;
        this.cancelTimeout();
        if (!this.completionPromise) {
            this.completionPromise = new Promise(function (c, e) {
                _this.doResolve = c;
                _this.doReject = e;
            }).then(function () {
                _this.completionPromise = null;
                _this.doResolve = null;
                var task = _this.task;
                _this.task = null;
                return task();
            });
        }
        this.timeout = setTimeout(function () {
            _this.timeout = null;
            _this.doResolve(null);
        }, delay);
        return this.completionPromise;
    };
    Delayer.prototype.isTriggered = function () {
        return this.timeout !== null;
    };
    Delayer.prototype.cancel = function () {
        this.cancelTimeout();
        if (this.completionPromise) {
            this.doReject(errors.canceled());
            this.completionPromise = null;
        }
    };
    Delayer.prototype.cancelTimeout = function () {
        if (this.timeout !== null) {
            clearTimeout(this.timeout);
            this.timeout = null;
        }
    };
    Delayer.prototype.dispose = function () {
        this.cancelTimeout();
    };
    return Delayer;
}());
export { Delayer };
export function timeout(millis, token) {
    if (!token) {
        return createCancelablePromise(function (token) { return timeout(millis, token); });
    }
    return new Promise(function (resolve, reject) {
        var handle = setTimeout(resolve, millis);
        token.onCancellationRequested(function () {
            clearTimeout(handle);
            reject(errors.canceled());
        });
    });
}
export function disposableTimeout(handler, timeout) {
    if (timeout === void 0) { timeout = 0; }
    var timer = setTimeout(handler, timeout);
    return toDisposable(function () { return clearTimeout(timer); });
}
export function first(promiseFactories, shouldStop, defaultValue) {
    if (shouldStop === void 0) { shouldStop = function (t) { return !!t; }; }
    if (defaultValue === void 0) { defaultValue = null; }
    var index = 0;
    var len = promiseFactories.length;
    var loop = function () {
        if (index >= len) {
            return Promise.resolve(defaultValue);
        }
        var factory = promiseFactories[index++];
        var promise = Promise.resolve(factory());
        return promise.then(function (result) {
            if (shouldStop(result)) {
                return Promise.resolve(result);
            }
            return loop();
        });
    };
    return loop();
}
var TimeoutTimer = /** @class */ (function () {
    function TimeoutTimer(runner, timeout) {
        this._token = -1;
        if (typeof runner === 'function' && typeof timeout === 'number') {
            this.setIfNotSet(runner, timeout);
        }
    }
    TimeoutTimer.prototype.dispose = function () {
        this.cancel();
    };
    TimeoutTimer.prototype.cancel = function () {
        if (this._token !== -1) {
            clearTimeout(this._token);
            this._token = -1;
        }
    };
    TimeoutTimer.prototype.cancelAndSet = function (runner, timeout) {
        var _this = this;
        this.cancel();
        this._token = setTimeout(function () {
            _this._token = -1;
            runner();
        }, timeout);
    };
    TimeoutTimer.prototype.setIfNotSet = function (runner, timeout) {
        var _this = this;
        if (this._token !== -1) {
            // timer is already set
            return;
        }
        this._token = setTimeout(function () {
            _this._token = -1;
            runner();
        }, timeout);
    };
    return TimeoutTimer;
}());
export { TimeoutTimer };
var IntervalTimer = /** @class */ (function () {
    function IntervalTimer() {
        this._token = -1;
    }
    IntervalTimer.prototype.dispose = function () {
        this.cancel();
    };
    IntervalTimer.prototype.cancel = function () {
        if (this._token !== -1) {
            clearInterval(this._token);
            this._token = -1;
        }
    };
    IntervalTimer.prototype.cancelAndSet = function (runner, interval) {
        this.cancel();
        this._token = setInterval(function () {
            runner();
        }, interval);
    };
    return IntervalTimer;
}());
export { IntervalTimer };
var RunOnceScheduler = /** @class */ (function () {
    function RunOnceScheduler(runner, timeout) {
        this.timeoutToken = -1;
        this.runner = runner;
        this.timeout = timeout;
        this.timeoutHandler = this.onTimeout.bind(this);
    }
    /**
     * Dispose RunOnceScheduler
     */
    RunOnceScheduler.prototype.dispose = function () {
        this.cancel();
        this.runner = null;
    };
    /**
     * Cancel current scheduled runner (if any).
     */
    RunOnceScheduler.prototype.cancel = function () {
        if (this.isScheduled()) {
            clearTimeout(this.timeoutToken);
            this.timeoutToken = -1;
        }
    };
    /**
     * Cancel previous runner (if any) & schedule a new runner.
     */
    RunOnceScheduler.prototype.schedule = function (delay) {
        if (delay === void 0) { delay = this.timeout; }
        this.cancel();
        this.timeoutToken = setTimeout(this.timeoutHandler, delay);
    };
    /**
     * Returns true if scheduled.
     */
    RunOnceScheduler.prototype.isScheduled = function () {
        return this.timeoutToken !== -1;
    };
    RunOnceScheduler.prototype.onTimeout = function () {
        this.timeoutToken = -1;
        if (this.runner) {
            this.doRun();
        }
    };
    RunOnceScheduler.prototype.doRun = function () {
        if (this.runner) {
            this.runner();
        }
    };
    return RunOnceScheduler;
}());
export { RunOnceScheduler };
/**
 * Execute the callback the next time the browser is idle
 */
export var runWhenIdle;
(function () {
    if (typeof requestIdleCallback !== 'function' || typeof cancelIdleCallback !== 'function') {
        var dummyIdle_1 = Object.freeze({
            didTimeout: true,
            timeRemaining: function () { return 15; }
        });
        runWhenIdle = function (runner) {
            var handle = setTimeout(function () { return runner(dummyIdle_1); });
            var disposed = false;
            return {
                dispose: function () {
                    if (disposed) {
                        return;
                    }
                    disposed = true;
                    clearTimeout(handle);
                }
            };
        };
    }
    else {
        runWhenIdle = function (runner, timeout) {
            var handle = requestIdleCallback(runner, typeof timeout === 'number' ? { timeout: timeout } : undefined);
            var disposed = false;
            return {
                dispose: function () {
                    if (disposed) {
                        return;
                    }
                    disposed = true;
                    cancelIdleCallback(handle);
                }
            };
        };
    }
})();
/**
 * An implementation of the "idle-until-urgent"-strategy as introduced
 * here: https://philipwalton.com/articles/idle-until-urgent/
 */
var IdleValue = /** @class */ (function () {
    function IdleValue(executor) {
        var _this = this;
        this._didRun = false;
        this._executor = function () {
            try {
                _this._value = executor();
            }
            catch (err) {
                _this._error = err;
            }
            finally {
                _this._didRun = true;
            }
        };
        this._handle = runWhenIdle(function () { return _this._executor(); });
    }
    IdleValue.prototype.dispose = function () {
        this._handle.dispose();
    };
    IdleValue.prototype.getValue = function () {
        if (!this._didRun) {
            this._handle.dispose();
            this._executor();
        }
        if (this._error) {
            throw this._error;
        }
        return this._value;
    };
    return IdleValue;
}());
export { IdleValue };
