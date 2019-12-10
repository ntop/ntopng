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
import { equals } from '../../../base/common/arrays.js';
import { CancellationTokenSource } from '../../../base/common/cancellation.js';
import { first } from '../../../base/common/collections.js';
import { onUnexpectedExternalError } from '../../../base/common/errors.js';
import { LRUCache } from '../../../base/common/map.js';
import { DocumentSymbolProviderRegistry } from '../../common/modes.js';
var TreeElement = /** @class */ (function () {
    function TreeElement() {
    }
    TreeElement.prototype.remove = function () {
        if (this.parent) {
            delete this.parent.children[this.id];
        }
    };
    TreeElement.findId = function (candidate, container) {
        // complex id-computation which contains the origin/extension,
        // the parent path, and some dedupe logic when names collide
        var candidateId;
        if (typeof candidate === 'string') {
            candidateId = container.id + "/" + candidate;
        }
        else {
            candidateId = container.id + "/" + candidate.name;
            if (container.children[candidateId] !== undefined) {
                candidateId = container.id + "/" + candidate.name + "_" + candidate.range.startLineNumber + "_" + candidate.range.startColumn;
            }
        }
        var id = candidateId;
        for (var i = 0; container.children[id] !== undefined; i++) {
            id = candidateId + "_" + i;
        }
        return id;
    };
    TreeElement.empty = function (element) {
        for (var _key in element.children) {
            return false;
        }
        return true;
    };
    return TreeElement;
}());
export { TreeElement };
var OutlineElement = /** @class */ (function (_super) {
    __extends(OutlineElement, _super);
    function OutlineElement(id, parent, symbol) {
        var _this = _super.call(this) || this;
        _this.id = id;
        _this.parent = parent;
        _this.symbol = symbol;
        _this.children = Object.create(null);
        return _this;
    }
    return OutlineElement;
}(TreeElement));
export { OutlineElement };
var OutlineGroup = /** @class */ (function (_super) {
    __extends(OutlineGroup, _super);
    function OutlineGroup(id, parent, provider, providerIndex) {
        var _this = _super.call(this) || this;
        _this.id = id;
        _this.parent = parent;
        _this.provider = provider;
        _this.providerIndex = providerIndex;
        _this.children = Object.create(null);
        return _this;
    }
    return OutlineGroup;
}(TreeElement));
export { OutlineGroup };
var MovingAverage = /** @class */ (function () {
    function MovingAverage() {
        this._n = 1;
        this._val = 0;
    }
    MovingAverage.prototype.update = function (value) {
        this._val = this._val + (value - this._val) / this._n;
        this._n += 1;
        return this;
    };
    return MovingAverage;
}());
var OutlineModel = /** @class */ (function (_super) {
    __extends(OutlineModel, _super);
    function OutlineModel(textModel) {
        var _this = _super.call(this) || this;
        _this.textModel = textModel;
        _this.id = 'root';
        _this.parent = undefined;
        _this._groups = Object.create(null);
        _this.children = Object.create(null);
        _this.id = 'root';
        _this.parent = undefined;
        return _this;
    }
    OutlineModel.create = function (textModel, token) {
        var _this = this;
        var key = this._keys.for(textModel, true);
        var data = OutlineModel._requests.get(key);
        if (!data) {
            var source = new CancellationTokenSource();
            data = {
                promiseCnt: 0,
                source: source,
                promise: OutlineModel._create(textModel, source.token),
                model: undefined,
            };
            OutlineModel._requests.set(key, data);
            // keep moving average of request durations
            var now_1 = Date.now();
            data.promise.then(function () {
                var key = _this._keys.for(textModel, false);
                var avg = _this._requestDurations.get(key);
                if (!avg) {
                    avg = new MovingAverage();
                    _this._requestDurations.set(key, avg);
                }
                avg.update(Date.now() - now_1);
            });
        }
        if (data.model) {
            // resolved -> return data
            return Promise.resolve(data.model);
        }
        // increase usage counter
        data.promiseCnt += 1;
        token.onCancellationRequested(function () {
            // last -> cancel provider request, remove cached promise
            if (--data.promiseCnt === 0) {
                data.source.cancel();
                OutlineModel._requests.delete(key);
            }
        });
        return new Promise(function (resolve, reject) {
            data.promise.then(function (model) {
                data.model = model;
                resolve(model);
            }, function (err) {
                OutlineModel._requests.delete(key);
                reject(err);
            });
        });
    };
    OutlineModel._create = function (textModel, token) {
        var cts = new CancellationTokenSource(token);
        var result = new OutlineModel(textModel);
        var provider = DocumentSymbolProviderRegistry.ordered(textModel);
        var promises = provider.map(function (provider, index) {
            var id = TreeElement.findId("provider_" + index, result);
            var group = new OutlineGroup(id, result, provider, index);
            return Promise.resolve(provider.provideDocumentSymbols(result.textModel, cts.token)).then(function (result) {
                for (var _i = 0, _a = result || []; _i < _a.length; _i++) {
                    var info = _a[_i];
                    OutlineModel._makeOutlineElement(info, group);
                }
                return group;
            }, function (err) {
                onUnexpectedExternalError(err);
                return group;
            }).then(function (group) {
                if (!TreeElement.empty(group)) {
                    result._groups[id] = group;
                }
                else {
                    group.remove();
                }
            });
        });
        var listener = DocumentSymbolProviderRegistry.onDidChange(function () {
            var newProvider = DocumentSymbolProviderRegistry.ordered(textModel);
            if (!equals(newProvider, provider)) {
                cts.cancel();
            }
        });
        return Promise.all(promises).then(function () {
            if (cts.token.isCancellationRequested && !token.isCancellationRequested) {
                return OutlineModel._create(textModel, token);
            }
            else {
                return result._compact();
            }
        }).finally(function () {
            listener.dispose();
        });
    };
    OutlineModel._makeOutlineElement = function (info, container) {
        var id = TreeElement.findId(info, container);
        var res = new OutlineElement(id, container, info);
        if (info.children) {
            for (var _i = 0, _a = info.children; _i < _a.length; _i++) {
                var childInfo = _a[_i];
                OutlineModel._makeOutlineElement(childInfo, res);
            }
        }
        container.children[res.id] = res;
    };
    OutlineModel.prototype._compact = function () {
        var count = 0;
        for (var key in this._groups) {
            var group = this._groups[key];
            if (first(group.children) === undefined) { // empty
                delete this._groups[key];
            }
            else {
                count += 1;
            }
        }
        if (count !== 1) {
            //
            this.children = this._groups;
        }
        else {
            // adopt all elements of the first group
            var group = first(this._groups);
            for (var key in group.children) {
                var child = group.children[key];
                child.parent = this;
                this.children[child.id] = child;
            }
        }
        return this;
    };
    OutlineModel._requestDurations = new LRUCache(50, 0.7);
    OutlineModel._requests = new LRUCache(9, 0.75);
    OutlineModel._keys = new /** @class */ (function () {
        function class_1() {
            this._counter = 1;
            this._data = new WeakMap();
        }
        class_1.prototype.for = function (textModel, version) {
            return textModel.id + "/" + (version ? textModel.getVersionId() : '') + "/" + this._hash(DocumentSymbolProviderRegistry.all(textModel));
        };
        class_1.prototype._hash = function (providers) {
            var result = '';
            for (var _i = 0, providers_1 = providers; _i < providers_1.length; _i++) {
                var provider = providers_1[_i];
                var n = this._data.get(provider);
                if (typeof n === 'undefined') {
                    n = this._counter++;
                    this._data.set(provider, n);
                }
                result += n;
            }
            return result;
        };
        return class_1;
    }());
    return OutlineModel;
}(TreeElement));
export { OutlineModel };
