/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { Range } from '../../common/core/range.js';
import { isUpperAsciiLetter, isLowerAsciiLetter } from '../../../base/common/strings.js';
var WordSelectionRangeProvider = /** @class */ (function () {
    function WordSelectionRangeProvider() {
    }
    WordSelectionRangeProvider.prototype.provideSelectionRanges = function (model, positions) {
        var result = [];
        for (var _i = 0, positions_1 = positions; _i < positions_1.length; _i++) {
            var position = positions_1[_i];
            var bucket = [];
            result.push(bucket);
            this._addInWordRanges(bucket, model, position);
            this._addWordRanges(bucket, model, position);
            this._addWhitespaceLine(bucket, model, position);
            bucket.push({ range: model.getFullModelRange() });
        }
        return result;
    };
    WordSelectionRangeProvider.prototype._addInWordRanges = function (bucket, model, pos) {
        var obj = model.getWordAtPosition(pos);
        if (!obj) {
            return;
        }
        var word = obj.word, startColumn = obj.startColumn;
        var offset = pos.column - startColumn;
        var start = offset;
        var end = offset;
        var lastCh = 0;
        // LEFT anchor (start)
        for (; start >= 0; start--) {
            var ch = word.charCodeAt(start);
            if (ch === 95 /* Underline */ || ch === 45 /* Dash */) {
                // foo-bar OR foo_bar
                break;
            }
            else if (isLowerAsciiLetter(ch) && isUpperAsciiLetter(lastCh)) {
                // fooBar
                break;
            }
            lastCh = ch;
        }
        start += 1;
        // RIGHT anchor (end)
        for (; end < word.length; end++) {
            var ch = word.charCodeAt(end);
            if (isUpperAsciiLetter(ch) && isLowerAsciiLetter(lastCh)) {
                // fooBar
                break;
            }
            else if (ch === 95 /* Underline */ || ch === 45 /* Dash */) {
                // foo-bar OR foo_bar
                break;
            }
            lastCh = ch;
        }
        if (start < end) {
            bucket.push({ range: new Range(pos.lineNumber, startColumn + start, pos.lineNumber, startColumn + end) });
        }
    };
    WordSelectionRangeProvider.prototype._addWordRanges = function (bucket, model, pos) {
        var word = model.getWordAtPosition(pos);
        if (word) {
            bucket.push({ range: new Range(pos.lineNumber, word.startColumn, pos.lineNumber, word.endColumn) });
        }
    };
    WordSelectionRangeProvider.prototype._addWhitespaceLine = function (bucket, model, pos) {
        if (model.getLineLength(pos.lineNumber) > 0
            && model.getLineFirstNonWhitespaceColumn(pos.lineNumber) === 0
            && model.getLineLastNonWhitespaceColumn(pos.lineNumber) === 0) {
            bucket.push({ range: new Range(pos.lineNumber, 1, pos.lineNumber, model.getLineMaxColumn(pos.lineNumber)) });
        }
    };
    return WordSelectionRangeProvider;
}());
export { WordSelectionRangeProvider };
