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
import { onUnexpectedError } from '../../../base/common/errors.js';
import * as strings from '../../../base/common/strings.js';
import { ReplaceCommand, ReplaceCommandWithOffsetCursorState, ReplaceCommandWithoutChangingPosition } from '../commands/replaceCommand.js';
import { ShiftCommand } from '../commands/shiftCommand.js';
import { SurroundSelectionCommand } from '../commands/surroundSelectionCommand.js';
import { CursorColumns, EditOperationResult, isQuote } from './cursorCommon.js';
import { getMapForWordSeparators } from './wordCharacterClassifier.js';
import { Range } from '../core/range.js';
import { IndentAction } from '../modes/languageConfiguration.js';
import { LanguageConfigurationRegistry } from '../modes/languageConfigurationRegistry.js';
var TypeOperations = /** @class */ (function () {
    function TypeOperations() {
    }
    TypeOperations.indent = function (config, model, selections) {
        if (model === null || selections === null) {
            return [];
        }
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = new ShiftCommand(selections[i], {
                isUnshift: false,
                tabSize: config.tabSize,
                indentSize: config.indentSize,
                insertSpaces: config.insertSpaces,
                useTabStops: config.useTabStops
            });
        }
        return commands;
    };
    TypeOperations.outdent = function (config, model, selections) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = new ShiftCommand(selections[i], {
                isUnshift: true,
                tabSize: config.tabSize,
                indentSize: config.indentSize,
                insertSpaces: config.insertSpaces,
                useTabStops: config.useTabStops
            });
        }
        return commands;
    };
    TypeOperations.shiftIndent = function (config, indentation, count) {
        count = count || 1;
        return ShiftCommand.shiftIndent(indentation, indentation.length + count, config.tabSize, config.indentSize, config.insertSpaces);
    };
    TypeOperations.unshiftIndent = function (config, indentation, count) {
        count = count || 1;
        return ShiftCommand.unshiftIndent(indentation, indentation.length + count, config.tabSize, config.indentSize, config.insertSpaces);
    };
    TypeOperations._distributedPaste = function (config, model, selections, text) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = new ReplaceCommand(selections[i], text[i]);
        }
        return new EditOperationResult(0 /* Other */, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    };
    TypeOperations._simplePaste = function (config, model, selections, text, pasteOnNewLine) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            var position = selection.getPosition();
            if (pasteOnNewLine && text.indexOf('\n') !== text.length - 1) {
                pasteOnNewLine = false;
            }
            if (pasteOnNewLine && selection.startLineNumber !== selection.endLineNumber) {
                pasteOnNewLine = false;
            }
            if (pasteOnNewLine && selection.startColumn === model.getLineMinColumn(selection.startLineNumber) && selection.endColumn === model.getLineMaxColumn(selection.startLineNumber)) {
                pasteOnNewLine = false;
            }
            if (pasteOnNewLine) {
                // Paste entire line at the beginning of line
                var typeSelection = new Range(position.lineNumber, 1, position.lineNumber, 1);
                commands[i] = new ReplaceCommand(typeSelection, text);
            }
            else {
                commands[i] = new ReplaceCommand(selection, text);
            }
        }
        return new EditOperationResult(0 /* Other */, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    };
    TypeOperations._distributePasteToCursors = function (selections, text, pasteOnNewLine, multicursorText) {
        if (pasteOnNewLine) {
            return null;
        }
        if (selections.length === 1) {
            return null;
        }
        if (multicursorText && multicursorText.length === selections.length) {
            return multicursorText;
        }
        // Remove trailing \n if present
        if (text.charCodeAt(text.length - 1) === 10 /* LineFeed */) {
            text = text.substr(0, text.length - 1);
        }
        var lines = text.split(/\r\n|\r|\n/);
        if (lines.length === selections.length) {
            return lines;
        }
        return null;
    };
    TypeOperations.paste = function (config, model, selections, text, pasteOnNewLine, multicursorText) {
        var distributedPaste = this._distributePasteToCursors(selections, text, pasteOnNewLine, multicursorText);
        if (distributedPaste) {
            selections = selections.sort(Range.compareRangesUsingStarts);
            return this._distributedPaste(config, model, selections, distributedPaste);
        }
        else {
            return this._simplePaste(config, model, selections, text, pasteOnNewLine);
        }
    };
    TypeOperations._goodIndentForLine = function (config, model, lineNumber) {
        var action = null;
        var indentation = '';
        var expectedIndentAction = config.autoIndent ? LanguageConfigurationRegistry.getInheritIndentForLine(model, lineNumber, false) : null;
        if (expectedIndentAction) {
            action = expectedIndentAction.action;
            indentation = expectedIndentAction.indentation;
        }
        else if (lineNumber > 1) {
            var lastLineNumber = void 0;
            for (lastLineNumber = lineNumber - 1; lastLineNumber >= 1; lastLineNumber--) {
                var lineText = model.getLineContent(lastLineNumber);
                var nonWhitespaceIdx = strings.lastNonWhitespaceIndex(lineText);
                if (nonWhitespaceIdx >= 0) {
                    break;
                }
            }
            if (lastLineNumber < 1) {
                // No previous line with content found
                return null;
            }
            var maxColumn = model.getLineMaxColumn(lastLineNumber);
            var expectedEnterAction = LanguageConfigurationRegistry.getEnterAction(model, new Range(lastLineNumber, maxColumn, lastLineNumber, maxColumn));
            if (expectedEnterAction) {
                indentation = expectedEnterAction.indentation;
                action = expectedEnterAction.enterAction;
                if (action) {
                    indentation += action.appendText;
                }
            }
        }
        if (action) {
            if (action === IndentAction.Indent) {
                indentation = TypeOperations.shiftIndent(config, indentation);
            }
            if (action === IndentAction.Outdent) {
                indentation = TypeOperations.unshiftIndent(config, indentation);
            }
            indentation = config.normalizeIndentation(indentation);
        }
        if (!indentation) {
            return null;
        }
        return indentation;
    };
    TypeOperations._replaceJumpToNextIndent = function (config, model, selection, insertsAutoWhitespace) {
        var typeText = '';
        var position = selection.getStartPosition();
        if (config.insertSpaces) {
            var visibleColumnFromColumn = CursorColumns.visibleColumnFromColumn2(config, model, position);
            var indentSize = config.indentSize;
            var spacesCnt = indentSize - (visibleColumnFromColumn % indentSize);
            for (var i = 0; i < spacesCnt; i++) {
                typeText += ' ';
            }
        }
        else {
            typeText = '\t';
        }
        return new ReplaceCommand(selection, typeText, insertsAutoWhitespace);
    };
    TypeOperations.tab = function (config, model, selections) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            if (selection.isEmpty()) {
                var lineText = model.getLineContent(selection.startLineNumber);
                if (/^\s*$/.test(lineText) && model.isCheapToTokenize(selection.startLineNumber)) {
                    var goodIndent = this._goodIndentForLine(config, model, selection.startLineNumber);
                    goodIndent = goodIndent || '\t';
                    var possibleTypeText = config.normalizeIndentation(goodIndent);
                    if (!strings.startsWith(lineText, possibleTypeText)) {
                        commands[i] = new ReplaceCommand(new Range(selection.startLineNumber, 1, selection.startLineNumber, lineText.length + 1), possibleTypeText, true);
                        continue;
                    }
                }
                commands[i] = this._replaceJumpToNextIndent(config, model, selection, true);
            }
            else {
                if (selection.startLineNumber === selection.endLineNumber) {
                    var lineMaxColumn = model.getLineMaxColumn(selection.startLineNumber);
                    if (selection.startColumn !== 1 || selection.endColumn !== lineMaxColumn) {
                        // This is a single line selection that is not the entire line
                        commands[i] = this._replaceJumpToNextIndent(config, model, selection, false);
                        continue;
                    }
                }
                commands[i] = new ShiftCommand(selection, {
                    isUnshift: false,
                    tabSize: config.tabSize,
                    indentSize: config.indentSize,
                    insertSpaces: config.insertSpaces,
                    useTabStops: config.useTabStops
                });
            }
        }
        return commands;
    };
    TypeOperations.replacePreviousChar = function (prevEditOperationType, config, model, selections, txt, replaceCharCnt) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            if (!selection.isEmpty()) {
                // looks like https://github.com/Microsoft/vscode/issues/2773
                // where a cursor operation occurred before a canceled composition
                // => ignore composition
                commands[i] = null;
                continue;
            }
            var pos = selection.getPosition();
            var startColumn = Math.max(1, pos.column - replaceCharCnt);
            var range = new Range(pos.lineNumber, startColumn, pos.lineNumber, pos.column);
            commands[i] = new ReplaceCommand(range, txt);
        }
        return new EditOperationResult(1 /* Typing */, commands, {
            shouldPushStackElementBefore: (prevEditOperationType !== 1 /* Typing */),
            shouldPushStackElementAfter: false
        });
    };
    TypeOperations._typeCommand = function (range, text, keepPosition) {
        if (keepPosition) {
            return new ReplaceCommandWithoutChangingPosition(range, text, true);
        }
        else {
            return new ReplaceCommand(range, text, true);
        }
    };
    TypeOperations._enter = function (config, model, keepPosition, range) {
        if (!model.isCheapToTokenize(range.getStartPosition().lineNumber)) {
            var lineText_1 = model.getLineContent(range.startLineNumber);
            var indentation_1 = strings.getLeadingWhitespace(lineText_1).substring(0, range.startColumn - 1);
            return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(indentation_1), keepPosition);
        }
        var r = LanguageConfigurationRegistry.getEnterAction(model, range);
        if (r) {
            var enterAction = r.enterAction;
            var indentation_2 = r.indentation;
            if (enterAction.indentAction === IndentAction.None) {
                // Nothing special
                return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(indentation_2 + enterAction.appendText), keepPosition);
            }
            else if (enterAction.indentAction === IndentAction.Indent) {
                // Indent once
                return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(indentation_2 + enterAction.appendText), keepPosition);
            }
            else if (enterAction.indentAction === IndentAction.IndentOutdent) {
                // Ultra special
                var normalIndent = config.normalizeIndentation(indentation_2);
                var increasedIndent = config.normalizeIndentation(indentation_2 + enterAction.appendText);
                var typeText = '\n' + increasedIndent + '\n' + normalIndent;
                if (keepPosition) {
                    return new ReplaceCommandWithoutChangingPosition(range, typeText, true);
                }
                else {
                    return new ReplaceCommandWithOffsetCursorState(range, typeText, -1, increasedIndent.length - normalIndent.length, true);
                }
            }
            else if (enterAction.indentAction === IndentAction.Outdent) {
                var actualIndentation = TypeOperations.unshiftIndent(config, indentation_2);
                return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(actualIndentation + enterAction.appendText), keepPosition);
            }
        }
        // no enter rules applied, we should check indentation rules then.
        if (!config.autoIndent) {
            // Nothing special
            var lineText_2 = model.getLineContent(range.startLineNumber);
            var indentation_3 = strings.getLeadingWhitespace(lineText_2).substring(0, range.startColumn - 1);
            return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(indentation_3), keepPosition);
        }
        var ir = LanguageConfigurationRegistry.getIndentForEnter(model, range, {
            unshiftIndent: function (indent) {
                return TypeOperations.unshiftIndent(config, indent);
            },
            shiftIndent: function (indent) {
                return TypeOperations.shiftIndent(config, indent);
            },
            normalizeIndentation: function (indent) {
                return config.normalizeIndentation(indent);
            }
        }, config.autoIndent);
        var lineText = model.getLineContent(range.startLineNumber);
        var indentation = strings.getLeadingWhitespace(lineText).substring(0, range.startColumn - 1);
        if (ir) {
            var oldEndViewColumn = CursorColumns.visibleColumnFromColumn2(config, model, range.getEndPosition());
            var oldEndColumn = range.endColumn;
            var beforeText = '\n';
            if (indentation !== config.normalizeIndentation(ir.beforeEnter)) {
                beforeText = config.normalizeIndentation(ir.beforeEnter) + lineText.substring(indentation.length, range.startColumn - 1) + '\n';
                range = new Range(range.startLineNumber, 1, range.endLineNumber, range.endColumn);
            }
            var newLineContent = model.getLineContent(range.endLineNumber);
            var firstNonWhitespace = strings.firstNonWhitespaceIndex(newLineContent);
            if (firstNonWhitespace >= 0) {
                range = range.setEndPosition(range.endLineNumber, Math.max(range.endColumn, firstNonWhitespace + 1));
            }
            else {
                range = range.setEndPosition(range.endLineNumber, model.getLineMaxColumn(range.endLineNumber));
            }
            if (keepPosition) {
                return new ReplaceCommandWithoutChangingPosition(range, beforeText + config.normalizeIndentation(ir.afterEnter), true);
            }
            else {
                var offset = 0;
                if (oldEndColumn <= firstNonWhitespace + 1) {
                    if (!config.insertSpaces) {
                        oldEndViewColumn = Math.ceil(oldEndViewColumn / config.indentSize);
                    }
                    offset = Math.min(oldEndViewColumn + 1 - config.normalizeIndentation(ir.afterEnter).length - 1, 0);
                }
                return new ReplaceCommandWithOffsetCursorState(range, beforeText + config.normalizeIndentation(ir.afterEnter), 0, offset, true);
            }
        }
        else {
            return TypeOperations._typeCommand(range, '\n' + config.normalizeIndentation(indentation), keepPosition);
        }
    };
    TypeOperations._isAutoIndentType = function (config, model, selections) {
        if (!config.autoIndent) {
            return false;
        }
        for (var i = 0, len = selections.length; i < len; i++) {
            if (!model.isCheapToTokenize(selections[i].getEndPosition().lineNumber)) {
                return false;
            }
        }
        return true;
    };
    TypeOperations._runAutoIndentType = function (config, model, range, ch) {
        var currentIndentation = LanguageConfigurationRegistry.getIndentationAtPosition(model, range.startLineNumber, range.startColumn);
        var actualIndentation = LanguageConfigurationRegistry.getIndentActionForType(model, range, ch, {
            shiftIndent: function (indentation) {
                return TypeOperations.shiftIndent(config, indentation);
            },
            unshiftIndent: function (indentation) {
                return TypeOperations.unshiftIndent(config, indentation);
            },
        });
        if (actualIndentation === null) {
            return null;
        }
        if (actualIndentation !== config.normalizeIndentation(currentIndentation)) {
            var firstNonWhitespace = model.getLineFirstNonWhitespaceColumn(range.startLineNumber);
            if (firstNonWhitespace === 0) {
                return TypeOperations._typeCommand(new Range(range.startLineNumber, 0, range.endLineNumber, range.endColumn), config.normalizeIndentation(actualIndentation) + ch, false);
            }
            else {
                return TypeOperations._typeCommand(new Range(range.startLineNumber, 0, range.endLineNumber, range.endColumn), config.normalizeIndentation(actualIndentation) +
                    model.getLineContent(range.startLineNumber).substring(firstNonWhitespace - 1, range.startColumn - 1) + ch, false);
            }
        }
        return null;
    };
    TypeOperations._isAutoClosingOvertype = function (config, model, selections, autoClosedCharacters, ch) {
        if (config.autoClosingOvertype === 'never') {
            return false;
        }
        if (!config.autoClosingPairsClose2.has(ch)) {
            return false;
        }
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            if (!selection.isEmpty()) {
                return false;
            }
            var position = selection.getPosition();
            var lineText = model.getLineContent(position.lineNumber);
            var afterCharacter = lineText.charAt(position.column - 1);
            if (afterCharacter !== ch) {
                return false;
            }
            // Must over-type a closing character typed by the editor
            if (config.autoClosingOvertype === 'auto') {
                var found = false;
                for (var j = 0, lenJ = autoClosedCharacters.length; j < lenJ; j++) {
                    var autoClosedCharacter = autoClosedCharacters[j];
                    if (position.lineNumber === autoClosedCharacter.startLineNumber && position.column === autoClosedCharacter.startColumn) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    return false;
                }
            }
        }
        return true;
    };
    TypeOperations._runAutoClosingOvertype = function (prevEditOperationType, config, model, selections, ch) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            var position = selection.getPosition();
            var typeSelection = new Range(position.lineNumber, position.column, position.lineNumber, position.column + 1);
            commands[i] = new ReplaceCommand(typeSelection, ch);
        }
        return new EditOperationResult(1 /* Typing */, commands, {
            shouldPushStackElementBefore: (prevEditOperationType !== 1 /* Typing */),
            shouldPushStackElementAfter: false
        });
    };
    TypeOperations._isBeforeClosingBrace = function (config, autoClosingPair, characterAfter) {
        var otherAutoClosingPairs = config.autoClosingPairsClose2.get(characterAfter);
        if (!otherAutoClosingPairs) {
            return false;
        }
        var thisBraceIsSymmetric = (autoClosingPair.open === autoClosingPair.close);
        for (var _i = 0, otherAutoClosingPairs_1 = otherAutoClosingPairs; _i < otherAutoClosingPairs_1.length; _i++) {
            var otherAutoClosingPair = otherAutoClosingPairs_1[_i];
            var otherBraceIsSymmetric = (otherAutoClosingPair.open === otherAutoClosingPair.close);
            if (!thisBraceIsSymmetric && otherBraceIsSymmetric) {
                continue;
            }
            return true;
        }
        return false;
    };
    TypeOperations._findAutoClosingPairOpen = function (config, model, positions, ch) {
        var autoClosingPairCandidates = config.autoClosingPairsOpen2.get(ch);
        if (!autoClosingPairCandidates) {
            return null;
        }
        // Determine which auto-closing pair it is
        var autoClosingPair = null;
        for (var _i = 0, autoClosingPairCandidates_1 = autoClosingPairCandidates; _i < autoClosingPairCandidates_1.length; _i++) {
            var autoClosingPairCandidate = autoClosingPairCandidates_1[_i];
            if (autoClosingPair === null || autoClosingPairCandidate.open.length > autoClosingPair.open.length) {
                var candidateIsMatch = true;
                for (var _a = 0, positions_1 = positions; _a < positions_1.length; _a++) {
                    var position = positions_1[_a];
                    var relevantText = model.getValueInRange(new Range(position.lineNumber, position.column - autoClosingPairCandidate.open.length + 1, position.lineNumber, position.column));
                    if (relevantText + ch !== autoClosingPairCandidate.open) {
                        candidateIsMatch = false;
                        break;
                    }
                }
                if (candidateIsMatch) {
                    autoClosingPair = autoClosingPairCandidate;
                }
            }
        }
        return autoClosingPair;
    };
    TypeOperations._isAutoClosingOpenCharType = function (config, model, selections, ch, insertOpenCharacter) {
        var chIsQuote = isQuote(ch);
        var autoCloseConfig = chIsQuote ? config.autoClosingQuotes : config.autoClosingBrackets;
        if (autoCloseConfig === 'never') {
            return null;
        }
        var autoClosingPair = this._findAutoClosingPairOpen(config, model, selections.map(function (s) { return s.getPosition(); }), ch);
        if (!autoClosingPair) {
            return null;
        }
        var shouldAutoCloseBefore = chIsQuote ? config.shouldAutoCloseBefore.quote : config.shouldAutoCloseBefore.bracket;
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            if (!selection.isEmpty()) {
                return null;
            }
            var position = selection.getPosition();
            var lineText = model.getLineContent(position.lineNumber);
            // Only consider auto closing the pair if a space follows or if another autoclosed pair follows
            if (lineText.length > position.column - 1) {
                var characterAfter = lineText.charAt(position.column - 1);
                var isBeforeCloseBrace = TypeOperations._isBeforeClosingBrace(config, autoClosingPair, characterAfter);
                if (!isBeforeCloseBrace && !shouldAutoCloseBefore(characterAfter)) {
                    return null;
                }
            }
            if (!model.isCheapToTokenize(position.lineNumber)) {
                // Do not force tokenization
                return null;
            }
            // Do not auto-close ' or " after a word character
            if (autoClosingPair.open.length === 1 && chIsQuote && autoCloseConfig !== 'always') {
                var wordSeparators = getMapForWordSeparators(config.wordSeparators);
                if (insertOpenCharacter && position.column > 1 && wordSeparators.get(lineText.charCodeAt(position.column - 2)) === 0 /* Regular */) {
                    return null;
                }
                if (!insertOpenCharacter && position.column > 2 && wordSeparators.get(lineText.charCodeAt(position.column - 3)) === 0 /* Regular */) {
                    return null;
                }
            }
            model.forceTokenization(position.lineNumber);
            var lineTokens = model.getLineTokens(position.lineNumber);
            var shouldAutoClosePair = false;
            try {
                shouldAutoClosePair = LanguageConfigurationRegistry.shouldAutoClosePair(autoClosingPair, lineTokens, insertOpenCharacter ? position.column : position.column - 1);
            }
            catch (e) {
                onUnexpectedError(e);
            }
            if (!shouldAutoClosePair) {
                return null;
            }
        }
        return autoClosingPair;
    };
    TypeOperations._runAutoClosingOpenCharType = function (prevEditOperationType, config, model, selections, ch, insertOpenCharacter, autoClosingPair) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            commands[i] = new TypeWithAutoClosingCommand(selection, ch, insertOpenCharacter, autoClosingPair.close);
        }
        return new EditOperationResult(1 /* Typing */, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: false
        });
    };
    TypeOperations._shouldSurroundChar = function (config, ch) {
        if (isQuote(ch)) {
            return (config.autoSurround === 'quotes' || config.autoSurround === 'languageDefined');
        }
        else {
            // Character is a bracket
            return (config.autoSurround === 'brackets' || config.autoSurround === 'languageDefined');
        }
    };
    TypeOperations._isSurroundSelectionType = function (config, model, selections, ch) {
        if (!TypeOperations._shouldSurroundChar(config, ch) || !config.surroundingPairs.hasOwnProperty(ch)) {
            return false;
        }
        var isTypingAQuoteCharacter = isQuote(ch);
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            if (selection.isEmpty()) {
                return false;
            }
            var selectionContainsOnlyWhitespace = true;
            for (var lineNumber = selection.startLineNumber; lineNumber <= selection.endLineNumber; lineNumber++) {
                var lineText = model.getLineContent(lineNumber);
                var startIndex = (lineNumber === selection.startLineNumber ? selection.startColumn - 1 : 0);
                var endIndex = (lineNumber === selection.endLineNumber ? selection.endColumn - 1 : lineText.length);
                var selectedText = lineText.substring(startIndex, endIndex);
                if (/[^ \t]/.test(selectedText)) {
                    // this selected text contains something other than whitespace
                    selectionContainsOnlyWhitespace = false;
                    break;
                }
            }
            if (selectionContainsOnlyWhitespace) {
                return false;
            }
            if (isTypingAQuoteCharacter && selection.startLineNumber === selection.endLineNumber && selection.startColumn + 1 === selection.endColumn) {
                var selectionText = model.getValueInRange(selection);
                if (isQuote(selectionText)) {
                    // Typing a quote character on top of another quote character
                    // => disable surround selection type
                    return false;
                }
            }
        }
        return true;
    };
    TypeOperations._runSurroundSelectionType = function (prevEditOperationType, config, model, selections, ch) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var selection = selections[i];
            var closeCharacter = config.surroundingPairs[ch];
            commands[i] = new SurroundSelectionCommand(selection, ch, closeCharacter);
        }
        return new EditOperationResult(0 /* Other */, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    };
    TypeOperations._isTypeInterceptorElectricChar = function (config, model, selections) {
        if (selections.length === 1 && model.isCheapToTokenize(selections[0].getEndPosition().lineNumber)) {
            return true;
        }
        return false;
    };
    TypeOperations._typeInterceptorElectricChar = function (prevEditOperationType, config, model, selection, ch) {
        if (!config.electricChars.hasOwnProperty(ch) || !selection.isEmpty()) {
            return null;
        }
        var position = selection.getPosition();
        model.forceTokenization(position.lineNumber);
        var lineTokens = model.getLineTokens(position.lineNumber);
        var electricAction;
        try {
            electricAction = LanguageConfigurationRegistry.onElectricCharacter(ch, lineTokens, position.column);
        }
        catch (e) {
            onUnexpectedError(e);
            return null;
        }
        if (!electricAction) {
            return null;
        }
        if (electricAction.matchOpenBracket) {
            var endColumn = (lineTokens.getLineContent() + ch).lastIndexOf(electricAction.matchOpenBracket) + 1;
            var match = model.findMatchingBracketUp(electricAction.matchOpenBracket, {
                lineNumber: position.lineNumber,
                column: endColumn
            });
            if (match) {
                if (match.startLineNumber === position.lineNumber) {
                    // matched something on the same line => no change in indentation
                    return null;
                }
                var matchLine = model.getLineContent(match.startLineNumber);
                var matchLineIndentation = strings.getLeadingWhitespace(matchLine);
                var newIndentation = config.normalizeIndentation(matchLineIndentation);
                var lineText = model.getLineContent(position.lineNumber);
                var lineFirstNonBlankColumn = model.getLineFirstNonWhitespaceColumn(position.lineNumber) || position.column;
                var prefix = lineText.substring(lineFirstNonBlankColumn - 1, position.column - 1);
                var typeText = newIndentation + prefix + ch;
                var typeSelection = new Range(position.lineNumber, 1, position.lineNumber, position.column);
                var command = new ReplaceCommand(typeSelection, typeText);
                return new EditOperationResult(1 /* Typing */, [command], {
                    shouldPushStackElementBefore: false,
                    shouldPushStackElementAfter: true
                });
            }
        }
        return null;
    };
    /**
     * This is very similar with typing, but the character is already in the text buffer!
     */
    TypeOperations.compositionEndWithInterceptors = function (prevEditOperationType, config, model, selections, autoClosedCharacters) {
        var ch = null;
        // extract last typed character
        for (var _i = 0, selections_1 = selections; _i < selections_1.length; _i++) {
            var selection = selections_1[_i];
            if (!selection.isEmpty()) {
                return null;
            }
            var position = selection.getPosition();
            var currentChar = model.getValueInRange(new Range(position.lineNumber, position.column - 1, position.lineNumber, position.column));
            if (ch === null) {
                ch = currentChar;
            }
            else if (ch !== currentChar) {
                return null;
            }
        }
        if (!ch) {
            return null;
        }
        if (this._isAutoClosingOvertype(config, model, selections, autoClosedCharacters, ch)) {
            // Unfortunately, the close character is at this point "doubled", so we need to delete it...
            var commands = selections.map(function (s) { return new ReplaceCommand(new Range(s.positionLineNumber, s.positionColumn, s.positionLineNumber, s.positionColumn + 1), '', false); });
            return new EditOperationResult(1 /* Typing */, commands, {
                shouldPushStackElementBefore: true,
                shouldPushStackElementAfter: false
            });
        }
        var autoClosingPairOpenCharType = this._isAutoClosingOpenCharType(config, model, selections, ch, false);
        if (autoClosingPairOpenCharType) {
            return this._runAutoClosingOpenCharType(prevEditOperationType, config, model, selections, ch, false, autoClosingPairOpenCharType);
        }
        return null;
    };
    TypeOperations.typeWithInterceptors = function (prevEditOperationType, config, model, selections, autoClosedCharacters, ch) {
        if (ch === '\n') {
            var commands_1 = [];
            for (var i = 0, len = selections.length; i < len; i++) {
                commands_1[i] = TypeOperations._enter(config, model, false, selections[i]);
            }
            return new EditOperationResult(1 /* Typing */, commands_1, {
                shouldPushStackElementBefore: true,
                shouldPushStackElementAfter: false,
            });
        }
        if (this._isAutoIndentType(config, model, selections)) {
            var commands_2 = [];
            var autoIndentFails = false;
            for (var i = 0, len = selections.length; i < len; i++) {
                commands_2[i] = this._runAutoIndentType(config, model, selections[i], ch);
                if (!commands_2[i]) {
                    autoIndentFails = true;
                    break;
                }
            }
            if (!autoIndentFails) {
                return new EditOperationResult(1 /* Typing */, commands_2, {
                    shouldPushStackElementBefore: true,
                    shouldPushStackElementAfter: false,
                });
            }
        }
        if (this._isAutoClosingOvertype(config, model, selections, autoClosedCharacters, ch)) {
            return this._runAutoClosingOvertype(prevEditOperationType, config, model, selections, ch);
        }
        var autoClosingPairOpenCharType = this._isAutoClosingOpenCharType(config, model, selections, ch, true);
        if (autoClosingPairOpenCharType) {
            return this._runAutoClosingOpenCharType(prevEditOperationType, config, model, selections, ch, true, autoClosingPairOpenCharType);
        }
        if (this._isSurroundSelectionType(config, model, selections, ch)) {
            return this._runSurroundSelectionType(prevEditOperationType, config, model, selections, ch);
        }
        // Electric characters make sense only when dealing with a single cursor,
        // as multiple cursors typing brackets for example would interfer with bracket matching
        if (this._isTypeInterceptorElectricChar(config, model, selections)) {
            var r = this._typeInterceptorElectricChar(prevEditOperationType, config, model, selections[0], ch);
            if (r) {
                return r;
            }
        }
        // A simple character type
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = new ReplaceCommand(selections[i], ch);
        }
        var shouldPushStackElementBefore = (prevEditOperationType !== 1 /* Typing */);
        if (ch === ' ') {
            shouldPushStackElementBefore = true;
        }
        return new EditOperationResult(1 /* Typing */, commands, {
            shouldPushStackElementBefore: shouldPushStackElementBefore,
            shouldPushStackElementAfter: false
        });
    };
    TypeOperations.typeWithoutInterceptors = function (prevEditOperationType, config, model, selections, str) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = new ReplaceCommand(selections[i], str);
        }
        return new EditOperationResult(1 /* Typing */, commands, {
            shouldPushStackElementBefore: (prevEditOperationType !== 1 /* Typing */),
            shouldPushStackElementAfter: false
        });
    };
    TypeOperations.lineInsertBefore = function (config, model, selections) {
        if (model === null || selections === null) {
            return [];
        }
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var lineNumber = selections[i].positionLineNumber;
            if (lineNumber === 1) {
                commands[i] = new ReplaceCommandWithoutChangingPosition(new Range(1, 1, 1, 1), '\n');
            }
            else {
                lineNumber--;
                var column = model.getLineMaxColumn(lineNumber);
                commands[i] = this._enter(config, model, false, new Range(lineNumber, column, lineNumber, column));
            }
        }
        return commands;
    };
    TypeOperations.lineInsertAfter = function (config, model, selections) {
        if (model === null || selections === null) {
            return [];
        }
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            var lineNumber = selections[i].positionLineNumber;
            var column = model.getLineMaxColumn(lineNumber);
            commands[i] = this._enter(config, model, false, new Range(lineNumber, column, lineNumber, column));
        }
        return commands;
    };
    TypeOperations.lineBreakInsert = function (config, model, selections) {
        var commands = [];
        for (var i = 0, len = selections.length; i < len; i++) {
            commands[i] = this._enter(config, model, true, selections[i]);
        }
        return commands;
    };
    return TypeOperations;
}());
export { TypeOperations };
var TypeWithAutoClosingCommand = /** @class */ (function (_super) {
    __extends(TypeWithAutoClosingCommand, _super);
    function TypeWithAutoClosingCommand(selection, openCharacter, insertOpenCharacter, closeCharacter) {
        var _this = _super.call(this, selection, (insertOpenCharacter ? openCharacter : '') + closeCharacter, 0, -closeCharacter.length) || this;
        _this._openCharacter = openCharacter;
        _this._closeCharacter = closeCharacter;
        _this.closeCharacterRange = null;
        _this.enclosingRange = null;
        return _this;
    }
    TypeWithAutoClosingCommand.prototype.computeCursorState = function (model, helper) {
        var inverseEditOperations = helper.getInverseEditOperations();
        var range = inverseEditOperations[0].range;
        this.closeCharacterRange = new Range(range.startLineNumber, range.endColumn - this._closeCharacter.length, range.endLineNumber, range.endColumn);
        this.enclosingRange = new Range(range.startLineNumber, range.endColumn - this._openCharacter.length - this._closeCharacter.length, range.endLineNumber, range.endColumn);
        return _super.prototype.computeCursorState.call(this, model, helper);
    };
    return TypeWithAutoClosingCommand;
}(ReplaceCommandWithOffsetCursorState));
export { TypeWithAutoClosingCommand };
