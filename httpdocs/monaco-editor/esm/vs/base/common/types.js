/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var _typeof = {
    number: 'number',
    string: 'string',
    undefined: 'undefined',
    object: 'object',
    function: 'function'
};
/**
 * @returns whether the provided parameter is a JavaScript Array or not.
 */
export function isArray(array) {
    if (Array.isArray) {
        return Array.isArray(array);
    }
    if (array && typeof (array.length) === _typeof.number && array.constructor === Array) {
        return true;
    }
    return false;
}
/**
 * @returns whether the provided parameter is a JavaScript String or not.
 */
export function isString(str) {
    if (typeof (str) === _typeof.string || str instanceof String) {
        return true;
    }
    return false;
}
/**
 *
 * @returns whether the provided parameter is of type `object` but **not**
 *	`null`, an `array`, a `regexp`, nor a `date`.
 */
export function isObject(obj) {
    // The method can't do a type cast since there are type (like strings) which
    // are subclasses of any put not positvely matched by the function. Hence type
    // narrowing results in wrong results.
    return typeof obj === _typeof.object
        && obj !== null
        && !Array.isArray(obj)
        && !(obj instanceof RegExp)
        && !(obj instanceof Date);
}
/**
 * In **contrast** to just checking `typeof` this will return `false` for `NaN`.
 * @returns whether the provided parameter is a JavaScript Number or not.
 */
export function isNumber(obj) {
    if ((typeof (obj) === _typeof.number || obj instanceof Number) && !isNaN(obj)) {
        return true;
    }
    return false;
}
/**
 * @returns whether the provided parameter is a JavaScript Boolean or not.
 */
export function isBoolean(obj) {
    return obj === true || obj === false;
}
/**
 * @returns whether the provided parameter is undefined.
 */
export function isUndefined(obj) {
    return typeof (obj) === _typeof.undefined;
}
/**
 * @returns whether the provided parameter is undefined or null.
 */
export function isUndefinedOrNull(obj) {
    return isUndefined(obj) || obj === null;
}
var hasOwnProperty = Object.prototype.hasOwnProperty;
/**
 * @returns whether the provided parameter is an empty JavaScript Object or not.
 */
export function isEmptyObject(obj) {
    if (!isObject(obj)) {
        return false;
    }
    for (var key in obj) {
        if (hasOwnProperty.call(obj, key)) {
            return false;
        }
    }
    return true;
}
/**
 * @returns whether the provided parameter is a JavaScript Function or not.
 */
export function isFunction(obj) {
    return typeof obj === _typeof.function;
}
export function validateConstraints(args, constraints) {
    var len = Math.min(args.length, constraints.length);
    for (var i = 0; i < len; i++) {
        validateConstraint(args[i], constraints[i]);
    }
}
export function validateConstraint(arg, constraint) {
    if (isString(constraint)) {
        if (typeof arg !== constraint) {
            throw new Error("argument does not match constraint: typeof " + constraint);
        }
    }
    else if (isFunction(constraint)) {
        try {
            if (arg instanceof constraint) {
                return;
            }
        }
        catch (_a) {
            // ignore
        }
        if (!isUndefinedOrNull(arg) && arg.constructor === constraint) {
            return;
        }
        if (constraint.length === 1 && constraint.call(undefined, arg) === true) {
            return;
        }
        throw new Error("argument does not match one of these constraints: arg instanceof constraint, arg.constructor === constraint, nor constraint(arg) === true");
    }
}
export function getAllPropertyNames(obj) {
    var res = [];
    var proto = Object.getPrototypeOf(obj);
    while (Object.prototype !== proto) {
        res = res.concat(Object.getOwnPropertyNames(proto));
        proto = Object.getPrototypeOf(proto);
    }
    return res;
}
export function getAllMethodNames(obj) {
    var methods = [];
    for (var _i = 0, _a = getAllPropertyNames(obj); _i < _a.length; _i++) {
        var prop = _a[_i];
        if (typeof obj[prop] === 'function') {
            methods.push(prop);
        }
    }
    return methods;
}
export function createProxyObject(methodNames, invoke) {
    var createProxyMethod = function (method) {
        return function () {
            var args = Array.prototype.slice.call(arguments, 0);
            return invoke(method, args);
        };
    };
    var result = {};
    for (var _i = 0, methodNames_1 = methodNames; _i < methodNames_1.length; _i++) {
        var methodName = methodNames_1[_i];
        result[methodName] = createProxyMethod(methodName);
    }
    return result;
}
/**
 * Converts null to undefined, passes all other values through.
 */
export function withNullAsUndefined(x) {
    return x === null ? undefined : x;
}
/**
 * Converts undefined to null, passes all other values through.
 */
export function withUndefinedAsNull(x) {
    return typeof x === 'undefined' ? null : x;
}
