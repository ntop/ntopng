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
import * as arrays from '../../../base/common/arrays.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { EditorAction, registerEditorAction, registerEditorContribution, registerDefaultLanguageCommand } from '../../browser/editorExtensions.js';
import { Position } from '../../common/core/position.js';
import { Range } from '../../common/core/range.js';
import { Selection } from '../../common/core/selection.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import * as modes from '../../common/modes.js';
import * as nls from '../../../nls.js';
import { dispose } from '../../../base/common/lifecycle.js';
import { WordSelectionRangeProvider } from './wordSelections.js';
import { BracketSelectionRangeProvider } from './bracketSelections.js';
import { CommandsRegistry } from '../../../platform/commands/common/commands.js';
import { onUnexpectedExternalError } from '../../../base/common/errors.js';
var SelectionRanges = /** @class */ (function () {
    function SelectionRanges(index, ranges) {
        this.index = index;
        this.ranges = ranges;
    }
    SelectionRanges.prototype.mov = function (fwd) {
        var index = this.index + (fwd ? 1 : -1);
        if (index < 0 || index >= this.ranges.length) {
            return this;
        }
        var res = new SelectionRanges(index, this.ranges);
        if (res.ranges[index].equalsRange(this.ranges[this.index])) {
            // next range equals this range, retry with next-next
            return res.mov(fwd);
        }
        return res;
    };
    return SelectionRanges;
}());
var SmartSelectController = /** @class */ (function () {
    function SmartSelectController(editor) {
        this._ignoreSelection = false;
        this._editor = editor;
    }
    SmartSelectController.get = function (editor) {
        return editor.getContribution(SmartSelectController._id);
    };
    SmartSelectController.prototype.dispose = function () {
        dispose(this._selectionListener);
    };
    SmartSelectController.prototype.getId = function () {
        return SmartSelectController._id;
    };
    SmartSelectController.prototype.run = function (forward) {
        var _this = this;
        if (!this._editor.hasModel()) {
            return;
        }
        var selections = this._editor.getSelections();
        var model = this._editor.getModel();
        if (!modes.SelectionRangeRegistry.has(model)) {
            return;
        }
        var promise = Promise.resolve(undefined);
        if (!this._state) {
            promise = provideSelectionRanges(model, selections.map(function (s) { return s.getPosition(); }), CancellationToken.None).then(function (ranges) {
                if (!arrays.isNonEmptyArray(ranges) || ranges.length !== selections.length) {
                    // invalid result
                    return;
                }
                if (!_this._editor.hasModel() || !arrays.equals(_this._editor.getSelections(), selections, function (a, b) { return a.equalsSelection(b); })) {
                    // invalid editor state
                    return;
                }
                var _loop_1 = function (i) {
                    ranges[i] = ranges[i].filter(function (range) {
                        // filter ranges inside the selection
                        return range.containsPosition(selections[i].getStartPosition()) && range.containsPosition(selections[i].getEndPosition());
                    });
                    // prepend current selection
                    ranges[i].unshift(selections[i]);
                };
                for (var i = 0; i < ranges.length; i++) {
                    _loop_1(i);
                }
                _this._state = ranges.map(function (ranges) { return new SelectionRanges(0, ranges); });
                // listen to caret move and forget about state
                dispose(_this._selectionListener);
                _this._selectionListener = _this._editor.onDidChangeCursorPosition(function () {
                    if (!_this._ignoreSelection) {
                        dispose(_this._selectionListener);
                        _this._state = undefined;
                    }
                });
            });
        }
        return promise.then(function () {
            if (!_this._state) {
                // no state
                return;
            }
            _this._state = _this._state.map(function (state) { return state.mov(forward); });
            var selections = _this._state.map(function (state) { return Selection.fromPositions(state.ranges[state.index].getStartPosition(), state.ranges[state.index].getEndPosition()); });
            _this._ignoreSelection = true;
            try {
                _this._editor.setSelections(selections);
            }
            finally {
                _this._ignoreSelection = false;
            }
        });
    };
    SmartSelectController._id = 'editor.contrib.smartSelectController';
    return SmartSelectController;
}());
var AbstractSmartSelect = /** @class */ (function (_super) {
    __extends(AbstractSmartSelect, _super);
    function AbstractSmartSelect(forward, opts) {
        var _this = _super.call(this, opts) || this;
        _this._forward = forward;
        return _this;
    }
    AbstractSmartSelect.prototype.run = function (_accessor, editor) {
        return __awaiter(this, void 0, void 0, function () {
            var controller;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        controller = SmartSelectController.get(editor);
                        if (!controller) return [3 /*break*/, 2];
                        return [4 /*yield*/, controller.run(this._forward)];
                    case 1:
                        _a.sent();
                        _a.label = 2;
                    case 2: return [2 /*return*/];
                }
            });
        });
    };
    return AbstractSmartSelect;
}(EditorAction));
var GrowSelectionAction = /** @class */ (function (_super) {
    __extends(GrowSelectionAction, _super);
    function GrowSelectionAction() {
        return _super.call(this, true, {
            id: 'editor.action.smartSelect.expand',
            label: nls.localize('smartSelect.expand', "Expand Selection"),
            alias: 'Expand Selection',
            precondition: undefined,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 1024 /* Shift */ | 512 /* Alt */ | 17 /* RightArrow */,
                mac: { primary: 2048 /* CtrlCmd */ | 256 /* WinCtrl */ | 1024 /* Shift */ | 17 /* RightArrow */ },
                weight: 100 /* EditorContrib */
            },
            menubarOpts: {
                menuId: 22 /* MenubarSelectionMenu */,
                group: '1_basic',
                title: nls.localize({ key: 'miSmartSelectGrow', comment: ['&& denotes a mnemonic'] }, "&&Expand Selection"),
                order: 2
            }
        }) || this;
    }
    return GrowSelectionAction;
}(AbstractSmartSelect));
// renamed command id
CommandsRegistry.registerCommandAlias('editor.action.smartSelect.grow', 'editor.action.smartSelect.expand');
var ShrinkSelectionAction = /** @class */ (function (_super) {
    __extends(ShrinkSelectionAction, _super);
    function ShrinkSelectionAction() {
        return _super.call(this, false, {
            id: 'editor.action.smartSelect.shrink',
            label: nls.localize('smartSelect.shrink', "Shrink Selection"),
            alias: 'Shrink Selection',
            precondition: undefined,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 1024 /* Shift */ | 512 /* Alt */ | 15 /* LeftArrow */,
                mac: { primary: 2048 /* CtrlCmd */ | 256 /* WinCtrl */ | 1024 /* Shift */ | 15 /* LeftArrow */ },
                weight: 100 /* EditorContrib */
            },
            menubarOpts: {
                menuId: 22 /* MenubarSelectionMenu */,
                group: '1_basic',
                title: nls.localize({ key: 'miSmartSelectShrink', comment: ['&& denotes a mnemonic'] }, "&&Shrink Selection"),
                order: 3
            }
        }) || this;
    }
    return ShrinkSelectionAction;
}(AbstractSmartSelect));
registerEditorContribution(SmartSelectController);
registerEditorAction(GrowSelectionAction);
registerEditorAction(ShrinkSelectionAction);
// word selection
modes.SelectionRangeRegistry.register('*', new WordSelectionRangeProvider());
export function provideSelectionRanges(model, positions, token) {
    var providers = modes.SelectionRangeRegistry.all(model);
    if (providers.length === 1) {
        // add word selection and bracket selection when no provider exists
        providers.unshift(new BracketSelectionRangeProvider());
    }
    var work = [];
    var allRawRanges = [];
    for (var _i = 0, providers_1 = providers; _i < providers_1.length; _i++) {
        var provider = providers_1[_i];
        work.push(Promise.resolve(provider.provideSelectionRanges(model, positions, token)).then(function (allProviderRanges) {
            if (arrays.isNonEmptyArray(allProviderRanges) && allProviderRanges.length === positions.length) {
                for (var i = 0; i < positions.length; i++) {
                    if (!allRawRanges[i]) {
                        allRawRanges[i] = [];
                    }
                    for (var _i = 0, _a = allProviderRanges[i]; _i < _a.length; _i++) {
                        var oneProviderRanges = _a[_i];
                        if (Range.isIRange(oneProviderRanges.range) && Range.containsPosition(oneProviderRanges.range, positions[i])) {
                            allRawRanges[i].push(Range.lift(oneProviderRanges.range));
                        }
                    }
                }
            }
        }, onUnexpectedExternalError));
    }
    return Promise.all(work).then(function () {
        return allRawRanges.map(function (oneRawRanges) {
            if (oneRawRanges.length === 0) {
                return [];
            }
            // sort all by start/end position
            oneRawRanges.sort(function (a, b) {
                if (Position.isBefore(a.getStartPosition(), b.getStartPosition())) {
                    return 1;
                }
                else if (Position.isBefore(b.getStartPosition(), a.getStartPosition())) {
                    return -1;
                }
                else if (Position.isBefore(a.getEndPosition(), b.getEndPosition())) {
                    return -1;
                }
                else if (Position.isBefore(b.getEndPosition(), a.getEndPosition())) {
                    return 1;
                }
                else {
                    return 0;
                }
            });
            // remove ranges that don't contain the former range or that are equal to the
            // former range
            var oneRanges = [];
            var last;
            for (var _i = 0, oneRawRanges_1 = oneRawRanges; _i < oneRawRanges_1.length; _i++) {
                var range = oneRawRanges_1[_i];
                if (!last || (Range.containsRange(range, last) && !Range.equalsRange(range, last))) {
                    oneRanges.push(range);
                    last = range;
                }
            }
            // add ranges that expand trivia at line starts and ends whenever a range
            // wraps onto the a new line
            var oneRangesWithTrivia = [oneRanges[0]];
            for (var i = 1; i < oneRanges.length; i++) {
                var prev = oneRanges[i - 1];
                var cur = oneRanges[i];
                if (cur.startLineNumber !== prev.startLineNumber || cur.endLineNumber !== prev.endLineNumber) {
                    // add line/block range without leading/failing whitespace
                    var rangeNoWhitespace = new Range(prev.startLineNumber, model.getLineFirstNonWhitespaceColumn(prev.startLineNumber), prev.endLineNumber, model.getLineLastNonWhitespaceColumn(prev.endLineNumber));
                    if (rangeNoWhitespace.containsRange(prev) && !rangeNoWhitespace.equalsRange(prev) && cur.containsRange(rangeNoWhitespace) && !cur.equalsRange(rangeNoWhitespace)) {
                        oneRangesWithTrivia.push(rangeNoWhitespace);
                    }
                    // add line/block range
                    var rangeFull = new Range(prev.startLineNumber, 1, prev.endLineNumber, model.getLineMaxColumn(prev.endLineNumber));
                    if (rangeFull.containsRange(prev) && !rangeFull.equalsRange(rangeNoWhitespace) && cur.containsRange(rangeFull) && !cur.equalsRange(rangeFull)) {
                        oneRangesWithTrivia.push(rangeFull);
                    }
                }
                oneRangesWithTrivia.push(cur);
            }
            return oneRangesWithTrivia;
        });
    });
}
registerDefaultLanguageCommand('_executeSelectionRangeProvider', function (model, _position, args) {
    return provideSelectionRanges(model, args.positions, CancellationToken.None);
});
