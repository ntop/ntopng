/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { FIN } from './iterator.js';
var Node = /** @class */ (function () {
    function Node(element) {
        this.element = element;
        this.next = Node.Undefined;
        this.prev = Node.Undefined;
    }
    Node.Undefined = new Node(undefined);
    return Node;
}());
var LinkedList = /** @class */ (function () {
    function LinkedList() {
        this._first = Node.Undefined;
        this._last = Node.Undefined;
        this._size = 0;
    }
    Object.defineProperty(LinkedList.prototype, "size", {
        get: function () {
            return this._size;
        },
        enumerable: true,
        configurable: true
    });
    LinkedList.prototype.isEmpty = function () {
        return this._first === Node.Undefined;
    };
    LinkedList.prototype.clear = function () {
        this._first = Node.Undefined;
        this._last = Node.Undefined;
        this._size = 0;
    };
    LinkedList.prototype.unshift = function (element) {
        return this._insert(element, false);
    };
    LinkedList.prototype.push = function (element) {
        return this._insert(element, true);
    };
    LinkedList.prototype._insert = function (element, atTheEnd) {
        var _this = this;
        var newNode = new Node(element);
        if (this._first === Node.Undefined) {
            this._first = newNode;
            this._last = newNode;
        }
        else if (atTheEnd) {
            // push
            var oldLast = this._last;
            this._last = newNode;
            newNode.prev = oldLast;
            oldLast.next = newNode;
        }
        else {
            // unshift
            var oldFirst = this._first;
            this._first = newNode;
            newNode.next = oldFirst;
            oldFirst.prev = newNode;
        }
        this._size += 1;
        var didRemove = false;
        return function () {
            if (!didRemove) {
                didRemove = true;
                _this._remove(newNode);
            }
        };
    };
    LinkedList.prototype.shift = function () {
        if (this._first === Node.Undefined) {
            return undefined;
        }
        else {
            var res = this._first.element;
            this._remove(this._first);
            return res;
        }
    };
    LinkedList.prototype.pop = function () {
        if (this._last === Node.Undefined) {
            return undefined;
        }
        else {
            var res = this._last.element;
            this._remove(this._last);
            return res;
        }
    };
    LinkedList.prototype._remove = function (node) {
        if (node.prev !== Node.Undefined && node.next !== Node.Undefined) {
            // middle
            var anchor = node.prev;
            anchor.next = node.next;
            node.next.prev = anchor;
        }
        else if (node.prev === Node.Undefined && node.next === Node.Undefined) {
            // only node
            this._first = Node.Undefined;
            this._last = Node.Undefined;
        }
        else if (node.next === Node.Undefined) {
            // last
            this._last = this._last.prev;
            this._last.next = Node.Undefined;
        }
        else if (node.prev === Node.Undefined) {
            // first
            this._first = this._first.next;
            this._first.prev = Node.Undefined;
        }
        // done
        this._size -= 1;
    };
    LinkedList.prototype.iterator = function () {
        var element;
        var node = this._first;
        return {
            next: function () {
                if (node === Node.Undefined) {
                    return FIN;
                }
                if (!element) {
                    element = { done: false, value: node.element };
                }
                else {
                    element.value = node.element;
                }
                node = node.next;
                return element;
            }
        };
    };
    LinkedList.prototype.toArray = function () {
        var result = [];
        for (var node = this._first; node !== Node.Undefined; node = node.next) {
            result.push(node.element);
        }
        return result;
    };
    return LinkedList;
}());
export { LinkedList };
