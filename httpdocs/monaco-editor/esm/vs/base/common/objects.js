/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { isObject, isUndefinedOrNull, isArray } from './types.js';
export function deepClone(obj) {
    if (!obj || typeof obj !== 'object') {
        return obj;
    }
    if (obj instanceof RegExp) {
        // See https://github.com/Microsoft/TypeScript/issues/10990
        return obj;
    }
    var result = Array.isArray(obj) ? [] : {};
    Object.keys(obj).forEach(function (key) {
        if (obj[key] && typeof obj[key] === 'object') {
            result[key] = deepClone(obj[key]);
        }
        else {
            result[key] = obj[key];
        }
    });
    return result;
}
export function deepFreeze(obj) {
    if (!obj || typeof obj !== 'object') {
        return obj;
    }
    var stack = [obj];
    while (stack.length > 0) {
        var obj_1 = stack.shift();
        Object.freeze(obj_1);
        for (var key in obj_1) {
            if (_hasOwnProperty.call(obj_1, key)) {
                var prop = obj_1[key];
                if (typeof prop === 'object' && !Object.isFrozen(prop)) {
                    stack.push(prop);
                }
            }
        }
    }
    return obj;
}
var _hasOwnProperty = Object.prototype.hasOwnProperty;
export function cloneAndChange(obj, changer) {
    return _cloneAndChange(obj, changer, new Set());
}
function _cloneAndChange(obj, changer, seen) {
    if (isUndefinedOrNull(obj)) {
        return obj;
    }
    var changed = changer(obj);
    if (typeof changed !== 'undefined') {
        return changed;
    }
    if (isArray(obj)) {
        var r1 = [];
        for (var _i = 0, obj_2 = obj; _i < obj_2.length; _i++) {
            var e = obj_2[_i];
            r1.push(_cloneAndChange(e, changer, seen));
        }
        return r1;
    }
    if (isObject(obj)) {
        if (seen.has(obj)) {
            throw new Error('Cannot clone recursive data-structure');
        }
        seen.add(obj);
        var r2 = {};
        for (var i2 in obj) {
            if (_hasOwnProperty.call(obj, i2)) {
                r2[i2] = _cloneAndChange(obj[i2], changer, seen);
            }
        }
        seen.delete(obj);
        return r2;
    }
    return obj;
}
/**
 * Copies all properties of source into destination. The optional parameter "overwrite" allows to control
 * if existing properties on the destination should be overwritten or not. Defaults to true (overwrite).
 */
export function mixin(destination, source, overwrite) {
    if (overwrite === void 0) { overwrite = true; }
    if (!isObject(destination)) {
        return source;
    }
    if (isObject(source)) {
        Object.keys(source).forEach(function (key) {
            if (key in destination) {
                if (overwrite) {
                    if (isObject(destination[key]) && isObject(source[key])) {
                        mixin(destination[key], source[key], overwrite);
                    }
                    else {
                        destination[key] = source[key];
                    }
                }
            }
            else {
                destination[key] = source[key];
            }
        });
    }
    return destination;
}
export function assign(destination) {
    var sources = [];
    for (var _i = 1; _i < arguments.length; _i++) {
        sources[_i - 1] = arguments[_i];
    }
    sources.forEach(function (source) { return Object.keys(source).forEach(function (key) { return destination[key] = source[key]; }); });
    return destination;
}
export function equals(one, other) {
    if (one === other) {
        return true;
    }
    if (one === null || one === undefined || other === null || other === undefined) {
        return false;
    }
    if (typeof one !== typeof other) {
        return false;
    }
    if (typeof one !== 'object') {
        return false;
    }
    if ((Array.isArray(one)) !== (Array.isArray(other))) {
        return false;
    }
    var i;
    var key;
    if (Array.isArray(one)) {
        if (one.length !== other.length) {
            return false;
        }
        for (i = 0; i < one.length; i++) {
            if (!equals(one[i], other[i])) {
                return false;
            }
        }
    }
    else {
        var oneKeys = [];
        for (key in one) {
            oneKeys.push(key);
        }
        oneKeys.sort();
        var otherKeys = [];
        for (key in other) {
            otherKeys.push(key);
        }
        otherKeys.sort();
        if (!equals(oneKeys, otherKeys)) {
            return false;
        }
        for (i = 0; i < oneKeys.length; i++) {
            if (!equals(one[oneKeys[i]], other[oneKeys[i]])) {
                return false;
            }
        }
    }
    return true;
}
export function getOrDefault(obj, fn, defaultValue) {
    var result = fn(obj);
    return typeof result === 'undefined' ? defaultValue : result;
}
