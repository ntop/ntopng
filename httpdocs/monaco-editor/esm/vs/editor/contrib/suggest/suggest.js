/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
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
import { first } from '../../../base/common/async.js';
import { assign } from '../../../base/common/objects.js';
import { onUnexpectedExternalError, canceled, isPromiseCanceledError } from '../../../base/common/errors.js';
import { registerDefaultLanguageCommand } from '../../browser/editorExtensions.js';
import * as modes from '../../common/modes.js';
import { RawContextKey } from '../../../platform/contextkey/common/contextkey.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { Range } from '../../common/core/range.js';
import { FuzzyScore } from '../../../base/common/filters.js';
import { isDisposable, DisposableStore } from '../../../base/common/lifecycle.js';
export var Context = {
    Visible: new RawContextKey('suggestWidgetVisible', false),
    MultipleSuggestions: new RawContextKey('suggestWidgetMultipleSuggestions', false),
    MakesTextEdit: new RawContextKey('suggestionMakesTextEdit', true),
    AcceptSuggestionsOnEnter: new RawContextKey('acceptSuggestionOnEnter', true)
};
var CompletionItem = /** @class */ (function () {
    function CompletionItem(position, completion, container, provider, model) {
        this.position = position;
        this.completion = completion;
        this.container = container;
        this.provider = provider;
        // sorting, filtering
        this.score = FuzzyScore.Default;
        this.distance = 0;
        // ensure lower-variants (perf)
        this.labelLow = completion.label.toLowerCase();
        this.sortTextLow = completion.sortText && completion.sortText.toLowerCase();
        this.filterTextLow = completion.filterText && completion.filterText.toLowerCase();
        // create the suggestion resolver
        var resolveCompletionItem = provider.resolveCompletionItem;
        if (typeof resolveCompletionItem !== 'function') {
            this.resolve = function () { return Promise.resolve(); };
        }
        else {
            var cached_1;
            this.resolve = function (token) {
                if (!cached_1) {
                    var isDone_1 = false;
                    cached_1 = Promise.resolve(resolveCompletionItem.call(provider, model, position, completion, token)).then(function (value) {
                        assign(completion, value);
                        isDone_1 = true;
                    }, function (err) {
                        if (isPromiseCanceledError(err)) {
                            // the IPC queue will reject the request with the
                            // cancellation error -> reset cached
                            cached_1 = undefined;
                        }
                    });
                    token.onCancellationRequested(function () {
                        if (!isDone_1) {
                            // cancellation after the request has been
                            // dispatched -> reset cache
                            cached_1 = undefined;
                        }
                    });
                }
                return cached_1;
            };
        }
    }
    return CompletionItem;
}());
export { CompletionItem };
var CompletionOptions = /** @class */ (function () {
    function CompletionOptions(snippetSortOrder, kindFilter, providerFilter) {
        if (snippetSortOrder === void 0) { snippetSortOrder = 2 /* Bottom */; }
        if (kindFilter === void 0) { kindFilter = new Set(); }
        if (providerFilter === void 0) { providerFilter = new Set(); }
        this.snippetSortOrder = snippetSortOrder;
        this.kindFilter = kindFilter;
        this.providerFilter = providerFilter;
    }
    CompletionOptions.default = new CompletionOptions();
    return CompletionOptions;
}());
export { CompletionOptions };
var _snippetSuggestSupport;
export function getSnippetSuggestSupport() {
    return _snippetSuggestSupport;
}
export function provideSuggestionItems(model, position, options, context, token) {
    if (options === void 0) { options = CompletionOptions.default; }
    if (context === void 0) { context = { triggerKind: 0 /* Invoke */ }; }
    if (token === void 0) { token = CancellationToken.None; }
    var wordUntil = model.getWordUntilPosition(position);
    var defaultRange = new Range(position.lineNumber, wordUntil.startColumn, position.lineNumber, wordUntil.endColumn);
    position = position.clone();
    // get provider groups, always add snippet suggestion provider
    var supports = modes.CompletionProviderRegistry.orderedGroups(model);
    // add snippets provider unless turned off
    if (!options.kindFilter.has(25 /* Snippet */) && _snippetSuggestSupport) {
        supports.unshift([_snippetSuggestSupport]);
    }
    var allSuggestions = [];
    var disposables = new DisposableStore();
    var hasResult = false;
    // add suggestions from contributed providers - providers are ordered in groups of
    // equal score and once a group produces a result the process stops
    var factory = supports.map(function (supports) { return function () {
        // for each support in the group ask for suggestions
        return Promise.all(supports.map(function (provider) {
            if (options.providerFilter.size > 0 && !options.providerFilter.has(provider)) {
                return undefined;
            }
            return Promise.resolve(provider.provideCompletionItems(model, position, context, token)).then(function (container) {
                var len = allSuggestions.length;
                if (container) {
                    for (var _i = 0, _a = container.suggestions || []; _i < _a.length; _i++) {
                        var suggestion = _a[_i];
                        if (!options.kindFilter.has(suggestion.kind)) {
                            // fill in default range when missing
                            if (!suggestion.range) {
                                suggestion.range = defaultRange;
                            }
                            allSuggestions.push(new CompletionItem(position, suggestion, container, provider, model));
                        }
                    }
                    if (isDisposable(container)) {
                        disposables.add(container);
                    }
                }
                if (len !== allSuggestions.length && provider !== _snippetSuggestSupport) {
                    hasResult = true;
                }
            }, onUnexpectedExternalError);
        }));
    }; });
    var result = first(factory, function () {
        // stop on result or cancellation
        return hasResult || token.isCancellationRequested;
    }).then(function () {
        if (token.isCancellationRequested) {
            disposables.dispose();
            return Promise.reject(canceled());
        }
        return allSuggestions.sort(getSuggestionComparator(options.snippetSortOrder));
    });
    // result.then(items => {
    // 	console.log(model.getWordUntilPosition(position), items.map(item => `${item.suggestion.label}, type=${item.suggestion.type}, incomplete?${item.container.incomplete}, overwriteBefore=${item.suggestion.overwriteBefore}`));
    // 	return items;
    // }, err => {
    // 	console.warn(model.getWordUntilPosition(position), err);
    // });
    return result;
}
function defaultComparator(a, b) {
    // check with 'sortText'
    if (a.sortTextLow && b.sortTextLow) {
        if (a.sortTextLow < b.sortTextLow) {
            return -1;
        }
        else if (a.sortTextLow > b.sortTextLow) {
            return 1;
        }
    }
    // check with 'label'
    if (a.completion.label < b.completion.label) {
        return -1;
    }
    else if (a.completion.label > b.completion.label) {
        return 1;
    }
    // check with 'type'
    return a.completion.kind - b.completion.kind;
}
function snippetUpComparator(a, b) {
    if (a.completion.kind !== b.completion.kind) {
        if (a.completion.kind === 25 /* Snippet */) {
            return -1;
        }
        else if (b.completion.kind === 25 /* Snippet */) {
            return 1;
        }
    }
    return defaultComparator(a, b);
}
function snippetDownComparator(a, b) {
    if (a.completion.kind !== b.completion.kind) {
        if (a.completion.kind === 25 /* Snippet */) {
            return 1;
        }
        else if (b.completion.kind === 25 /* Snippet */) {
            return -1;
        }
    }
    return defaultComparator(a, b);
}
var _snippetComparators = new Map();
_snippetComparators.set(0 /* Top */, snippetUpComparator);
_snippetComparators.set(2 /* Bottom */, snippetDownComparator);
_snippetComparators.set(1 /* Inline */, defaultComparator);
export function getSuggestionComparator(snippetConfig) {
    return _snippetComparators.get(snippetConfig);
}
registerDefaultLanguageCommand('_executeCompletionItemProvider', function (model, position, args) { return __awaiter(_this, void 0, void 0, function () {
    var result, disposables, resolving, maxItemsToResolve, items, _i, items_1, item;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                result = {
                    incomplete: false,
                    suggestions: []
                };
                disposables = new DisposableStore();
                resolving = [];
                maxItemsToResolve = args['maxItemsToResolve'] || 0;
                return [4 /*yield*/, provideSuggestionItems(model, position)];
            case 1:
                items = _a.sent();
                for (_i = 0, items_1 = items; _i < items_1.length; _i++) {
                    item = items_1[_i];
                    if (resolving.length < maxItemsToResolve) {
                        resolving.push(item.resolve(CancellationToken.None));
                    }
                    result.incomplete = result.incomplete || item.container.incomplete;
                    result.suggestions.push(item.completion);
                    if (isDisposable(item.container)) {
                        disposables.add(item.container);
                    }
                }
                _a.label = 2;
            case 2:
                _a.trys.push([2, , 4, 5]);
                return [4 /*yield*/, Promise.all(resolving)];
            case 3:
                _a.sent();
                return [2 /*return*/, result];
            case 4:
                setTimeout(function () { return disposables.dispose(); }, 100);
                return [7 /*endfinally*/];
            case 5: return [2 /*return*/];
        }
    });
}); });
var _provider = new /** @class */ (function () {
    function class_1() {
        this.onlyOnceSuggestions = [];
    }
    class_1.prototype.provideCompletionItems = function () {
        var suggestions = this.onlyOnceSuggestions.slice(0);
        var result = { suggestions: suggestions };
        this.onlyOnceSuggestions.length = 0;
        return result;
    };
    return class_1;
}());
modes.CompletionProviderRegistry.register('*', _provider);
export function showSimpleSuggestions(editor, suggestions) {
    setTimeout(function () {
        var _a;
        (_a = _provider.onlyOnceSuggestions).push.apply(_a, suggestions);
        editor.getContribution('editor.contrib.suggestController').triggerSuggest(new Set().add(_provider));
    }, 0);
}
