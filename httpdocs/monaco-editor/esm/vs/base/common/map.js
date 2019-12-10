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
export function values(forEachable) {
    var result = [];
    forEachable.forEach(function (value) { return result.push(value); });
    return result;
}
export function keys(map) {
    var result = [];
    map.forEach(function (value, key) { return result.push(key); });
    return result;
}
var StringIterator = /** @class */ (function () {
    function StringIterator() {
        this._value = '';
        this._pos = 0;
    }
    StringIterator.prototype.reset = function (key) {
        this._value = key;
        this._pos = 0;
        return this;
    };
    StringIterator.prototype.next = function () {
        this._pos += 1;
        return this;
    };
    StringIterator.prototype.hasNext = function () {
        return this._pos < this._value.length - 1;
    };
    StringIterator.prototype.cmp = function (a) {
        var aCode = a.charCodeAt(0);
        var thisCode = this._value.charCodeAt(this._pos);
        return aCode - thisCode;
    };
    StringIterator.prototype.value = function () {
        return this._value[this._pos];
    };
    return StringIterator;
}());
export { StringIterator };
var PathIterator = /** @class */ (function () {
    function PathIterator() {
    }
    PathIterator.prototype.reset = function (key) {
        this._value = key.replace(/\\$|\/$/, '');
        this._from = 0;
        this._to = 0;
        return this.next();
    };
    PathIterator.prototype.hasNext = function () {
        return this._to < this._value.length;
    };
    PathIterator.prototype.next = function () {
        // this._data = key.split(/[\\/]/).filter(s => !!s);
        this._from = this._to;
        var justSeps = true;
        for (; this._to < this._value.length; this._to++) {
            var ch = this._value.charCodeAt(this._to);
            if (ch === 47 /* Slash */ || ch === 92 /* Backslash */) {
                if (justSeps) {
                    this._from++;
                }
                else {
                    break;
                }
            }
            else {
                justSeps = false;
            }
        }
        return this;
    };
    PathIterator.prototype.cmp = function (a) {
        var aPos = 0;
        var aLen = a.length;
        var thisPos = this._from;
        while (aPos < aLen && thisPos < this._to) {
            var cmp = a.charCodeAt(aPos) - this._value.charCodeAt(thisPos);
            if (cmp !== 0) {
                return cmp;
            }
            aPos += 1;
            thisPos += 1;
        }
        if (aLen === this._to - this._from) {
            return 0;
        }
        else if (aPos < aLen) {
            return -1;
        }
        else {
            return 1;
        }
    };
    PathIterator.prototype.value = function () {
        return this._value.substring(this._from, this._to);
    };
    return PathIterator;
}());
export { PathIterator };
var TernarySearchTreeNode = /** @class */ (function () {
    function TernarySearchTreeNode() {
    }
    return TernarySearchTreeNode;
}());
var TernarySearchTree = /** @class */ (function () {
    function TernarySearchTree(segments) {
        this._iter = segments;
    }
    TernarySearchTree.forPaths = function () {
        return new TernarySearchTree(new PathIterator());
    };
    TernarySearchTree.forStrings = function () {
        return new TernarySearchTree(new StringIterator());
    };
    TernarySearchTree.prototype.clear = function () {
        this._root = undefined;
    };
    TernarySearchTree.prototype.set = function (key, element) {
        var iter = this._iter.reset(key);
        var node;
        if (!this._root) {
            this._root = new TernarySearchTreeNode();
            this._root.segment = iter.value();
        }
        node = this._root;
        while (true) {
            var val = iter.cmp(node.segment);
            if (val > 0) {
                // left
                if (!node.left) {
                    node.left = new TernarySearchTreeNode();
                    node.left.segment = iter.value();
                }
                node = node.left;
            }
            else if (val < 0) {
                // right
                if (!node.right) {
                    node.right = new TernarySearchTreeNode();
                    node.right.segment = iter.value();
                }
                node = node.right;
            }
            else if (iter.hasNext()) {
                // mid
                iter.next();
                if (!node.mid) {
                    node.mid = new TernarySearchTreeNode();
                    node.mid.segment = iter.value();
                }
                node = node.mid;
            }
            else {
                break;
            }
        }
        var oldElement = node.value;
        node.value = element;
        node.key = key;
        return oldElement;
    };
    TernarySearchTree.prototype.get = function (key) {
        var iter = this._iter.reset(key);
        var node = this._root;
        while (node) {
            var val = iter.cmp(node.segment);
            if (val > 0) {
                // left
                node = node.left;
            }
            else if (val < 0) {
                // right
                node = node.right;
            }
            else if (iter.hasNext()) {
                // mid
                iter.next();
                node = node.mid;
            }
            else {
                break;
            }
        }
        return node ? node.value : undefined;
    };
    TernarySearchTree.prototype.findSubstr = function (key) {
        var iter = this._iter.reset(key);
        var node = this._root;
        var candidate = undefined;
        while (node) {
            var val = iter.cmp(node.segment);
            if (val > 0) {
                // left
                node = node.left;
            }
            else if (val < 0) {
                // right
                node = node.right;
            }
            else if (iter.hasNext()) {
                // mid
                iter.next();
                candidate = node.value || candidate;
                node = node.mid;
            }
            else {
                break;
            }
        }
        return node && node.value || candidate;
    };
    TernarySearchTree.prototype.forEach = function (callback) {
        this._forEach(this._root, callback);
    };
    TernarySearchTree.prototype._forEach = function (node, callback) {
        if (node) {
            // left
            this._forEach(node.left, callback);
            // node
            if (node.value) {
                // callback(node.value, this._iter.join(parts));
                callback(node.value, node.key);
            }
            // mid
            this._forEach(node.mid, callback);
            // right
            this._forEach(node.right, callback);
        }
    };
    return TernarySearchTree;
}());
export { TernarySearchTree };
var ResourceMap = /** @class */ (function () {
    function ResourceMap() {
        this.map = new Map();
        this.ignoreCase = false; // in the future this should be an uri-comparator
    }
    ResourceMap.prototype.set = function (resource, value) {
        this.map.set(this.toKey(resource), value);
    };
    ResourceMap.prototype.get = function (resource) {
        return this.map.get(this.toKey(resource));
    };
    ResourceMap.prototype.toKey = function (resource) {
        var key = resource.toString();
        if (this.ignoreCase) {
            key = key.toLowerCase();
        }
        return key;
    };
    return ResourceMap;
}());
export { ResourceMap };
var LinkedMap = /** @class */ (function () {
    function LinkedMap() {
        this._map = new Map();
        this._head = undefined;
        this._tail = undefined;
        this._size = 0;
    }
    LinkedMap.prototype.clear = function () {
        this._map.clear();
        this._head = undefined;
        this._tail = undefined;
        this._size = 0;
    };
    Object.defineProperty(LinkedMap.prototype, "size", {
        get: function () {
            return this._size;
        },
        enumerable: true,
        configurable: true
    });
    LinkedMap.prototype.get = function (key, touch) {
        if (touch === void 0) { touch = 0 /* None */; }
        var item = this._map.get(key);
        if (!item) {
            return undefined;
        }
        if (touch !== 0 /* None */) {
            this.touch(item, touch);
        }
        return item.value;
    };
    LinkedMap.prototype.set = function (key, value, touch) {
        if (touch === void 0) { touch = 0 /* None */; }
        var item = this._map.get(key);
        if (item) {
            item.value = value;
            if (touch !== 0 /* None */) {
                this.touch(item, touch);
            }
        }
        else {
            item = { key: key, value: value, next: undefined, previous: undefined };
            switch (touch) {
                case 0 /* None */:
                    this.addItemLast(item);
                    break;
                case 1 /* AsOld */:
                    this.addItemFirst(item);
                    break;
                case 2 /* AsNew */:
                    this.addItemLast(item);
                    break;
                default:
                    this.addItemLast(item);
                    break;
            }
            this._map.set(key, item);
            this._size++;
        }
    };
    LinkedMap.prototype.delete = function (key) {
        return !!this.remove(key);
    };
    LinkedMap.prototype.remove = function (key) {
        var item = this._map.get(key);
        if (!item) {
            return undefined;
        }
        this._map.delete(key);
        this.removeItem(item);
        this._size--;
        return item.value;
    };
    LinkedMap.prototype.forEach = function (callbackfn, thisArg) {
        var current = this._head;
        while (current) {
            if (thisArg) {
                callbackfn.bind(thisArg)(current.value, current.key, this);
            }
            else {
                callbackfn(current.value, current.key, this);
            }
            current = current.next;
        }
    };
    /* VS Code / Monaco editor runs on es5 which has no Symbol.iterator
    keys(): IterableIterator<K> {
        const current = this._head;
        const iterator: IterableIterator<K> = {
            [Symbol.iterator]() {
                return iterator;
            },
            next():IteratorResult<K> {
                if (current) {
                    const result = { value: current.key, done: false };
                    current = current.next;
                    return result;
                } else {
                    return { value: undefined, done: true };
                }
            }
        };
        return iterator;
    }

    values(): IterableIterator<V> {
        const current = this._head;
        const iterator: IterableIterator<V> = {
            [Symbol.iterator]() {
                return iterator;
            },
            next():IteratorResult<V> {
                if (current) {
                    const result = { value: current.value, done: false };
                    current = current.next;
                    return result;
                } else {
                    return { value: undefined, done: true };
                }
            }
        };
        return iterator;
    }
    */
    LinkedMap.prototype.trimOld = function (newSize) {
        if (newSize >= this.size) {
            return;
        }
        if (newSize === 0) {
            this.clear();
            return;
        }
        var current = this._head;
        var currentSize = this.size;
        while (current && currentSize > newSize) {
            this._map.delete(current.key);
            current = current.next;
            currentSize--;
        }
        this._head = current;
        this._size = currentSize;
        if (current) {
            current.previous = undefined;
        }
    };
    LinkedMap.prototype.addItemFirst = function (item) {
        // First time Insert
        if (!this._head && !this._tail) {
            this._tail = item;
        }
        else if (!this._head) {
            throw new Error('Invalid list');
        }
        else {
            item.next = this._head;
            this._head.previous = item;
        }
        this._head = item;
    };
    LinkedMap.prototype.addItemLast = function (item) {
        // First time Insert
        if (!this._head && !this._tail) {
            this._head = item;
        }
        else if (!this._tail) {
            throw new Error('Invalid list');
        }
        else {
            item.previous = this._tail;
            this._tail.next = item;
        }
        this._tail = item;
    };
    LinkedMap.prototype.removeItem = function (item) {
        if (item === this._head && item === this._tail) {
            this._head = undefined;
            this._tail = undefined;
        }
        else if (item === this._head) {
            // This can only happend if size === 1 which is handle
            // by the case above.
            if (!item.next) {
                throw new Error('Invalid list');
            }
            item.next.previous = undefined;
            this._head = item.next;
        }
        else if (item === this._tail) {
            // This can only happend if size === 1 which is handle
            // by the case above.
            if (!item.previous) {
                throw new Error('Invalid list');
            }
            item.previous.next = undefined;
            this._tail = item.previous;
        }
        else {
            var next = item.next;
            var previous = item.previous;
            if (!next || !previous) {
                throw new Error('Invalid list');
            }
            next.previous = previous;
            previous.next = next;
        }
        item.next = undefined;
        item.previous = undefined;
    };
    LinkedMap.prototype.touch = function (item, touch) {
        if (!this._head || !this._tail) {
            throw new Error('Invalid list');
        }
        if ((touch !== 1 /* AsOld */ && touch !== 2 /* AsNew */)) {
            return;
        }
        if (touch === 1 /* AsOld */) {
            if (item === this._head) {
                return;
            }
            var next = item.next;
            var previous = item.previous;
            // Unlink the item
            if (item === this._tail) {
                // previous must be defined since item was not head but is tail
                // So there are more than on item in the map
                previous.next = undefined;
                this._tail = previous;
            }
            else {
                // Both next and previous are not undefined since item was neither head nor tail.
                next.previous = previous;
                previous.next = next;
            }
            // Insert the node at head
            item.previous = undefined;
            item.next = this._head;
            this._head.previous = item;
            this._head = item;
        }
        else if (touch === 2 /* AsNew */) {
            if (item === this._tail) {
                return;
            }
            var next = item.next;
            var previous = item.previous;
            // Unlink the item.
            if (item === this._head) {
                // next must be defined since item was not tail but is head
                // So there are more than on item in the map
                next.previous = undefined;
                this._head = next;
            }
            else {
                // Both next and previous are not undefined since item was neither head nor tail.
                next.previous = previous;
                previous.next = next;
            }
            item.next = undefined;
            item.previous = this._tail;
            this._tail.next = item;
            this._tail = item;
        }
    };
    LinkedMap.prototype.toJSON = function () {
        var data = [];
        this.forEach(function (value, key) {
            data.push([key, value]);
        });
        return data;
    };
    return LinkedMap;
}());
export { LinkedMap };
var LRUCache = /** @class */ (function (_super) {
    __extends(LRUCache, _super);
    function LRUCache(limit, ratio) {
        if (ratio === void 0) { ratio = 1; }
        var _this = _super.call(this) || this;
        _this._limit = limit;
        _this._ratio = Math.min(Math.max(0, ratio), 1);
        return _this;
    }
    LRUCache.prototype.get = function (key) {
        return _super.prototype.get.call(this, key, 2 /* AsNew */);
    };
    LRUCache.prototype.peek = function (key) {
        return _super.prototype.get.call(this, key, 0 /* None */);
    };
    LRUCache.prototype.set = function (key, value) {
        _super.prototype.set.call(this, key, value, 2 /* AsNew */);
        this.checkTrim();
    };
    LRUCache.prototype.checkTrim = function () {
        if (this.size > this._limit) {
            this.trimOld(Math.round(this._limit * this._ratio));
        }
    };
    return LRUCache;
}(LinkedMap));
export { LRUCache };
