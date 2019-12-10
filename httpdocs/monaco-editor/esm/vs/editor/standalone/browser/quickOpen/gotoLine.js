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
import './gotoLine.css';
import * as strings from '../../../../base/common/strings.js';
import { QuickOpenEntry, QuickOpenModel } from '../../../../base/parts/quickopen/browser/quickOpenModel.js';
import { isCodeEditor } from '../../../browser/editorBrowser.js';
import { registerEditorAction } from '../../../browser/editorExtensions.js';
import { Position } from '../../../common/core/position.js';
import { Range } from '../../../common/core/range.js';
import { EditorContextKeys } from '../../../common/editorContextKeys.js';
import { BaseEditorQuickOpenAction } from './editorQuickOpen.js';
import { GoToLineNLS } from '../../../common/standaloneStrings.js';
var GotoLineEntry = /** @class */ (function (_super) {
    __extends(GotoLineEntry, _super);
    function GotoLineEntry(line, editor, decorator) {
        var _this = _super.call(this) || this;
        _this.editor = editor;
        _this.decorator = decorator;
        _this.parseResult = _this.parseInput(line);
        return _this;
    }
    GotoLineEntry.prototype.parseInput = function (line) {
        var numbers = line.split(',').map(function (part) { return parseInt(part, 10); }).filter(function (part) { return !isNaN(part); });
        var position;
        if (numbers.length === 0) {
            position = new Position(-1, -1);
        }
        else if (numbers.length === 1) {
            position = new Position(numbers[0], 1);
        }
        else {
            position = new Position(numbers[0], numbers[1]);
        }
        var model;
        if (isCodeEditor(this.editor)) {
            model = this.editor.getModel();
        }
        else {
            var diffModel = this.editor.getModel();
            model = diffModel ? diffModel.modified : null;
        }
        var isValid = model ? model.validatePosition(position).equals(position) : false;
        var label;
        if (isValid) {
            if (position.column && position.column > 1) {
                label = strings.format(GoToLineNLS.gotoLineLabelValidLineAndColumn, position.lineNumber, position.column);
            }
            else {
                label = strings.format(GoToLineNLS.gotoLineLabelValidLine, position.lineNumber);
            }
        }
        else if (position.lineNumber < 1 || position.lineNumber > (model ? model.getLineCount() : 0)) {
            label = strings.format(GoToLineNLS.gotoLineLabelEmptyWithLineLimit, model ? model.getLineCount() : 0);
        }
        else {
            label = strings.format(GoToLineNLS.gotoLineLabelEmptyWithLineAndColumnLimit, model ? model.getLineMaxColumn(position.lineNumber) : 0);
        }
        return {
            position: position,
            isValid: isValid,
            label: label
        };
    };
    GotoLineEntry.prototype.getLabel = function () {
        return this.parseResult.label;
    };
    GotoLineEntry.prototype.getAriaLabel = function () {
        var position = this.editor.getPosition();
        var currentLine = position ? position.lineNumber : 0;
        return strings.format(GoToLineNLS.gotoLineAriaLabel, currentLine, this.parseResult.label);
    };
    GotoLineEntry.prototype.run = function (mode, _context) {
        if (mode === 1 /* OPEN */) {
            return this.runOpen();
        }
        return this.runPreview();
    };
    GotoLineEntry.prototype.runOpen = function () {
        // No-op if range is not valid
        if (!this.parseResult.isValid) {
            return false;
        }
        // Apply selection and focus
        var range = this.toSelection();
        this.editor.setSelection(range);
        this.editor.revealRangeInCenter(range, 0 /* Smooth */);
        this.editor.focus();
        return true;
    };
    GotoLineEntry.prototype.runPreview = function () {
        // No-op if range is not valid
        if (!this.parseResult.isValid) {
            this.decorator.clearDecorations();
            return false;
        }
        // Select Line Position
        var range = this.toSelection();
        this.editor.revealRangeInCenter(range, 0 /* Smooth */);
        // Decorate if possible
        this.decorator.decorateLine(range, this.editor);
        return false;
    };
    GotoLineEntry.prototype.toSelection = function () {
        return new Range(this.parseResult.position.lineNumber, this.parseResult.position.column, this.parseResult.position.lineNumber, this.parseResult.position.column);
    };
    return GotoLineEntry;
}(QuickOpenEntry));
export { GotoLineEntry };
var GotoLineAction = /** @class */ (function (_super) {
    __extends(GotoLineAction, _super);
    function GotoLineAction() {
        return _super.call(this, GoToLineNLS.gotoLineActionInput, {
            id: 'editor.action.gotoLine',
            label: GoToLineNLS.gotoLineActionLabel,
            alias: 'Go to Line...',
            precondition: undefined,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: 2048 /* CtrlCmd */ | 37 /* KEY_G */,
                mac: { primary: 256 /* WinCtrl */ | 37 /* KEY_G */ },
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    GotoLineAction.prototype.run = function (accessor, editor) {
        var _this = this;
        this._show(this.getController(editor), {
            getModel: function (value) {
                return new QuickOpenModel([new GotoLineEntry(value, editor, _this.getController(editor))]);
            },
            getAutoFocus: function (searchValue) {
                return {
                    autoFocusFirstEntry: searchValue.length > 0
                };
            }
        });
    };
    return GotoLineAction;
}(BaseEditorQuickOpenAction));
export { GotoLineAction };
registerEditorAction(GotoLineAction);
