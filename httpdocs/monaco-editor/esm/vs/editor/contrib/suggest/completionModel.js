/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { fuzzyScore, fuzzyScoreGracefulAggressive, FuzzyScore, anyScore } from '../../../base/common/filters.js';
import { EDITOR_DEFAULTS } from '../../common/config/editorOptions.js';
import { compareIgnoreCase } from '../../../base/common/strings.js';
var LineContext = /** @class */ (function () {
    function LineContext(leadingLineContent, characterCountDelta) {
        this.leadingLineContent = leadingLineContent;
        this.characterCountDelta = characterCountDelta;
    }
    return LineContext;
}());
export { LineContext };
var CompletionModel = /** @class */ (function () {
    function CompletionModel(items, column, lineContext, wordDistance, options) {
        if (options === void 0) { options = EDITOR_DEFAULTS.contribInfo.suggest; }
        this._snippetCompareFn = CompletionModel._compareCompletionItems;
        this._items = items;
        this._column = column;
        this._wordDistance = wordDistance;
        this._options = options;
        this._refilterKind = 1 /* All */;
        this._lineContext = lineContext;
        if (options.snippets === 'top') {
            this._snippetCompareFn = CompletionModel._compareCompletionItemsSnippetsUp;
        }
        else if (options.snippets === 'bottom') {
            this._snippetCompareFn = CompletionModel._compareCompletionItemsSnippetsDown;
        }
    }
    Object.defineProperty(CompletionModel.prototype, "lineContext", {
        get: function () {
            return this._lineContext;
        },
        set: function (value) {
            if (this._lineContext.leadingLineContent !== value.leadingLineContent
                || this._lineContext.characterCountDelta !== value.characterCountDelta) {
                this._refilterKind = this._lineContext.characterCountDelta < value.characterCountDelta && this._filteredItems ? 2 /* Incr */ : 1 /* All */;
                this._lineContext = value;
            }
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(CompletionModel.prototype, "items", {
        get: function () {
            this._ensureCachedState();
            return this._filteredItems;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(CompletionModel.prototype, "incomplete", {
        get: function () {
            this._ensureCachedState();
            return this._isIncomplete;
        },
        enumerable: true,
        configurable: true
    });
    CompletionModel.prototype.adopt = function (except) {
        var res = new Array();
        for (var i = 0; i < this._items.length;) {
            if (!except.has(this._items[i].provider)) {
                res.push(this._items[i]);
                // unordered removed
                this._items[i] = this._items[this._items.length - 1];
                this._items.pop();
            }
            else {
                // continue with next item
                i++;
            }
        }
        this._refilterKind = 1 /* All */;
        return res;
    };
    Object.defineProperty(CompletionModel.prototype, "stats", {
        get: function () {
            this._ensureCachedState();
            return this._stats;
        },
        enumerable: true,
        configurable: true
    });
    CompletionModel.prototype._ensureCachedState = function () {
        if (this._refilterKind !== 0 /* Nothing */) {
            this._createCachedState();
        }
    };
    CompletionModel.prototype._createCachedState = function () {
        this._isIncomplete = new Set();
        this._stats = { suggestionCount: 0, snippetCount: 0, textCount: 0 };
        var _a = this._lineContext, leadingLineContent = _a.leadingLineContent, characterCountDelta = _a.characterCountDelta;
        var word = '';
        var wordLow = '';
        // incrementally filter less
        var source = this._refilterKind === 1 /* All */ ? this._items : this._filteredItems;
        var target = [];
        // picks a score function based on the number of
        // items that we have to score/filter and based on the
        // user-configuration
        var scoreFn = (!this._options.filterGraceful || source.length > 2000) ? fuzzyScore : fuzzyScoreGracefulAggressive;
        for (var i = 0; i < source.length; i++) {
            var item = source[i];
            // collect those supports that signaled having
            // an incomplete result
            if (item.container.incomplete) {
                this._isIncomplete.add(item.provider);
            }
            // 'word' is that remainder of the current line that we
            // filter and score against. In theory each suggestion uses a
            // different word, but in practice not - that's why we cache
            var overwriteBefore = item.position.column - item.completion.range.startColumn;
            var wordLen = overwriteBefore + characterCountDelta - (item.position.column - this._column);
            if (word.length !== wordLen) {
                word = wordLen === 0 ? '' : leadingLineContent.slice(-wordLen);
                wordLow = word.toLowerCase();
            }
            // remember the word against which this item was
            // scored
            item.word = word;
            if (wordLen === 0) {
                // when there is nothing to score against, don't
                // event try to do. Use a const rank and rely on
                // the fallback-sort using the initial sort order.
                // use a score of `-100` because that is out of the
                // bound of values `fuzzyScore` will return
                item.score = FuzzyScore.Default;
            }
            else {
                // skip word characters that are whitespace until
                // we have hit the replace range (overwriteBefore)
                var wordPos = 0;
                while (wordPos < overwriteBefore) {
                    var ch = word.charCodeAt(wordPos);
                    if (ch === 32 /* Space */ || ch === 9 /* Tab */) {
                        wordPos += 1;
                    }
                    else {
                        break;
                    }
                }
                if (wordPos >= wordLen) {
                    // the wordPos at which scoring starts is the whole word
                    // and therefore the same rules as not having a word apply
                    item.score = FuzzyScore.Default;
                }
                else if (typeof item.completion.filterText === 'string') {
                    // when there is a `filterText` it must match the `word`.
                    // if it matches we check with the label to compute highlights
                    // and if that doesn't yield a result we have no highlights,
                    // despite having the match
                    var match = scoreFn(word, wordLow, wordPos, item.completion.filterText, item.filterTextLow, 0, false);
                    if (!match) {
                        continue; // NO match
                    }
                    if (compareIgnoreCase(item.completion.filterText, item.completion.label) === 0) {
                        // filterText and label are actually the same -> use good highlights
                        item.score = match;
                    }
                    else {
                        // re-run the scorer on the label in the hope of a result BUT use the rank
                        // of the filterText-match
                        item.score = anyScore(word, wordLow, wordPos, item.completion.label, item.labelLow, 0);
                        item.score[0] = match[0]; // use score from filterText
                    }
                }
                else {
                    // by default match `word` against the `label`
                    var match = scoreFn(word, wordLow, wordPos, item.completion.label, item.labelLow, 0, false);
                    if (!match) {
                        continue; // NO match
                    }
                    item.score = match;
                }
            }
            item.idx = i;
            item.distance = this._wordDistance.distance(item.position, item.completion);
            target.push(item);
            // update stats
            this._stats.suggestionCount++;
            switch (item.completion.kind) {
                case 25 /* Snippet */:
                    this._stats.snippetCount++;
                    break;
                case 18 /* Text */:
                    this._stats.textCount++;
                    break;
            }
        }
        this._filteredItems = target.sort(this._snippetCompareFn);
        this._refilterKind = 0 /* Nothing */;
    };
    CompletionModel._compareCompletionItems = function (a, b) {
        if (a.score[0] > b.score[0]) {
            return -1;
        }
        else if (a.score[0] < b.score[0]) {
            return 1;
        }
        else if (a.distance < b.distance) {
            return -1;
        }
        else if (a.distance > b.distance) {
            return 1;
        }
        else if (a.idx < b.idx) {
            return -1;
        }
        else if (a.idx > b.idx) {
            return 1;
        }
        else {
            return 0;
        }
    };
    CompletionModel._compareCompletionItemsSnippetsDown = function (a, b) {
        if (a.completion.kind !== b.completion.kind) {
            if (a.completion.kind === 25 /* Snippet */) {
                return 1;
            }
            else if (b.completion.kind === 25 /* Snippet */) {
                return -1;
            }
        }
        return CompletionModel._compareCompletionItems(a, b);
    };
    CompletionModel._compareCompletionItemsSnippetsUp = function (a, b) {
        if (a.completion.kind !== b.completion.kind) {
            if (a.completion.kind === 25 /* Snippet */) {
                return -1;
            }
            else if (b.completion.kind === 25 /* Snippet */) {
                return 1;
            }
        }
        return CompletionModel._compareCompletionItems(a, b);
    };
    return CompletionModel;
}());
export { CompletionModel };
