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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
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
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { KeyChord } from '../../../base/common/keyCodes.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
import { EditorAction, registerEditorAction, registerEditorContribution } from '../../browser/editorExtensions.js';
import { ICodeEditorService } from '../../browser/services/codeEditorService.js';
import { CharacterSet } from '../../common/core/characterClassifier.js';
import { Range } from '../../common/core/range.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import { DocumentRangeFormattingEditProviderRegistry, OnTypeFormattingEditProviderRegistry } from '../../common/modes.js';
import { IEditorWorkerService } from '../../common/services/editorWorkerService.js';
import { getOnTypeFormattingEdits, alertFormattingEdits, formatDocumentRangeWithSelectedProvider, formatDocumentWithSelectedProvider } from './format.js';
import { FormattingEdit } from './formattingEdit.js';
import * as nls from '../../../nls.js';
import { CommandsRegistry, ICommandService } from '../../../platform/commands/common/commands.js';
import { ContextKeyExpr } from '../../../platform/contextkey/common/contextkey.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
var FormatOnType = /** @class */ (function () {
    function FormatOnType(editor, _workerService) {
        var _this = this;
        this._workerService = _workerService;
        this._callOnDispose = new DisposableStore();
        this._callOnModel = new DisposableStore();
        this._editor = editor;
        this._callOnDispose.add(editor.onDidChangeConfiguration(function () { return _this._update(); }));
        this._callOnDispose.add(editor.onDidChangeModel(function () { return _this._update(); }));
        this._callOnDispose.add(editor.onDidChangeModelLanguage(function () { return _this._update(); }));
        this._callOnDispose.add(OnTypeFormattingEditProviderRegistry.onDidChange(this._update, this));
    }
    FormatOnType.prototype.getId = function () {
        return FormatOnType.ID;
    };
    FormatOnType.prototype.dispose = function () {
        this._callOnDispose.dispose();
        this._callOnModel.dispose();
    };
    FormatOnType.prototype._update = function () {
        var _this = this;
        // clean up
        this._callOnModel.clear();
        // we are disabled
        if (!this._editor.getConfiguration().contribInfo.formatOnType) {
            return;
        }
        // no model
        if (!this._editor.hasModel()) {
            return;
        }
        var model = this._editor.getModel();
        // no support
        var support = OnTypeFormattingEditProviderRegistry.ordered(model)[0];
        if (!support || !support.autoFormatTriggerCharacters) {
            return;
        }
        // register typing listeners that will trigger the format
        var triggerChars = new CharacterSet();
        for (var _i = 0, _a = support.autoFormatTriggerCharacters; _i < _a.length; _i++) {
            var ch = _a[_i];
            triggerChars.add(ch.charCodeAt(0));
        }
        this._callOnModel.add(this._editor.onDidType(function (text) {
            var lastCharCode = text.charCodeAt(text.length - 1);
            if (triggerChars.has(lastCharCode)) {
                _this._trigger(String.fromCharCode(lastCharCode));
            }
        }));
    };
    FormatOnType.prototype._trigger = function (ch) {
        var _this = this;
        if (!this._editor.hasModel()) {
            return;
        }
        if (this._editor.getSelections().length > 1) {
            return;
        }
        var model = this._editor.getModel();
        var position = this._editor.getPosition();
        var canceled = false;
        // install a listener that checks if edits happens before the
        // position on which we format right now. If so, we won't
        // apply the format edits
        var unbind = this._editor.onDidChangeModelContent(function (e) {
            if (e.isFlush) {
                // a model.setValue() was called
                // cancel only once
                canceled = true;
                unbind.dispose();
                return;
            }
            for (var i = 0, len = e.changes.length; i < len; i++) {
                var change = e.changes[i];
                if (change.range.endLineNumber <= position.lineNumber) {
                    // cancel only once
                    canceled = true;
                    unbind.dispose();
                    return;
                }
            }
        });
        getOnTypeFormattingEdits(this._workerService, model, position, ch, model.getFormattingOptions()).then(function (edits) {
            unbind.dispose();
            if (canceled) {
                return;
            }
            if (isNonEmptyArray(edits)) {
                FormattingEdit.execute(_this._editor, edits);
                alertFormattingEdits(edits);
            }
        }, function (err) {
            unbind.dispose();
            throw err;
        });
    };
    FormatOnType.ID = 'editor.contrib.autoFormat';
    FormatOnType = __decorate([
        __param(1, IEditorWorkerService)
    ], FormatOnType);
    return FormatOnType;
}());
var FormatOnPaste = /** @class */ (function () {
    function FormatOnPaste(editor, _instantiationService) {
        var _this = this;
        this.editor = editor;
        this._instantiationService = _instantiationService;
        this._callOnDispose = new DisposableStore();
        this._callOnModel = new DisposableStore();
        this._callOnDispose.add(editor.onDidChangeConfiguration(function () { return _this._update(); }));
        this._callOnDispose.add(editor.onDidChangeModel(function () { return _this._update(); }));
        this._callOnDispose.add(editor.onDidChangeModelLanguage(function () { return _this._update(); }));
        this._callOnDispose.add(DocumentRangeFormattingEditProviderRegistry.onDidChange(this._update, this));
    }
    FormatOnPaste.prototype.getId = function () {
        return FormatOnPaste.ID;
    };
    FormatOnPaste.prototype.dispose = function () {
        this._callOnDispose.dispose();
        this._callOnModel.dispose();
    };
    FormatOnPaste.prototype._update = function () {
        var _this = this;
        // clean up
        this._callOnModel.clear();
        // we are disabled
        if (!this.editor.getConfiguration().contribInfo.formatOnPaste) {
            return;
        }
        // no model
        if (!this.editor.hasModel()) {
            return;
        }
        // no formatter
        if (!DocumentRangeFormattingEditProviderRegistry.has(this.editor.getModel())) {
            return;
        }
        this._callOnModel.add(this.editor.onDidPaste(function (range) { return _this._trigger(range); }));
    };
    FormatOnPaste.prototype._trigger = function (range) {
        if (!this.editor.hasModel()) {
            return;
        }
        if (this.editor.getSelections().length > 1) {
            return;
        }
        this._instantiationService.invokeFunction(formatDocumentRangeWithSelectedProvider, this.editor, range, 2 /* Silent */, CancellationToken.None).catch(onUnexpectedError);
    };
    FormatOnPaste.ID = 'editor.contrib.formatOnPaste';
    FormatOnPaste = __decorate([
        __param(1, IInstantiationService)
    ], FormatOnPaste);
    return FormatOnPaste;
}());
var FormatDocumentAction = /** @class */ (function (_super) {
    __extends(FormatDocumentAction, _super);
    function FormatDocumentAction() {
        return _super.call(this, {
            id: 'editor.action.formatDocument',
            label: nls.localize('formatDocument.label', "Format Document"),
            alias: 'Format Document',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasDocumentFormattingProvider),
            kbOpts: {
                kbExpr: ContextKeyExpr.and(EditorContextKeys.editorTextFocus, EditorContextKeys.hasDocumentFormattingProvider),
                primary: 1024 /* Shift */ | 512 /* Alt */ | 36 /* KEY_F */,
                linux: { primary: 2048 /* CtrlCmd */ | 1024 /* Shift */ | 39 /* KEY_I */ },
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                when: EditorContextKeys.hasDocumentFormattingProvider,
                group: '1_modification',
                order: 1.3
            }
        }) || this;
    }
    FormatDocumentAction.prototype.run = function (accessor, editor) {
        return __awaiter(this, void 0, void 0, function () {
            var instaService;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (!editor.hasModel()) return [3 /*break*/, 2];
                        instaService = accessor.get(IInstantiationService);
                        return [4 /*yield*/, instaService.invokeFunction(formatDocumentWithSelectedProvider, editor, 1 /* Explicit */, CancellationToken.None)];
                    case 1:
                        _a.sent();
                        _a.label = 2;
                    case 2: return [2 /*return*/];
                }
            });
        });
    };
    return FormatDocumentAction;
}(EditorAction));
var FormatSelectionAction = /** @class */ (function (_super) {
    __extends(FormatSelectionAction, _super);
    function FormatSelectionAction() {
        return _super.call(this, {
            id: 'editor.action.formatSelection',
            label: nls.localize('formatSelection.label', "Format Selection"),
            alias: 'Format Selection',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasDocumentSelectionFormattingProvider),
            kbOpts: {
                kbExpr: ContextKeyExpr.and(EditorContextKeys.editorTextFocus, EditorContextKeys.hasDocumentSelectionFormattingProvider),
                primary: KeyChord(2048 /* CtrlCmd */ | 41 /* KEY_K */, 2048 /* CtrlCmd */ | 36 /* KEY_F */),
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                when: ContextKeyExpr.and(EditorContextKeys.hasDocumentSelectionFormattingProvider, EditorContextKeys.hasNonEmptySelection),
                group: '1_modification',
                order: 1.31
            }
        }) || this;
    }
    FormatSelectionAction.prototype.run = function (accessor, editor) {
        return __awaiter(this, void 0, void 0, function () {
            var instaService, model, range;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (!editor.hasModel()) {
                            return [2 /*return*/];
                        }
                        instaService = accessor.get(IInstantiationService);
                        model = editor.getModel();
                        range = editor.getSelection();
                        if (range.isEmpty()) {
                            range = new Range(range.startLineNumber, 1, range.startLineNumber, model.getLineMaxColumn(range.startLineNumber));
                        }
                        return [4 /*yield*/, instaService.invokeFunction(formatDocumentRangeWithSelectedProvider, editor, range, 1 /* Explicit */, CancellationToken.None)];
                    case 1:
                        _a.sent();
                        return [2 /*return*/];
                }
            });
        });
    };
    return FormatSelectionAction;
}(EditorAction));
registerEditorContribution(FormatOnType);
registerEditorContribution(FormatOnPaste);
registerEditorAction(FormatDocumentAction);
registerEditorAction(FormatSelectionAction);
// this is the old format action that does both (format document OR format selection)
// and we keep it here such that existing keybinding configurations etc will still work
CommandsRegistry.registerCommand('editor.action.format', function (accessor) { return __awaiter(_this, void 0, void 0, function () {
    var editor, commandService;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                editor = accessor.get(ICodeEditorService).getFocusedCodeEditor();
                if (!editor || !editor.hasModel()) {
                    return [2 /*return*/];
                }
                commandService = accessor.get(ICommandService);
                if (!editor.getSelection().isEmpty()) return [3 /*break*/, 2];
                return [4 /*yield*/, commandService.executeCommand('editor.action.formatDocument')];
            case 1:
                _a.sent();
                return [3 /*break*/, 4];
            case 2: return [4 /*yield*/, commandService.executeCommand('editor.action.formatSelection')];
            case 3:
                _a.sent();
                _a.label = 4;
            case 4: return [2 /*return*/];
        }
    });
}); });
