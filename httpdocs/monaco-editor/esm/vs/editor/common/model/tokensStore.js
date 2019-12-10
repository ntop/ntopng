/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as arrays from '../../../base/common/arrays.js';
import { LineTokens } from '../core/lineTokens.js';
import { Position } from '../core/position.js';
import { TokenMetadata } from '../modes.js';
export function countEOL(text) {
    var eolCount = 0;
    var firstLineLength = 0;
    for (var i = 0, len = text.length; i < len; i++) {
        var chr = text.charCodeAt(i);
        if (chr === 13 /* CarriageReturn */) {
            if (eolCount === 0) {
                firstLineLength = i;
            }
            eolCount++;
            if (i + 1 < len && text.charCodeAt(i + 1) === 10 /* LineFeed */) {
                // \r\n... case
                i++; // skip \n
            }
            else {
                // \r... case
            }
        }
        else if (chr === 10 /* LineFeed */) {
            if (eolCount === 0) {
                firstLineLength = i;
            }
            eolCount++;
        }
    }
    if (eolCount === 0) {
        firstLineLength = text.length;
    }
    return [eolCount, firstLineLength];
}
function getDefaultMetadata(topLevelLanguageId) {
    return ((topLevelLanguageId << 0 /* LANGUAGEID_OFFSET */)
        | (0 /* Other */ << 8 /* TOKEN_TYPE_OFFSET */)
        | (0 /* None */ << 11 /* FONT_STYLE_OFFSET */)
        | (1 /* DefaultForeground */ << 14 /* FOREGROUND_OFFSET */)
        | (2 /* DefaultBackground */ << 23 /* BACKGROUND_OFFSET */)) >>> 0;
}
var EMPTY_LINE_TOKENS = (new Uint32Array(0)).buffer;
var MultilineTokensBuilder = /** @class */ (function () {
    function MultilineTokensBuilder() {
        this.tokens = [];
    }
    MultilineTokensBuilder.prototype.add = function (lineNumber, lineTokens) {
        if (this.tokens.length > 0) {
            var last = this.tokens[this.tokens.length - 1];
            var lastLineNumber = last.startLineNumber + last.tokens.length - 1;
            if (lastLineNumber + 1 === lineNumber) {
                // append
                last.tokens.push(lineTokens);
                return;
            }
        }
        this.tokens.push(new MultilineTokens(lineNumber, [lineTokens]));
    };
    return MultilineTokensBuilder;
}());
export { MultilineTokensBuilder };
var MultilineTokens = /** @class */ (function () {
    function MultilineTokens(startLineNumber, tokens) {
        this.startLineNumber = startLineNumber;
        this.tokens = tokens;
    }
    return MultilineTokens;
}());
export { MultilineTokens };
function toUint32Array(arr) {
    if (arr instanceof Uint32Array) {
        return arr;
    }
    else {
        return new Uint32Array(arr);
    }
}
var TokensStore = /** @class */ (function () {
    function TokensStore() {
        this._lineTokens = [];
        this._len = 0;
    }
    TokensStore.prototype.flush = function () {
        this._lineTokens = [];
        this._len = 0;
    };
    TokensStore.prototype.getTokens = function (topLevelLanguageId, lineIndex, lineText) {
        var rawLineTokens = null;
        if (lineIndex < this._len) {
            rawLineTokens = this._lineTokens[lineIndex];
        }
        if (rawLineTokens !== null && rawLineTokens !== EMPTY_LINE_TOKENS) {
            return new LineTokens(toUint32Array(rawLineTokens), lineText);
        }
        var lineTokens = new Uint32Array(2);
        lineTokens[0] = lineText.length;
        lineTokens[1] = getDefaultMetadata(topLevelLanguageId);
        return new LineTokens(lineTokens, lineText);
    };
    TokensStore._massageTokens = function (topLevelLanguageId, lineTextLength, _tokens) {
        var tokens = _tokens ? toUint32Array(_tokens) : null;
        if (lineTextLength === 0) {
            var hasDifferentLanguageId = false;
            if (tokens && tokens.length > 1) {
                hasDifferentLanguageId = (TokenMetadata.getLanguageId(tokens[1]) !== topLevelLanguageId);
            }
            if (!hasDifferentLanguageId) {
                return EMPTY_LINE_TOKENS;
            }
        }
        if (!tokens || tokens.length === 0) {
            var tokens_1 = new Uint32Array(2);
            tokens_1[0] = lineTextLength;
            tokens_1[1] = getDefaultMetadata(topLevelLanguageId);
            return tokens_1.buffer;
        }
        // Ensure the last token covers the end of the text
        tokens[tokens.length - 2] = lineTextLength;
        if (tokens.byteOffset === 0 && tokens.byteLength === tokens.buffer.byteLength) {
            // Store directly the ArrayBuffer pointer to save an object
            return tokens.buffer;
        }
        return tokens;
    };
    TokensStore.prototype._ensureLine = function (lineIndex) {
        while (lineIndex >= this._len) {
            this._lineTokens[this._len] = null;
            this._len++;
        }
    };
    TokensStore.prototype._deleteLines = function (start, deleteCount) {
        if (deleteCount === 0) {
            return;
        }
        if (start + deleteCount > this._len) {
            deleteCount = this._len - start;
        }
        this._lineTokens.splice(start, deleteCount);
        this._len -= deleteCount;
    };
    TokensStore.prototype._insertLines = function (insertIndex, insertCount) {
        if (insertCount === 0) {
            return;
        }
        var lineTokens = [];
        for (var i = 0; i < insertCount; i++) {
            lineTokens[i] = null;
        }
        this._lineTokens = arrays.arrayInsert(this._lineTokens, insertIndex, lineTokens);
        this._len += insertCount;
    };
    TokensStore.prototype.setTokens = function (topLevelLanguageId, lineIndex, lineTextLength, _tokens) {
        var tokens = TokensStore._massageTokens(topLevelLanguageId, lineTextLength, _tokens);
        this._ensureLine(lineIndex);
        this._lineTokens[lineIndex] = tokens;
    };
    //#region Editing
    TokensStore.prototype.acceptEdit = function (range, eolCount, firstLineLength) {
        this._acceptDeleteRange(range);
        this._acceptInsertText(new Position(range.startLineNumber, range.startColumn), eolCount, firstLineLength);
    };
    TokensStore.prototype._acceptDeleteRange = function (range) {
        var firstLineIndex = range.startLineNumber - 1;
        if (firstLineIndex >= this._len) {
            return;
        }
        if (range.startLineNumber === range.endLineNumber) {
            if (range.startColumn === range.endColumn) {
                // Nothing to delete
                return;
            }
            this._lineTokens[firstLineIndex] = TokensStore._delete(this._lineTokens[firstLineIndex], range.startColumn - 1, range.endColumn - 1);
            return;
        }
        this._lineTokens[firstLineIndex] = TokensStore._deleteEnding(this._lineTokens[firstLineIndex], range.startColumn - 1);
        var lastLineIndex = range.endLineNumber - 1;
        var lastLineTokens = null;
        if (lastLineIndex < this._len) {
            lastLineTokens = TokensStore._deleteBeginning(this._lineTokens[lastLineIndex], range.endColumn - 1);
        }
        // Take remaining text on last line and append it to remaining text on first line
        this._lineTokens[firstLineIndex] = TokensStore._append(this._lineTokens[firstLineIndex], lastLineTokens);
        // Delete middle lines
        this._deleteLines(range.startLineNumber, range.endLineNumber - range.startLineNumber);
    };
    TokensStore.prototype._acceptInsertText = function (position, eolCount, firstLineLength) {
        if (eolCount === 0 && firstLineLength === 0) {
            // Nothing to insert
            return;
        }
        var lineIndex = position.lineNumber - 1;
        if (lineIndex >= this._len) {
            return;
        }
        if (eolCount === 0) {
            // Inserting text on one line
            this._lineTokens[lineIndex] = TokensStore._insert(this._lineTokens[lineIndex], position.column - 1, firstLineLength);
            return;
        }
        this._lineTokens[lineIndex] = TokensStore._deleteEnding(this._lineTokens[lineIndex], position.column - 1);
        this._lineTokens[lineIndex] = TokensStore._insert(this._lineTokens[lineIndex], position.column - 1, firstLineLength);
        this._insertLines(position.lineNumber, eolCount);
    };
    TokensStore._deleteBeginning = function (lineTokens, toChIndex) {
        if (lineTokens === null || lineTokens === EMPTY_LINE_TOKENS) {
            return lineTokens;
        }
        return TokensStore._delete(lineTokens, 0, toChIndex);
    };
    TokensStore._deleteEnding = function (lineTokens, fromChIndex) {
        if (lineTokens === null || lineTokens === EMPTY_LINE_TOKENS) {
            return lineTokens;
        }
        var tokens = toUint32Array(lineTokens);
        var lineTextLength = tokens[tokens.length - 2];
        return TokensStore._delete(lineTokens, fromChIndex, lineTextLength);
    };
    TokensStore._delete = function (lineTokens, fromChIndex, toChIndex) {
        if (lineTokens === null || lineTokens === EMPTY_LINE_TOKENS || fromChIndex === toChIndex) {
            return lineTokens;
        }
        var tokens = toUint32Array(lineTokens);
        var tokensCount = (tokens.length >>> 1);
        // special case: deleting everything
        if (fromChIndex === 0 && tokens[tokens.length - 2] === toChIndex) {
            return EMPTY_LINE_TOKENS;
        }
        var fromTokenIndex = LineTokens.findIndexInTokensArray(tokens, fromChIndex);
        var fromTokenStartOffset = (fromTokenIndex > 0 ? tokens[(fromTokenIndex - 1) << 1] : 0);
        var fromTokenEndOffset = tokens[fromTokenIndex << 1];
        if (toChIndex < fromTokenEndOffset) {
            // the delete range is inside a single token
            var delta_1 = (toChIndex - fromChIndex);
            for (var i = fromTokenIndex; i < tokensCount; i++) {
                tokens[i << 1] -= delta_1;
            }
            return lineTokens;
        }
        var dest;
        var lastEnd;
        if (fromTokenStartOffset !== fromChIndex) {
            tokens[fromTokenIndex << 1] = fromChIndex;
            dest = ((fromTokenIndex + 1) << 1);
            lastEnd = fromChIndex;
        }
        else {
            dest = (fromTokenIndex << 1);
            lastEnd = fromTokenStartOffset;
        }
        var delta = (toChIndex - fromChIndex);
        for (var tokenIndex = fromTokenIndex + 1; tokenIndex < tokensCount; tokenIndex++) {
            var tokenEndOffset = tokens[tokenIndex << 1] - delta;
            if (tokenEndOffset > lastEnd) {
                tokens[dest++] = tokenEndOffset;
                tokens[dest++] = tokens[(tokenIndex << 1) + 1];
                lastEnd = tokenEndOffset;
            }
        }
        if (dest === tokens.length) {
            // nothing to trim
            return lineTokens;
        }
        var tmp = new Uint32Array(dest);
        tmp.set(tokens.subarray(0, dest), 0);
        return tmp.buffer;
    };
    TokensStore._append = function (lineTokens, _otherTokens) {
        if (_otherTokens === EMPTY_LINE_TOKENS) {
            return lineTokens;
        }
        if (lineTokens === EMPTY_LINE_TOKENS) {
            return _otherTokens;
        }
        if (lineTokens === null) {
            return lineTokens;
        }
        if (_otherTokens === null) {
            // cannot determine combined line length...
            return null;
        }
        var myTokens = toUint32Array(lineTokens);
        var otherTokens = toUint32Array(_otherTokens);
        var otherTokensCount = (otherTokens.length >>> 1);
        var result = new Uint32Array(myTokens.length + otherTokens.length);
        result.set(myTokens, 0);
        var dest = myTokens.length;
        var delta = myTokens[myTokens.length - 2];
        for (var i = 0; i < otherTokensCount; i++) {
            result[dest++] = otherTokens[(i << 1)] + delta;
            result[dest++] = otherTokens[(i << 1) + 1];
        }
        return result.buffer;
    };
    TokensStore._insert = function (lineTokens, chIndex, textLength) {
        if (lineTokens === null || lineTokens === EMPTY_LINE_TOKENS) {
            // nothing to do
            return lineTokens;
        }
        var tokens = toUint32Array(lineTokens);
        var tokensCount = (tokens.length >>> 1);
        var fromTokenIndex = LineTokens.findIndexInTokensArray(tokens, chIndex);
        if (fromTokenIndex > 0) {
            var fromTokenStartOffset = tokens[(fromTokenIndex - 1) << 1];
            if (fromTokenStartOffset === chIndex) {
                fromTokenIndex--;
            }
        }
        for (var tokenIndex = fromTokenIndex; tokenIndex < tokensCount; tokenIndex++) {
            tokens[tokenIndex << 1] += textLength;
        }
        return lineTokens;
    };
    return TokensStore;
}());
export { TokensStore };
