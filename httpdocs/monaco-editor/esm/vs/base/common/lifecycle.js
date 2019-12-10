/**
 * Enables logging of potentially leaked disposables.
 *
 * A disposable is considered leaked if it is not disposed or not registered as the child of
 * another disposable. This tracking is very simple an only works for classes that either
 * extend Disposable or use a DisposableStore. This means there are a lot of false positives.
 */
var TRACK_DISPOSABLES = false;
var __is_disposable_tracked__ = '__is_disposable_tracked__';
function markTracked(x) {
    if (!TRACK_DISPOSABLES) {
        return;
    }
    if (x && x !== Disposable.None) {
        try {
            x[__is_disposable_tracked__] = true;
        }
        catch (_a) {
            // noop
        }
    }
}
function trackDisposable(x) {
    if (!TRACK_DISPOSABLES) {
        return x;
    }
    var stack = new Error('Potentially leaked disposable').stack;
    setTimeout(function () {
        if (!x[__is_disposable_tracked__]) {
            console.log(stack);
        }
    }, 3000);
    return x;
}
export function isDisposable(thing) {
    return typeof thing.dispose === 'function'
        && thing.dispose.length === 0;
}
export function dispose(disposables) {
    if (Array.isArray(disposables)) {
        disposables.forEach(function (d) {
            if (d) {
                markTracked(d);
                d.dispose();
            }
        });
        return [];
    }
    else if (disposables) {
        markTracked(disposables);
        disposables.dispose();
        return disposables;
    }
    else {
        return undefined;
    }
}
export function combinedDisposable() {
    var disposables = [];
    for (var _i = 0; _i < arguments.length; _i++) {
        disposables[_i] = arguments[_i];
    }
    disposables.forEach(markTracked);
    return trackDisposable({ dispose: function () { return dispose(disposables); } });
}
export function toDisposable(fn) {
    var self = trackDisposable({
        dispose: function () {
            markTracked(self);
            fn();
        }
    });
    return self;
}
var DisposableStore = /** @class */ (function () {
    function DisposableStore() {
        this._toDispose = new Set();
        this._isDisposed = false;
    }
    /**
     * Dispose of all registered disposables and mark this object as disposed.
     *
     * Any future disposables added to this object will be disposed of on `add`.
     */
    DisposableStore.prototype.dispose = function () {
        if (this._isDisposed) {
            return;
        }
        markTracked(this);
        this._isDisposed = true;
        this.clear();
    };
    /**
     * Dispose of all registered disposables but do not mark this object as disposed.
     */
    DisposableStore.prototype.clear = function () {
        this._toDispose.forEach(function (item) { return item.dispose(); });
        this._toDispose.clear();
    };
    DisposableStore.prototype.add = function (t) {
        if (!t) {
            return t;
        }
        if (t === this) {
            throw new Error('Cannot register a disposable on itself!');
        }
        markTracked(t);
        if (this._isDisposed) {
            console.warn(new Error('Trying to add a disposable to a DisposableStore that has already been disposed of. The added object will be leaked!').stack);
        }
        else {
            this._toDispose.add(t);
        }
        return t;
    };
    return DisposableStore;
}());
export { DisposableStore };
var Disposable = /** @class */ (function () {
    function Disposable() {
        this._store = new DisposableStore();
        trackDisposable(this);
    }
    Disposable.prototype.dispose = function () {
        markTracked(this);
        this._store.dispose();
    };
    Disposable.prototype._register = function (t) {
        if (t === this) {
            throw new Error('Cannot register a disposable on itself!');
        }
        return this._store.add(t);
    };
    Disposable.None = Object.freeze({ dispose: function () { } });
    return Disposable;
}());
export { Disposable };
/**
 * Manages the lifecycle of a disposable value that may be changed.
 *
 * This ensures that when the the disposable value is changed, the previously held disposable is disposed of. You can
 * also register a `MutableDisposable` on a `Disposable` to ensure it is automatically cleaned up.
 */
var MutableDisposable = /** @class */ (function () {
    function MutableDisposable() {
        this._isDisposed = false;
        trackDisposable(this);
    }
    Object.defineProperty(MutableDisposable.prototype, "value", {
        get: function () {
            return this._isDisposed ? undefined : this._value;
        },
        set: function (value) {
            if (this._isDisposed || value === this._value) {
                return;
            }
            if (this._value) {
                this._value.dispose();
            }
            if (value) {
                markTracked(value);
            }
            this._value = value;
        },
        enumerable: true,
        configurable: true
    });
    MutableDisposable.prototype.clear = function () {
        this.value = undefined;
    };
    MutableDisposable.prototype.dispose = function () {
        this._isDisposed = true;
        markTracked(this);
        if (this._value) {
            this._value.dispose();
        }
        this._value = undefined;
    };
    return MutableDisposable;
}());
export { MutableDisposable };
var ImmortalReference = /** @class */ (function () {
    function ImmortalReference(object) {
        this.object = object;
    }
    ImmortalReference.prototype.dispose = function () { };
    return ImmortalReference;
}());
export { ImmortalReference };
