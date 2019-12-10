/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as strings from '../../../base/common/strings.js';
import { CursorColumns } from '../controller/cursorCommon.js';
import { Range } from '../core/range.js';
import { Selection } from '../core/selection.js';
import { LanguageConfigurationRegistry } from '../modes/languageConfigurationRegistry.js';
var repeatCache = Object.create(null);
export function cachedStringRepeat(str, count) {
    if (!repeatCache[str]) {
        repeatCache[str] = ['', str];
    }
    var cache = repeatCache[str];
    for (var i = cache.length; i <= count; i++) {
        cache[i] = cache[i - 1] + str;
    }
    return cache[count];
}
var ShiftCommand = /** @class */ (function () {
    function ShiftCommand(range, opts) {
        this._opts = opts;
        this._selection = range;
        this._selectionId = null;
        this._useLastEditRangeForCursorEndPosition = false;
        this._selectionStartColumnStaysPut = false;
    }
    ShiftCommand.unshiftIndent = function (line, column, tabSize, indentSize, insertSpaces) {
        // Determine the visible column where the content starts
        var contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(line, column, tabSize);
        if (insertSpaces) {
            var indent = cachedStringRepeat(' ', indentSize);
            var desiredTabStop = CursorColumns.prevIndentTabStop(contentStartVisibleColumn, indentSize);
            var indentCount = desiredTabStop / indentSize; // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
        else {
            var indent = '\t';
            var desiredTabStop = CursorColumns.prevRenderTabStop(contentStartVisibleColumn, tabSize);
            var indentCount = desiredTabStop / tabSize; // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
    };
    ShiftCommand.shiftIndent = function (line, column, tabSize, indentSize, insertSpaces) {
        // Determine the visible column where the content starts
        var contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(line, column, tabSize);
        if (insertSpaces) {
            var indent = cachedStringRepeat(' ', indentSize);
            var desiredTabStop = CursorColumns.nextIndentTabStop(contentStartVisibleColumn, indentSize);
            var indentCount = desiredTabStop / indentSize; // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
        else {
            var indent = '\t';
            var desiredTabStop = CursorColumns.nextRenderTabStop(contentStartVisibleColumn, tabSize);
            var indentCount = desiredTabStop / tabSize; // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
    };
    ShiftCommand.prototype._addEditOperation = function (builder, range, text) {
        if (this._useLastEditRangeForCursorEndPosition) {
            builder.addTrackedEditOperation(range, text);
        }
        else {
            builder.addEditOperation(range, text);
        }
    };
    ShiftCommand.prototype.getEditOperations = function (model, builder) {
        var startLine = this._selection.startLineNumber;
        var endLine = this._selection.endLineNumber;
        if (this._selection.endColumn === 1 && startLine !== endLine) {
            endLine = endLine - 1;
        }
        var _a = this._opts, tabSize = _a.tabSize, indentSize = _a.indentSize, insertSpaces = _a.insertSpaces;
        var shouldIndentEmptyLines = (startLine === endLine);
        // if indenting or outdenting on a whitespace only line
        if (this._selection.isEmpty()) {
            if (/^\s*$/.test(model.getLineContent(startLine))) {
                this._useLastEditRangeForCursorEndPosition = true;
            }
        }
        if (this._opts.useTabStops) {
            // keep track of previous line's "miss-alignment"
            var previousLineExtraSpaces = 0, extraSpaces = 0;
            for (var lineNumber = startLine; lineNumber <= endLine; lineNumber++, previousLineExtraSpaces = extraSpaces) {
                extraSpaces = 0;
                var lineText = model.getLineContent(lineNumber);
                var indentationEndIndex = strings.firstNonWhitespaceIndex(lineText);
                if (this._opts.isUnshift && (lineText.length === 0 || indentationEndIndex === 0)) {
                    // empty line or line with no leading whitespace => nothing to do
                    continue;
                }
                if (!shouldIndentEmptyLines && !this._opts.isUnshift && lineText.length === 0) {
                    // do not indent empty lines => nothing to do
                    continue;
                }
                if (indentationEndIndex === -1) {
                    // the entire line is whitespace
                    indentationEndIndex = lineText.length;
                }
                if (lineNumber > 1) {
                    var contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(lineText, indentationEndIndex + 1, tabSize);
                    if (contentStartVisibleColumn % indentSize !== 0) {
                        // The current line is "miss-aligned", so let's see if this is expected...
                        // This can only happen when it has trailing commas in the indent
                        if (model.isCheapToTokenize(lineNumber - 1)) {
                            var enterAction = LanguageConfigurationRegistry.getRawEnterActionAtPosition(model, lineNumber - 1, model.getLineMaxColumn(lineNumber - 1));
                            if (enterAction) {
                                extraSpaces = previousLineExtraSpaces;
                                if (enterAction.appendText) {
                                    for (var j = 0, lenJ = enterAction.appendText.length; j < lenJ && extraSpaces < indentSize; j++) {
                                        if (enterAction.appendText.charCodeAt(j) === 32 /* Space */) {
                                            extraSpaces++;
                                        }
                                        else {
                                            break;
                                        }
                                    }
                                }
                                if (enterAction.removeText) {
                                    extraSpaces = Math.max(0, extraSpaces - enterAction.removeText);
                                }
                                // Act as if `prefixSpaces` is not part of the indentation
                                for (var j = 0; j < extraSpaces; j++) {
                                    if (indentationEndIndex === 0 || lineText.charCodeAt(indentationEndIndex - 1) !== 32 /* Space */) {
                                        break;
                                    }
                                    indentationEndIndex--;
                                }
                            }
                        }
                    }
                }
                if (this._opts.isUnshift && indentationEndIndex === 0) {
                    // line with no leading whitespace => nothing to do
                    continue;
                }
                var desiredIndent = void 0;
                if (this._opts.isUnshift) {
                    desiredIndent = ShiftCommand.unshiftIndent(lineText, indentationEndIndex + 1, tabSize, indentSize, insertSpaces);
                }
                else {
                    desiredIndent = ShiftCommand.shiftIndent(lineText, indentationEndIndex + 1, tabSize, indentSize, insertSpaces);
                }
                this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, indentationEndIndex + 1), desiredIndent);
                if (lineNumber === startLine) {
                    // Force the startColumn to stay put because we're inserting after it
                    this._selectionStartColumnStaysPut = (this._selection.startColumn <= indentationEndIndex + 1);
                }
            }
        }
        else {
            var oneIndent = (insertSpaces ? cachedStringRepeat(' ', indentSize) : '\t');
            for (var lineNumber = startLine; lineNumber <= endLine; lineNumber++) {
                var lineText = model.getLineContent(lineNumber);
                var indentationEndIndex = strings.firstNonWhitespaceIndex(lineText);
                if (this._opts.isUnshift && (lineText.length === 0 || indentationEndIndex === 0)) {
                    // empty line or line with no leading whitespace => nothing to do
                    continue;
                }
                if (!shouldIndentEmptyLines && !this._opts.isUnshift && lineText.length === 0) {
                    // do not indent empty lines => nothing to do
                    continue;
                }
                if (indentationEndIndex === -1) {
                    // the entire line is whitespace
                    indentationEndIndex = lineText.length;
                }
                if (this._opts.isUnshift && indentationEndIndex === 0) {
                    // line with no leading whitespace => nothing to do
                    continue;
                }
                if (this._opts.isUnshift) {
                    indentationEndIndex = Math.min(indentationEndIndex, indentSize);
                    for (var i = 0; i < indentationEndIndex; i++) {
                        var chr = lineText.charCodeAt(i);
                        if (chr === 9 /* Tab */) {
                            indentationEndIndex = i + 1;
                            break;
                        }
                    }
                    this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, indentationEndIndex + 1), '');
                }
                else {
                    this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, 1), oneIndent);
                    if (lineNumber === startLine) {
                        // Force the startColumn to stay put because we're inserting after it
                        this._selectionStartColumnStaysPut = (this._selection.startColumn === 1);
                    }
                }
            }
        }
        this._selectionId = builder.trackSelection(this._selection);
    };
    ShiftCommand.prototype.computeCursorState = function (model, helper) {
        if (this._useLastEditRangeForCursorEndPosition) {
            var lastOp = helper.getInverseEditOperations()[0];
            return new Selection(lastOp.range.endLineNumber, lastOp.range.endColumn, lastOp.range.endLineNumber, lastOp.range.endColumn);
        }
        var result = helper.getTrackedSelection(this._selectionId);
        if (this._selectionStartColumnStaysPut) {
            // The selection start should not move
            var initialStartColumn = this._selection.startColumn;
            var resultStartColumn = result.startColumn;
            if (resultStartColumn <= initialStartColumn) {
                return result;
            }
            if (result.getDirection() === 0 /* LTR */) {
                return new Selection(result.startLineNumber, initialStartColumn, result.endLineNumber, result.endColumn);
            }
            return new Selection(result.endLineNumber, result.endColumn, result.startLineNumber, initialStartColumn);
        }
        return result;
    };
    return ShiftCommand;
}());
export { ShiftCommand };
