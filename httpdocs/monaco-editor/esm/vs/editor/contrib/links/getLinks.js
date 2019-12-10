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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
var _this = this;
import { CancellationToken } from '../../../base/common/cancellation.js';
import { onUnexpectedExternalError } from '../../../base/common/errors.js';
import { URI } from '../../../base/common/uri.js';
import { Range } from '../../common/core/range.js';
import { LinkProviderRegistry } from '../../common/modes.js';
import { IModelService } from '../../common/services/modelService.js';
import { CommandsRegistry } from '../../../platform/commands/common/commands.js';
import { isDisposable, Disposable } from '../../../base/common/lifecycle.js';
import { coalesce } from '../../../base/common/arrays.js';
var Link = /** @class */ (function () {
    function Link(link, provider) {
        this._link = link;
        this._provider = provider;
    }
    Link.prototype.toJSON = function () {
        return {
            range: this.range,
            url: this.url,
            tooltip: this.tooltip
        };
    };
    Object.defineProperty(Link.prototype, "range", {
        get: function () {
            return this._link.range;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Link.prototype, "url", {
        get: function () {
            return this._link.url;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Link.prototype, "tooltip", {
        get: function () {
            return this._link.tooltip;
        },
        enumerable: true,
        configurable: true
    });
    Link.prototype.resolve = function (token) {
        var _this = this;
        if (this._link.url) {
            try {
                if (typeof this._link.url === 'string') {
                    return Promise.resolve(URI.parse(this._link.url));
                }
                else {
                    return Promise.resolve(this._link.url);
                }
            }
            catch (e) {
                return Promise.reject(new Error('invalid'));
            }
        }
        if (typeof this._provider.resolveLink === 'function') {
            return Promise.resolve(this._provider.resolveLink(this._link, token)).then(function (value) {
                _this._link = value || _this._link;
                if (_this._link.url) {
                    // recurse
                    return _this.resolve(token);
                }
                return Promise.reject(new Error('missing'));
            });
        }
        return Promise.reject(new Error('missing'));
    };
    return Link;
}());
export { Link };
var LinksList = /** @class */ (function (_super) {
    __extends(LinksList, _super);
    function LinksList(tuples) {
        var _this = _super.call(this) || this;
        var links = [];
        var _loop_1 = function (list, provider) {
            // merge all links
            var newLinks = list.links.map(function (link) { return new Link(link, provider); });
            links = LinksList._union(links, newLinks);
            // register disposables
            if (isDisposable(provider)) {
                this_1._register(provider);
            }
        };
        var this_1 = this;
        for (var _i = 0, tuples_1 = tuples; _i < tuples_1.length; _i++) {
            var _a = tuples_1[_i], list = _a[0], provider = _a[1];
            _loop_1(list, provider);
        }
        _this.links = links;
        return _this;
    }
    LinksList._union = function (oldLinks, newLinks) {
        // reunite oldLinks with newLinks and remove duplicates
        var result = [];
        var oldIndex;
        var oldLen;
        var newIndex;
        var newLen;
        for (oldIndex = 0, newIndex = 0, oldLen = oldLinks.length, newLen = newLinks.length; oldIndex < oldLen && newIndex < newLen;) {
            var oldLink = oldLinks[oldIndex];
            var newLink = newLinks[newIndex];
            if (Range.areIntersectingOrTouching(oldLink.range, newLink.range)) {
                // Remove the oldLink
                oldIndex++;
                continue;
            }
            var comparisonResult = Range.compareRangesUsingStarts(oldLink.range, newLink.range);
            if (comparisonResult < 0) {
                // oldLink is before
                result.push(oldLink);
                oldIndex++;
            }
            else {
                // newLink is before
                result.push(newLink);
                newIndex++;
            }
        }
        for (; oldIndex < oldLen; oldIndex++) {
            result.push(oldLinks[oldIndex]);
        }
        for (; newIndex < newLen; newIndex++) {
            result.push(newLinks[newIndex]);
        }
        return result;
    };
    return LinksList;
}(Disposable));
export { LinksList };
export function getLinks(model, token) {
    var lists = [];
    // ask all providers for links in parallel
    var promises = LinkProviderRegistry.ordered(model).reverse().map(function (provider, i) {
        return Promise.resolve(provider.provideLinks(model, token)).then(function (result) {
            if (result) {
                lists[i] = [result, provider];
            }
        }, onUnexpectedExternalError);
    });
    return Promise.all(promises).then(function () {
        var result = new LinksList(coalesce(lists));
        if (!token.isCancellationRequested) {
            return result;
        }
        result.dispose();
        return new LinksList([]);
    });
}
CommandsRegistry.registerCommand('_executeLinkProvider', function (accessor) {
    var args = [];
    for (var _i = 1; _i < arguments.length; _i++) {
        args[_i - 1] = arguments[_i];
    }
    return __awaiter(_this, void 0, void 0, function () {
        var uri, model, list, result;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    uri = args[0];
                    if (!(uri instanceof URI)) {
                        return [2 /*return*/, []];
                    }
                    model = accessor.get(IModelService).getModel(uri);
                    if (!model) {
                        return [2 /*return*/, []];
                    }
                    return [4 /*yield*/, getLinks(model, CancellationToken.None)];
                case 1:
                    list = _a.sent();
                    if (!list) {
                        return [2 /*return*/, []];
                    }
                    result = list.links.slice(0);
                    list.dispose();
                    return [2 /*return*/, result];
            }
        });
    });
});
