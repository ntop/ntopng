/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __extends = (this && this.__extends) || (function () {
    var extendStatics = function (d, b) {
        extendStatics = Object.setPrototypeOf ||
            ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
            function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
        return extendStatics(d, b);
    };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
import { isFalsyOrWhitespace } from '../../../base/common/strings.js';
import { createDecorator } from '../../instantiation/common/instantiation.js';
var ContextKeyExpr = /** @class */ (function () {
    function ContextKeyExpr() {
    }
    ContextKeyExpr.has = function (key) {
        return ContextKeyDefinedExpr.create(key);
    };
    ContextKeyExpr.equals = function (key, value) {
        return ContextKeyEqualsExpr.create(key, value);
    };
    ContextKeyExpr.regex = function (key, value) {
        return ContextKeyRegexExpr.create(key, value);
    };
    ContextKeyExpr.not = function (key) {
        return ContextKeyNotExpr.create(key);
    };
    ContextKeyExpr.and = function () {
        var expr = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            expr[_i] = arguments[_i];
        }
        return ContextKeyAndExpr.create(expr);
    };
    ContextKeyExpr.or = function () {
        var expr = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            expr[_i] = arguments[_i];
        }
        return ContextKeyOrExpr.create(expr);
    };
    ContextKeyExpr.deserialize = function (serialized, strict) {
        if (strict === void 0) { strict = false; }
        if (!serialized) {
            return undefined;
        }
        return this._deserializeOrExpression(serialized, strict);
    };
    ContextKeyExpr._deserializeOrExpression = function (serialized, strict) {
        var _this = this;
        var pieces = serialized.split('||');
        return ContextKeyOrExpr.create(pieces.map(function (p) { return _this._deserializeAndExpression(p, strict); }));
    };
    ContextKeyExpr._deserializeAndExpression = function (serialized, strict) {
        var _this = this;
        var pieces = serialized.split('&&');
        return ContextKeyAndExpr.create(pieces.map(function (p) { return _this._deserializeOne(p, strict); }));
    };
    ContextKeyExpr._deserializeOne = function (serializedOne, strict) {
        serializedOne = serializedOne.trim();
        if (serializedOne.indexOf('!=') >= 0) {
            var pieces = serializedOne.split('!=');
            return ContextKeyNotEqualsExpr.create(pieces[0].trim(), this._deserializeValue(pieces[1], strict));
        }
        if (serializedOne.indexOf('==') >= 0) {
            var pieces = serializedOne.split('==');
            return ContextKeyEqualsExpr.create(pieces[0].trim(), this._deserializeValue(pieces[1], strict));
        }
        if (serializedOne.indexOf('=~') >= 0) {
            var pieces = serializedOne.split('=~');
            return ContextKeyRegexExpr.create(pieces[0].trim(), this._deserializeRegexValue(pieces[1], strict));
        }
        if (/^\!\s*/.test(serializedOne)) {
            return ContextKeyNotExpr.create(serializedOne.substr(1).trim());
        }
        return ContextKeyDefinedExpr.create(serializedOne);
    };
    ContextKeyExpr._deserializeValue = function (serializedValue, strict) {
        serializedValue = serializedValue.trim();
        if (serializedValue === 'true') {
            return true;
        }
        if (serializedValue === 'false') {
            return false;
        }
        var m = /^'([^']*)'$/.exec(serializedValue);
        if (m) {
            return m[1].trim();
        }
        return serializedValue;
    };
    ContextKeyExpr._deserializeRegexValue = function (serializedValue, strict) {
        if (isFalsyOrWhitespace(serializedValue)) {
            if (strict) {
                throw new Error('missing regexp-value for =~-expression');
            }
            else {
                console.warn('missing regexp-value for =~-expression');
            }
            return null;
        }
        var start = serializedValue.indexOf('/');
        var end = serializedValue.lastIndexOf('/');
        if (start === end || start < 0 /* || to < 0 */) {
            if (strict) {
                throw new Error("bad regexp-value '" + serializedValue + "', missing /-enclosure");
            }
            else {
                console.warn("bad regexp-value '" + serializedValue + "', missing /-enclosure");
            }
            return null;
        }
        var value = serializedValue.slice(start + 1, end);
        var caseIgnoreFlag = serializedValue[end + 1] === 'i' ? 'i' : '';
        try {
            return new RegExp(value, caseIgnoreFlag);
        }
        catch (e) {
            if (strict) {
                throw new Error("bad regexp-value '" + serializedValue + "', parse error: " + e);
            }
            else {
                console.warn("bad regexp-value '" + serializedValue + "', parse error: " + e);
            }
            return null;
        }
    };
    return ContextKeyExpr;
}());
export { ContextKeyExpr };
function cmp(a, b) {
    var aType = a.getType();
    var bType = b.getType();
    if (aType !== bType) {
        return aType - bType;
    }
    switch (aType) {
        case 1 /* Defined */:
            return a.cmp(b);
        case 2 /* Not */:
            return a.cmp(b);
        case 3 /* Equals */:
            return a.cmp(b);
        case 4 /* NotEquals */:
            return a.cmp(b);
        case 6 /* Regex */:
            return a.cmp(b);
        case 7 /* NotRegex */:
            return a.cmp(b);
        case 5 /* And */:
            return a.cmp(b);
        default:
            throw new Error('Unknown ContextKeyExpr!');
    }
}
var ContextKeyDefinedExpr = /** @class */ (function () {
    function ContextKeyDefinedExpr(key) {
        this.key = key;
    }
    ContextKeyDefinedExpr.create = function (key) {
        return new ContextKeyDefinedExpr(key);
    };
    ContextKeyDefinedExpr.prototype.getType = function () {
        return 1 /* Defined */;
    };
    ContextKeyDefinedExpr.prototype.cmp = function (other) {
        if (this.key < other.key) {
            return -1;
        }
        if (this.key > other.key) {
            return 1;
        }
        return 0;
    };
    ContextKeyDefinedExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyDefinedExpr) {
            return (this.key === other.key);
        }
        return false;
    };
    ContextKeyDefinedExpr.prototype.evaluate = function (context) {
        return (!!context.getValue(this.key));
    };
    ContextKeyDefinedExpr.prototype.keys = function () {
        return [this.key];
    };
    ContextKeyDefinedExpr.prototype.negate = function () {
        return ContextKeyNotExpr.create(this.key);
    };
    return ContextKeyDefinedExpr;
}());
export { ContextKeyDefinedExpr };
var ContextKeyEqualsExpr = /** @class */ (function () {
    function ContextKeyEqualsExpr(key, value) {
        this.key = key;
        this.value = value;
    }
    ContextKeyEqualsExpr.create = function (key, value) {
        if (typeof value === 'boolean') {
            if (value) {
                return ContextKeyDefinedExpr.create(key);
            }
            return ContextKeyNotExpr.create(key);
        }
        return new ContextKeyEqualsExpr(key, value);
    };
    ContextKeyEqualsExpr.prototype.getType = function () {
        return 3 /* Equals */;
    };
    ContextKeyEqualsExpr.prototype.cmp = function (other) {
        if (this.key < other.key) {
            return -1;
        }
        if (this.key > other.key) {
            return 1;
        }
        if (this.value < other.value) {
            return -1;
        }
        if (this.value > other.value) {
            return 1;
        }
        return 0;
    };
    ContextKeyEqualsExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyEqualsExpr) {
            return (this.key === other.key && this.value === other.value);
        }
        return false;
    };
    ContextKeyEqualsExpr.prototype.evaluate = function (context) {
        /* tslint:disable:triple-equals */
        // Intentional ==
        return (context.getValue(this.key) == this.value);
        /* tslint:enable:triple-equals */
    };
    ContextKeyEqualsExpr.prototype.keys = function () {
        return [this.key];
    };
    ContextKeyEqualsExpr.prototype.negate = function () {
        return ContextKeyNotEqualsExpr.create(this.key, this.value);
    };
    return ContextKeyEqualsExpr;
}());
export { ContextKeyEqualsExpr };
var ContextKeyNotEqualsExpr = /** @class */ (function () {
    function ContextKeyNotEqualsExpr(key, value) {
        this.key = key;
        this.value = value;
    }
    ContextKeyNotEqualsExpr.create = function (key, value) {
        if (typeof value === 'boolean') {
            if (value) {
                return ContextKeyNotExpr.create(key);
            }
            return ContextKeyDefinedExpr.create(key);
        }
        return new ContextKeyNotEqualsExpr(key, value);
    };
    ContextKeyNotEqualsExpr.prototype.getType = function () {
        return 4 /* NotEquals */;
    };
    ContextKeyNotEqualsExpr.prototype.cmp = function (other) {
        if (this.key < other.key) {
            return -1;
        }
        if (this.key > other.key) {
            return 1;
        }
        if (this.value < other.value) {
            return -1;
        }
        if (this.value > other.value) {
            return 1;
        }
        return 0;
    };
    ContextKeyNotEqualsExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyNotEqualsExpr) {
            return (this.key === other.key && this.value === other.value);
        }
        return false;
    };
    ContextKeyNotEqualsExpr.prototype.evaluate = function (context) {
        /* tslint:disable:triple-equals */
        // Intentional !=
        return (context.getValue(this.key) != this.value);
        /* tslint:enable:triple-equals */
    };
    ContextKeyNotEqualsExpr.prototype.keys = function () {
        return [this.key];
    };
    ContextKeyNotEqualsExpr.prototype.negate = function () {
        return ContextKeyEqualsExpr.create(this.key, this.value);
    };
    return ContextKeyNotEqualsExpr;
}());
export { ContextKeyNotEqualsExpr };
var ContextKeyNotExpr = /** @class */ (function () {
    function ContextKeyNotExpr(key) {
        this.key = key;
    }
    ContextKeyNotExpr.create = function (key) {
        return new ContextKeyNotExpr(key);
    };
    ContextKeyNotExpr.prototype.getType = function () {
        return 2 /* Not */;
    };
    ContextKeyNotExpr.prototype.cmp = function (other) {
        if (this.key < other.key) {
            return -1;
        }
        if (this.key > other.key) {
            return 1;
        }
        return 0;
    };
    ContextKeyNotExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyNotExpr) {
            return (this.key === other.key);
        }
        return false;
    };
    ContextKeyNotExpr.prototype.evaluate = function (context) {
        return (!context.getValue(this.key));
    };
    ContextKeyNotExpr.prototype.keys = function () {
        return [this.key];
    };
    ContextKeyNotExpr.prototype.negate = function () {
        return ContextKeyDefinedExpr.create(this.key);
    };
    return ContextKeyNotExpr;
}());
export { ContextKeyNotExpr };
var ContextKeyRegexExpr = /** @class */ (function () {
    function ContextKeyRegexExpr(key, regexp) {
        this.key = key;
        this.regexp = regexp;
        //
    }
    ContextKeyRegexExpr.create = function (key, regexp) {
        return new ContextKeyRegexExpr(key, regexp);
    };
    ContextKeyRegexExpr.prototype.getType = function () {
        return 6 /* Regex */;
    };
    ContextKeyRegexExpr.prototype.cmp = function (other) {
        if (this.key < other.key) {
            return -1;
        }
        if (this.key > other.key) {
            return 1;
        }
        var thisSource = this.regexp ? this.regexp.source : '';
        var otherSource = other.regexp ? other.regexp.source : '';
        if (thisSource < otherSource) {
            return -1;
        }
        if (thisSource > otherSource) {
            return 1;
        }
        return 0;
    };
    ContextKeyRegexExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyRegexExpr) {
            var thisSource = this.regexp ? this.regexp.source : '';
            var otherSource = other.regexp ? other.regexp.source : '';
            return (this.key === other.key && thisSource === otherSource);
        }
        return false;
    };
    ContextKeyRegexExpr.prototype.evaluate = function (context) {
        var value = context.getValue(this.key);
        return this.regexp ? this.regexp.test(value) : false;
    };
    ContextKeyRegexExpr.prototype.keys = function () {
        return [this.key];
    };
    ContextKeyRegexExpr.prototype.negate = function () {
        return ContextKeyNotRegexExpr.create(this);
    };
    return ContextKeyRegexExpr;
}());
export { ContextKeyRegexExpr };
var ContextKeyNotRegexExpr = /** @class */ (function () {
    function ContextKeyNotRegexExpr(_actual) {
        this._actual = _actual;
        //
    }
    ContextKeyNotRegexExpr.create = function (actual) {
        return new ContextKeyNotRegexExpr(actual);
    };
    ContextKeyNotRegexExpr.prototype.getType = function () {
        return 7 /* NotRegex */;
    };
    ContextKeyNotRegexExpr.prototype.cmp = function (other) {
        return this._actual.cmp(other._actual);
    };
    ContextKeyNotRegexExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyNotRegexExpr) {
            return this._actual.equals(other._actual);
        }
        return false;
    };
    ContextKeyNotRegexExpr.prototype.evaluate = function (context) {
        return !this._actual.evaluate(context);
    };
    ContextKeyNotRegexExpr.prototype.keys = function () {
        return this._actual.keys();
    };
    ContextKeyNotRegexExpr.prototype.negate = function () {
        return this._actual;
    };
    return ContextKeyNotRegexExpr;
}());
export { ContextKeyNotRegexExpr };
var ContextKeyAndExpr = /** @class */ (function () {
    function ContextKeyAndExpr(expr) {
        this.expr = expr;
    }
    ContextKeyAndExpr.create = function (_expr) {
        var expr = ContextKeyAndExpr._normalizeArr(_expr);
        if (expr.length === 0) {
            return undefined;
        }
        if (expr.length === 1) {
            return expr[0];
        }
        return new ContextKeyAndExpr(expr);
    };
    ContextKeyAndExpr.prototype.getType = function () {
        return 5 /* And */;
    };
    ContextKeyAndExpr.prototype.cmp = function (other) {
        if (this.expr.length < other.expr.length) {
            return -1;
        }
        if (this.expr.length > other.expr.length) {
            return 1;
        }
        for (var i = 0, len = this.expr.length; i < len; i++) {
            var r = cmp(this.expr[i], other.expr[i]);
            if (r !== 0) {
                return r;
            }
        }
        return 0;
    };
    ContextKeyAndExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyAndExpr) {
            if (this.expr.length !== other.expr.length) {
                return false;
            }
            for (var i = 0, len = this.expr.length; i < len; i++) {
                if (!this.expr[i].equals(other.expr[i])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    };
    ContextKeyAndExpr.prototype.evaluate = function (context) {
        for (var i = 0, len = this.expr.length; i < len; i++) {
            if (!this.expr[i].evaluate(context)) {
                return false;
            }
        }
        return true;
    };
    ContextKeyAndExpr._normalizeArr = function (arr) {
        var expr = [];
        if (arr) {
            for (var i = 0, len = arr.length; i < len; i++) {
                var e = arr[i];
                if (!e) {
                    continue;
                }
                if (e instanceof ContextKeyAndExpr) {
                    expr = expr.concat(e.expr);
                    continue;
                }
                if (e instanceof ContextKeyOrExpr) {
                    // Not allowed, because we don't have parens!
                    throw new Error("It is not allowed to have an or expression here due to lack of parens!");
                }
                expr.push(e);
            }
            expr.sort(cmp);
        }
        return expr;
    };
    ContextKeyAndExpr.prototype.keys = function () {
        var result = [];
        for (var _i = 0, _a = this.expr; _i < _a.length; _i++) {
            var expr = _a[_i];
            result.push.apply(result, expr.keys());
        }
        return result;
    };
    ContextKeyAndExpr.prototype.negate = function () {
        var result = [];
        for (var _i = 0, _a = this.expr; _i < _a.length; _i++) {
            var expr = _a[_i];
            result.push(expr.negate());
        }
        return ContextKeyOrExpr.create(result);
    };
    return ContextKeyAndExpr;
}());
export { ContextKeyAndExpr };
var ContextKeyOrExpr = /** @class */ (function () {
    function ContextKeyOrExpr(expr) {
        this.expr = expr;
    }
    ContextKeyOrExpr.create = function (_expr) {
        var expr = ContextKeyOrExpr._normalizeArr(_expr);
        if (expr.length === 0) {
            return undefined;
        }
        if (expr.length === 1) {
            return expr[0];
        }
        return new ContextKeyOrExpr(expr);
    };
    ContextKeyOrExpr.prototype.getType = function () {
        return 8 /* Or */;
    };
    ContextKeyOrExpr.prototype.equals = function (other) {
        if (other instanceof ContextKeyOrExpr) {
            if (this.expr.length !== other.expr.length) {
                return false;
            }
            for (var i = 0, len = this.expr.length; i < len; i++) {
                if (!this.expr[i].equals(other.expr[i])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    };
    ContextKeyOrExpr.prototype.evaluate = function (context) {
        for (var i = 0, len = this.expr.length; i < len; i++) {
            if (this.expr[i].evaluate(context)) {
                return true;
            }
        }
        return false;
    };
    ContextKeyOrExpr._normalizeArr = function (arr) {
        var expr = [];
        if (arr) {
            for (var i = 0, len = arr.length; i < len; i++) {
                var e = arr[i];
                if (!e) {
                    continue;
                }
                if (e instanceof ContextKeyOrExpr) {
                    expr = expr.concat(e.expr);
                    continue;
                }
                expr.push(e);
            }
            expr.sort(cmp);
        }
        return expr;
    };
    ContextKeyOrExpr.prototype.keys = function () {
        var result = [];
        for (var _i = 0, _a = this.expr; _i < _a.length; _i++) {
            var expr = _a[_i];
            result.push.apply(result, expr.keys());
        }
        return result;
    };
    ContextKeyOrExpr.prototype.negate = function () {
        var result = [];
        for (var _i = 0, _a = this.expr; _i < _a.length; _i++) {
            var expr = _a[_i];
            result.push(expr.negate());
        }
        var terminals = function (node) {
            if (node instanceof ContextKeyOrExpr) {
                return node.expr;
            }
            return [node];
        };
        // We don't support parens, so here we distribute the AND over the OR terminals
        // We always take the first 2 AND pairs and distribute them
        while (result.length > 1) {
            var LEFT = result.shift();
            var RIGHT = result.shift();
            var all = [];
            for (var _b = 0, _c = terminals(LEFT); _b < _c.length; _b++) {
                var left = _c[_b];
                for (var _d = 0, _e = terminals(RIGHT); _d < _e.length; _d++) {
                    var right = _e[_d];
                    all.push(ContextKeyExpr.and(left, right));
                }
            }
            result.unshift(ContextKeyExpr.or.apply(ContextKeyExpr, all));
        }
        return result[0];
    };
    return ContextKeyOrExpr;
}());
export { ContextKeyOrExpr };
var RawContextKey = /** @class */ (function (_super) {
    __extends(RawContextKey, _super);
    function RawContextKey(key, defaultValue) {
        var _this = _super.call(this, key) || this;
        _this._defaultValue = defaultValue;
        return _this;
    }
    RawContextKey.prototype.bindTo = function (target) {
        return target.createKey(this.key, this._defaultValue);
    };
    RawContextKey.prototype.getValue = function (target) {
        return target.getContextKeyValue(this.key);
    };
    RawContextKey.prototype.toNegated = function () {
        return ContextKeyExpr.not(this.key);
    };
    return RawContextKey;
}(ContextKeyDefinedExpr));
export { RawContextKey };
export var IContextKeyService = createDecorator('contextKeyService');
export var SET_CONTEXT_COMMAND_ID = 'setContext';
