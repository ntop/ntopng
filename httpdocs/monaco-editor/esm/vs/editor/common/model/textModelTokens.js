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
import * as arrays from '../../../base/common/arrays.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { LineTokens } from '../core/lineTokens.js';
import { Position } from '../core/position.js';
import { TokenizationRegistry } from '../modes.js';
import { nullTokenize2 } from '../modes/nullMode.js';
import { Disposable } from '../../../base/common/lifecycle.js';
import { StopWatch } from '../../../base/common/stopwatch.js';
import { MultilineTokensBuilder, countEOL } from './tokensStore.js';
var TokenizationStateStore = /** @class */ (function () {
    function TokenizationStateStore() {
        this._beginState = [];
        this._valid = [];
        this._len = 0;
        this._invalidLineStartIndex = 0;
    }
    TokenizationStateStore.prototype._reset = function (initialState) {
        this._beginState = [];
        this._valid = [];
        this._len = 0;
        this._invalidLineStartIndex = 0;
        if (initialState) {
            this._setBeginState(0, initialState);
        }
    };
    TokenizationStateStore.prototype.flush = function (initialState) {
        this._reset(initialState);
    };
    Object.defineProperty(TokenizationStateStore.prototype, "invalidLineStartIndex", {
        get: function () {
            return this._invalidLineStartIndex;
        },
        enumerable: true,
        configurable: true
    });
    TokenizationStateStore.prototype._invalidateLine = function (lineIndex) {
        if (lineIndex < this._len) {
            this._valid[lineIndex] = false;
        }
        if (lineIndex < this._invalidLineStartIndex) {
            this._invalidLineStartIndex = lineIndex;
        }
    };
    TokenizationStateStore.prototype._isValid = function (lineIndex) {
        if (lineIndex < this._len) {
            return this._valid[lineIndex];
        }
        return false;
    };
    TokenizationStateStore.prototype.getBeginState = function (lineIndex) {
        if (lineIndex < this._len) {
            return this._beginState[lineIndex];
        }
        return null;
    };
    TokenizationStateStore.prototype._ensureLine = function (lineIndex) {
        while (lineIndex >= this._len) {
            this._beginState[this._len] = null;
            this._valid[this._len] = false;
            this._len++;
        }
    };
    TokenizationStateStore.prototype._deleteLines = function (start, deleteCount) {
        if (deleteCount === 0) {
            return;
        }
        if (start + deleteCount > this._len) {
            deleteCount = this._len - start;
        }
        this._beginState.splice(start, deleteCount);
        this._valid.splice(start, deleteCount);
        this._len -= deleteCount;
    };
    TokenizationStateStore.prototype._insertLines = function (insertIndex, insertCount) {
        if (insertCount === 0) {
            return;
        }
        var beginState = [];
        var valid = [];
        for (var i = 0; i < insertCount; i++) {
            beginState[i] = null;
            valid[i] = false;
        }
        this._beginState = arrays.arrayInsert(this._beginState, insertIndex, beginState);
        this._valid = arrays.arrayInsert(this._valid, insertIndex, valid);
        this._len += insertCount;
    };
    TokenizationStateStore.prototype._setValid = function (lineIndex, valid) {
        this._ensureLine(lineIndex);
        this._valid[lineIndex] = valid;
    };
    TokenizationStateStore.prototype._setBeginState = function (lineIndex, beginState) {
        this._ensureLine(lineIndex);
        this._beginState[lineIndex] = beginState;
    };
    TokenizationStateStore.prototype.setEndState = function (linesLength, lineIndex, endState) {
        this._setValid(lineIndex, true);
        this._invalidLineStartIndex = lineIndex + 1;
        // Check if this was the last line
        if (lineIndex === linesLength - 1) {
            return;
        }
        // Check if the end state has changed
        var previousEndState = this.getBeginState(lineIndex + 1);
        if (previousEndState === null || !endState.equals(previousEndState)) {
            this._setBeginState(lineIndex + 1, endState);
            this._invalidateLine(lineIndex + 1);
            return;
        }
        // Perhaps we can skip tokenizing some lines...
        var i = lineIndex + 1;
        while (i < linesLength) {
            if (!this._isValid(i)) {
                break;
            }
            i++;
        }
        this._invalidLineStartIndex = i;
    };
    TokenizationStateStore.prototype.setFakeTokens = function (lineIndex) {
        this._setValid(lineIndex, false);
    };
    //#region Editing
    TokenizationStateStore.prototype.applyEdits = function (range, eolCount) {
        var deletingLinesCnt = range.endLineNumber - range.startLineNumber;
        var insertingLinesCnt = eolCount;
        var editingLinesCnt = Math.min(deletingLinesCnt, insertingLinesCnt);
        for (var j = editingLinesCnt; j >= 0; j--) {
            this._invalidateLine(range.startLineNumber + j - 1);
        }
        this._acceptDeleteRange(range);
        this._acceptInsertText(new Position(range.startLineNumber, range.startColumn), eolCount);
    };
    TokenizationStateStore.prototype._acceptDeleteRange = function (range) {
        var firstLineIndex = range.startLineNumber - 1;
        if (firstLineIndex >= this._len) {
            return;
        }
        this._deleteLines(range.startLineNumber, range.endLineNumber - range.startLineNumber);
    };
    TokenizationStateStore.prototype._acceptInsertText = function (position, eolCount) {
        var lineIndex = position.lineNumber - 1;
        if (lineIndex >= this._len) {
            return;
        }
        this._insertLines(position.lineNumber, eolCount);
    };
    return TokenizationStateStore;
}());
export { TokenizationStateStore };
var TextModelTokenization = /** @class */ (function (_super) {
    __extends(TextModelTokenization, _super);
    function TextModelTokenization(textModel) {
        var _this = _super.call(this) || this;
        _this._textModel = textModel;
        _this._tokenizationStateStore = new TokenizationStateStore();
        _this._revalidateTokensTimeout = -1;
        _this._tokenizationSupport = null;
        _this._register(TokenizationRegistry.onDidChange(function (e) {
            var languageIdentifier = _this._textModel.getLanguageIdentifier();
            if (e.changedLanguages.indexOf(languageIdentifier.language) === -1) {
                return;
            }
            _this._resetTokenizationState();
            _this._textModel.clearTokens();
        }));
        _this._register(_this._textModel.onDidChangeRawContentFast(function (e) {
            if (e.containsEvent(1 /* Flush */)) {
                _this._resetTokenizationState();
                return;
            }
        }));
        _this._register(_this._textModel.onDidChangeContentFast(function (e) {
            for (var i = 0, len = e.changes.length; i < len; i++) {
                var change = e.changes[i];
                var eolCount = countEOL(change.text)[0];
                _this._tokenizationStateStore.applyEdits(change.range, eolCount);
            }
            _this._beginBackgroundTokenization();
        }));
        _this._register(_this._textModel.onDidChangeAttached(function () {
            _this._beginBackgroundTokenization();
        }));
        _this._register(_this._textModel.onDidChangeLanguage(function () {
            _this._resetTokenizationState();
            _this._textModel.clearTokens();
        }));
        _this._resetTokenizationState();
        return _this;
    }
    TextModelTokenization.prototype.dispose = function () {
        this._clearTimers();
        _super.prototype.dispose.call(this);
    };
    TextModelTokenization.prototype._clearTimers = function () {
        if (this._revalidateTokensTimeout !== -1) {
            clearTimeout(this._revalidateTokensTimeout);
            this._revalidateTokensTimeout = -1;
        }
    };
    TextModelTokenization.prototype._resetTokenizationState = function () {
        this._clearTimers();
        var _a = initializeTokenization(this._textModel), tokenizationSupport = _a[0], initialState = _a[1];
        this._tokenizationSupport = tokenizationSupport;
        this._tokenizationStateStore.flush(initialState);
        this._beginBackgroundTokenization();
    };
    TextModelTokenization.prototype._beginBackgroundTokenization = function () {
        var _this = this;
        if (this._textModel.isAttachedToEditor() && this._hasLinesToTokenize() && this._revalidateTokensTimeout === -1) {
            this._revalidateTokensTimeout = setTimeout(function () {
                _this._revalidateTokensTimeout = -1;
                _this._revalidateTokensNow();
            }, 0);
        }
    };
    TextModelTokenization.prototype._revalidateTokensNow = function (toLineNumber) {
        if (toLineNumber === void 0) { toLineNumber = this._textModel.getLineCount(); }
        var MAX_ALLOWED_TIME = 20;
        var builder = new MultilineTokensBuilder();
        var sw = StopWatch.create(false);
        while (this._hasLinesToTokenize()) {
            if (sw.elapsed() > MAX_ALLOWED_TIME) {
                // Stop if MAX_ALLOWED_TIME is reached
                break;
            }
            var tokenizedLineNumber = this._tokenizeOneInvalidLine(builder);
            if (tokenizedLineNumber >= toLineNumber) {
                break;
            }
        }
        this._beginBackgroundTokenization();
        this._textModel.setTokens(builder.tokens);
    };
    TextModelTokenization.prototype.tokenizeViewport = function (startLineNumber, endLineNumber) {
        var builder = new MultilineTokensBuilder();
        this._tokenizeViewport(builder, startLineNumber, endLineNumber);
        this._textModel.setTokens(builder.tokens);
    };
    TextModelTokenization.prototype.reset = function () {
        this._resetTokenizationState();
        this._textModel.clearTokens();
    };
    TextModelTokenization.prototype.forceTokenization = function (lineNumber) {
        var builder = new MultilineTokensBuilder();
        this._updateTokensUntilLine(builder, lineNumber);
        this._textModel.setTokens(builder.tokens);
    };
    TextModelTokenization.prototype.isCheapToTokenize = function (lineNumber) {
        if (!this._tokenizationSupport) {
            return true;
        }
        var firstInvalidLineNumber = this._tokenizationStateStore.invalidLineStartIndex + 1;
        if (lineNumber > firstInvalidLineNumber) {
            return false;
        }
        if (lineNumber < firstInvalidLineNumber) {
            return true;
        }
        if (this._textModel.getLineLength(lineNumber) < 2048 /* CHEAP_TOKENIZATION_LENGTH_LIMIT */) {
            return true;
        }
        return false;
    };
    TextModelTokenization.prototype._hasLinesToTokenize = function () {
        if (!this._tokenizationSupport) {
            return false;
        }
        return (this._tokenizationStateStore.invalidLineStartIndex < this._textModel.getLineCount());
    };
    TextModelTokenization.prototype._tokenizeOneInvalidLine = function (builder) {
        if (!this._hasLinesToTokenize()) {
            return this._textModel.getLineCount() + 1;
        }
        var lineNumber = this._tokenizationStateStore.invalidLineStartIndex + 1;
        this._updateTokensUntilLine(builder, lineNumber);
        return lineNumber;
    };
    TextModelTokenization.prototype._updateTokensUntilLine = function (builder, lineNumber) {
        if (!this._tokenizationSupport) {
            return;
        }
        var languageIdentifier = this._textModel.getLanguageIdentifier();
        var linesLength = this._textModel.getLineCount();
        var endLineIndex = lineNumber - 1;
        // Validate all states up to and including endLineIndex
        for (var lineIndex = this._tokenizationStateStore.invalidLineStartIndex; lineIndex <= endLineIndex; lineIndex++) {
            var text = this._textModel.getLineContent(lineIndex + 1);
            var lineStartState = this._tokenizationStateStore.getBeginState(lineIndex);
            var r = safeTokenize(languageIdentifier, this._tokenizationSupport, text, lineStartState);
            builder.add(lineIndex + 1, r.tokens);
            this._tokenizationStateStore.setEndState(linesLength, lineIndex, r.endState);
            lineIndex = this._tokenizationStateStore.invalidLineStartIndex - 1; // -1 because the outer loop increments it
        }
    };
    TextModelTokenization.prototype._tokenizeViewport = function (builder, startLineNumber, endLineNumber) {
        if (!this._tokenizationSupport) {
            // nothing to do
            return;
        }
        if (endLineNumber <= this._tokenizationStateStore.invalidLineStartIndex) {
            // nothing to do
            return;
        }
        if (startLineNumber <= this._tokenizationStateStore.invalidLineStartIndex) {
            // tokenization has reached the viewport start...
            this._updateTokensUntilLine(builder, endLineNumber);
            return;
        }
        var nonWhitespaceColumn = this._textModel.getLineFirstNonWhitespaceColumn(startLineNumber);
        var fakeLines = [];
        var initialState = null;
        for (var i = startLineNumber - 1; nonWhitespaceColumn > 0 && i >= 1; i--) {
            var newNonWhitespaceIndex = this._textModel.getLineFirstNonWhitespaceColumn(i);
            if (newNonWhitespaceIndex === 0) {
                continue;
            }
            if (newNonWhitespaceIndex < nonWhitespaceColumn) {
                initialState = this._tokenizationStateStore.getBeginState(i - 1);
                if (initialState) {
                    break;
                }
                fakeLines.push(this._textModel.getLineContent(i));
                nonWhitespaceColumn = newNonWhitespaceIndex;
            }
        }
        if (!initialState) {
            initialState = this._tokenizationSupport.getInitialState();
        }
        var languageIdentifier = this._textModel.getLanguageIdentifier();
        var state = initialState;
        for (var i = fakeLines.length - 1; i >= 0; i--) {
            var r = safeTokenize(languageIdentifier, this._tokenizationSupport, fakeLines[i], state);
            state = r.endState;
        }
        for (var lineNumber = startLineNumber; lineNumber <= endLineNumber; lineNumber++) {
            var text = this._textModel.getLineContent(lineNumber);
            var r = safeTokenize(languageIdentifier, this._tokenizationSupport, text, state);
            builder.add(lineNumber, r.tokens);
            this._tokenizationStateStore.setFakeTokens(lineNumber - 1);
            state = r.endState;
        }
    };
    return TextModelTokenization;
}(Disposable));
export { TextModelTokenization };
function initializeTokenization(textModel) {
    var languageIdentifier = textModel.getLanguageIdentifier();
    var tokenizationSupport = (textModel.isTooLargeForTokenization()
        ? null
        : TokenizationRegistry.get(languageIdentifier.language));
    var initialState = null;
    if (tokenizationSupport) {
        try {
            initialState = tokenizationSupport.getInitialState();
        }
        catch (e) {
            onUnexpectedError(e);
            tokenizationSupport = null;
        }
    }
    return [tokenizationSupport, initialState];
}
function safeTokenize(languageIdentifier, tokenizationSupport, text, state) {
    var r = null;
    if (tokenizationSupport) {
        try {
            r = tokenizationSupport.tokenize2(text, state.clone(), 0);
        }
        catch (e) {
            onUnexpectedError(e);
        }
    }
    if (!r) {
        r = nullTokenize2(languageIdentifier.id, text, state, 0);
    }
    LineTokens.convertToEndOffset(r.tokens, text.length);
    return r;
}
