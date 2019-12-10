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
import { Disposable } from '../../../base/common/lifecycle.js';
import { escapeRegExpCharacters } from '../../../base/common/strings.js';
import { EditorAction, EditorCommand } from '../../browser/editorExtensions.js';
import { IBulkEditService } from '../../browser/services/bulkEditService.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import { CodeActionUi } from './codeActionUi.js';
import { MessageController } from '../message/messageController.js';
import * as nls from '../../../nls.js';
import { ICommandService } from '../../../platform/commands/common/commands.js';
import { ContextKeyExpr, IContextKeyService } from '../../../platform/contextkey/common/contextkey.js';
import { IContextMenuService } from '../../../platform/contextview/browser/contextView.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
import { IMarkerService } from '../../../platform/markers/common/markers.js';
import { IEditorProgressService } from '../../../platform/progress/common/progress.js';
import { CodeActionModel, SUPPORTED_CODE_ACTIONS } from './codeActionModel.js';
import { CodeActionKind } from './codeActionTrigger.js';
function contextKeyForSupportedActions(kind) {
    return ContextKeyExpr.regex(SUPPORTED_CODE_ACTIONS.keys()[0], new RegExp('(\\s|^)' + escapeRegExpCharacters(kind.value) + '\\b'));
}
var QuickFixController = /** @class */ (function (_super) {
    __extends(QuickFixController, _super);
    function QuickFixController(editor, markerService, contextKeyService, progressService, contextMenuService, keybindingService, _commandService, _bulkEditService) {
        var _this = _super.call(this) || this;
        _this._commandService = _commandService;
        _this._bulkEditService = _bulkEditService;
        _this._editor = editor;
        _this._model = _this._register(new CodeActionModel(_this._editor, markerService, contextKeyService, progressService));
        _this._register(_this._model.onDidChangeState(function (newState) { return _this.update(newState); }));
        _this._ui = _this._register(new CodeActionUi(editor, QuickFixAction.Id, {
            applyCodeAction: function (action, retrigger) { return __awaiter(_this, void 0, void 0, function () {
                return __generator(this, function (_a) {
                    switch (_a.label) {
                        case 0:
                            _a.trys.push([0, , 2, 3]);
                            return [4 /*yield*/, this._applyCodeAction(action)];
                        case 1:
                            _a.sent();
                            return [3 /*break*/, 3];
                        case 2:
                            if (retrigger) {
                                this._trigger({ type: 'auto', filter: {} });
                            }
                            return [7 /*endfinally*/];
                        case 3: return [2 /*return*/];
                    }
                });
            }); }
        }, contextMenuService, keybindingService));
        return _this;
    }
    QuickFixController.get = function (editor) {
        return editor.getContribution(QuickFixController.ID);
    };
    QuickFixController.prototype.update = function (newState) {
        this._ui.update(newState);
    };
    QuickFixController.prototype.showCodeActions = function (actions, at) {
        return this._ui.showCodeActionList(actions, at);
    };
    QuickFixController.prototype.getId = function () {
        return QuickFixController.ID;
    };
    QuickFixController.prototype.manualTriggerAtCurrentPosition = function (notAvailableMessage, filter, autoApply) {
        if (!this._editor.hasModel()) {
            return;
        }
        MessageController.get(this._editor).closeMessage();
        var triggerPosition = this._editor.getPosition();
        this._trigger({ type: 'manual', filter: filter, autoApply: autoApply, context: { notAvailableMessage: notAvailableMessage, position: triggerPosition } });
    };
    QuickFixController.prototype._trigger = function (trigger) {
        return this._model.trigger(trigger);
    };
    QuickFixController.prototype._applyCodeAction = function (action) {
        return applyCodeAction(action, this._bulkEditService, this._commandService, this._editor);
    };
    QuickFixController.ID = 'editor.contrib.quickFixController';
    QuickFixController = __decorate([
        __param(1, IMarkerService),
        __param(2, IContextKeyService),
        __param(3, IEditorProgressService),
        __param(4, IContextMenuService),
        __param(5, IKeybindingService),
        __param(6, ICommandService),
        __param(7, IBulkEditService)
    ], QuickFixController);
    return QuickFixController;
}(Disposable));
export { QuickFixController };
export function applyCodeAction(action, bulkEditService, commandService, editor) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    if (!action.edit) return [3 /*break*/, 2];
                    return [4 /*yield*/, bulkEditService.apply(action.edit, { editor: editor })];
                case 1:
                    _a.sent();
                    _a.label = 2;
                case 2:
                    if (!action.command) return [3 /*break*/, 4];
                    return [4 /*yield*/, commandService.executeCommand.apply(commandService, [action.command.id].concat((action.command.arguments || [])))];
                case 3:
                    _a.sent();
                    _a.label = 4;
                case 4: return [2 /*return*/];
            }
        });
    });
}
function triggerCodeActionsForEditorSelection(editor, notAvailableMessage, filter, autoApply) {
    if (editor.hasModel()) {
        var controller = QuickFixController.get(editor);
        if (controller) {
            controller.manualTriggerAtCurrentPosition(notAvailableMessage, filter, autoApply);
        }
    }
}
var QuickFixAction = /** @class */ (function (_super) {
    __extends(QuickFixAction, _super);
    function QuickFixAction() {
        return _super.call(this, {
            id: QuickFixAction.Id,
            label: nls.localize('quickfix.trigger.label', "Quick Fix..."),
            alias: 'Quick Fix...',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 2048 /* CtrlCmd */ | 84 /* US_DOT */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    QuickFixAction.prototype.run = function (_accessor, editor) {
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.quickFix.noneMessage', "No code actions available"), undefined, undefined);
    };
    QuickFixAction.Id = 'editor.action.quickFix';
    return QuickFixAction;
}(EditorAction));
export { QuickFixAction };
var CodeActionCommandArgs = /** @class */ (function () {
    function CodeActionCommandArgs(kind, apply, preferred) {
        this.kind = kind;
        this.apply = apply;
        this.preferred = preferred;
    }
    CodeActionCommandArgs.fromUser = function (arg, defaults) {
        if (!arg || typeof arg !== 'object') {
            return new CodeActionCommandArgs(defaults.kind, defaults.apply, false);
        }
        return new CodeActionCommandArgs(CodeActionCommandArgs.getKindFromUser(arg, defaults.kind), CodeActionCommandArgs.getApplyFromUser(arg, defaults.apply), CodeActionCommandArgs.getPreferredUser(arg));
    };
    CodeActionCommandArgs.getApplyFromUser = function (arg, defaultAutoApply) {
        switch (typeof arg.apply === 'string' ? arg.apply.toLowerCase() : '') {
            case 'first': return 1 /* First */;
            case 'never': return 2 /* Never */;
            case 'ifsingle': return 0 /* IfSingle */;
            default: return defaultAutoApply;
        }
    };
    CodeActionCommandArgs.getKindFromUser = function (arg, defaultKind) {
        return typeof arg.kind === 'string'
            ? new CodeActionKind(arg.kind)
            : defaultKind;
    };
    CodeActionCommandArgs.getPreferredUser = function (arg) {
        return typeof arg.preferred === 'boolean'
            ? arg.preferred
            : false;
    };
    return CodeActionCommandArgs;
}());
var CodeActionCommand = /** @class */ (function (_super) {
    __extends(CodeActionCommand, _super);
    function CodeActionCommand() {
        return _super.call(this, {
            id: CodeActionCommand.Id,
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
            description: {
                description: "Trigger a code action",
                args: [{
                        name: 'args',
                        schema: {
                            'type': 'object',
                            'required': ['kind'],
                            'properties': {
                                'kind': {
                                    'type': 'string'
                                },
                                'apply': {
                                    'type': 'string',
                                    'default': 'ifSingle',
                                    'enum': ['first', 'ifSingle', 'never']
                                }
                            }
                        }
                    }]
            }
        }) || this;
    }
    CodeActionCommand.prototype.runEditorCommand = function (_accessor, editor, userArg) {
        var args = CodeActionCommandArgs.fromUser(userArg, {
            kind: CodeActionKind.Empty,
            apply: 0 /* IfSingle */,
        });
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.quickFix.noneMessage', "No code actions available"), {
            kind: args.kind,
            includeSourceActions: true,
            onlyIncludePreferredActions: args.preferred,
        }, args.apply);
    };
    CodeActionCommand.Id = 'editor.action.codeAction';
    return CodeActionCommand;
}(EditorCommand));
export { CodeActionCommand };
var RefactorAction = /** @class */ (function (_super) {
    __extends(RefactorAction, _super);
    function RefactorAction() {
        return _super.call(this, {
            id: RefactorAction.Id,
            label: nls.localize('refactor.label', "Refactor..."),
            alias: 'Refactor...',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 2048 /* CtrlCmd */ | 1024 /* Shift */ | 48 /* KEY_R */,
                mac: {
                    primary: 256 /* WinCtrl */ | 1024 /* Shift */ | 48 /* KEY_R */
                },
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                group: '1_modification',
                order: 2,
                when: ContextKeyExpr.and(EditorContextKeys.writable, contextKeyForSupportedActions(CodeActionKind.Refactor)),
            },
            description: {
                description: 'Refactor...',
                args: [{
                        name: 'args',
                        schema: {
                            'type': 'object',
                            'properties': {
                                'kind': {
                                    'type': 'string'
                                },
                                'apply': {
                                    'type': 'string',
                                    'default': 'never',
                                    'enum': ['first', 'ifSingle', 'never']
                                }
                            }
                        }
                    }]
            }
        }) || this;
    }
    RefactorAction.prototype.run = function (_accessor, editor, userArg) {
        var args = CodeActionCommandArgs.fromUser(userArg, {
            kind: CodeActionKind.Refactor,
            apply: 2 /* Never */
        });
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.refactor.noneMessage', "No refactorings available"), {
            kind: CodeActionKind.Refactor.contains(args.kind) ? args.kind : CodeActionKind.Empty,
            onlyIncludePreferredActions: args.preferred,
        }, args.apply);
    };
    RefactorAction.Id = 'editor.action.refactor';
    return RefactorAction;
}(EditorAction));
export { RefactorAction };
var SourceAction = /** @class */ (function (_super) {
    __extends(SourceAction, _super);
    function SourceAction() {
        return _super.call(this, {
            id: SourceAction.Id,
            label: nls.localize('source.label', "Source Action..."),
            alias: 'Source Action...',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCodeActionsProvider),
            menuOpts: {
                group: '1_modification',
                order: 2.1,
                when: ContextKeyExpr.and(EditorContextKeys.writable, contextKeyForSupportedActions(CodeActionKind.Source)),
            },
            description: {
                description: 'Source Action...',
                args: [{
                        name: 'args',
                        schema: {
                            'type': 'object',
                            'properties': {
                                'kind': {
                                    'type': 'string'
                                },
                                'apply': {
                                    'type': 'string',
                                    'default': 'never',
                                    'enum': ['first', 'ifSingle', 'never']
                                }
                            }
                        }
                    }]
            }
        }) || this;
    }
    SourceAction.prototype.run = function (_accessor, editor, userArg) {
        var args = CodeActionCommandArgs.fromUser(userArg, {
            kind: CodeActionKind.Source,
            apply: 2 /* Never */
        });
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.source.noneMessage', "No source actions available"), {
            kind: CodeActionKind.Source.contains(args.kind) ? args.kind : CodeActionKind.Empty,
            includeSourceActions: true,
            onlyIncludePreferredActions: args.preferred,
        }, args.apply);
    };
    SourceAction.Id = 'editor.action.sourceAction';
    return SourceAction;
}(EditorAction));
export { SourceAction };
var OrganizeImportsAction = /** @class */ (function (_super) {
    __extends(OrganizeImportsAction, _super);
    function OrganizeImportsAction() {
        return _super.call(this, {
            id: OrganizeImportsAction.Id,
            label: nls.localize('organizeImports.label', "Organize Imports"),
            alias: 'Organize Imports',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, contextKeyForSupportedActions(CodeActionKind.SourceOrganizeImports)),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 1024 /* Shift */ | 512 /* Alt */ | 45 /* KEY_O */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    OrganizeImportsAction.prototype.run = function (_accessor, editor) {
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.organize.noneMessage', "No organize imports action available"), { kind: CodeActionKind.SourceOrganizeImports, includeSourceActions: true }, 0 /* IfSingle */);
    };
    OrganizeImportsAction.Id = 'editor.action.organizeImports';
    return OrganizeImportsAction;
}(EditorAction));
export { OrganizeImportsAction };
var FixAllAction = /** @class */ (function (_super) {
    __extends(FixAllAction, _super);
    function FixAllAction() {
        return _super.call(this, {
            id: FixAllAction.Id,
            label: nls.localize('fixAll.label', "Fix All"),
            alias: 'Fix All',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, contextKeyForSupportedActions(CodeActionKind.SourceFixAll))
        }) || this;
    }
    FixAllAction.prototype.run = function (_accessor, editor) {
        return triggerCodeActionsForEditorSelection(editor, nls.localize('fixAll.noneMessage', "No fix all action available"), { kind: CodeActionKind.SourceFixAll, includeSourceActions: true }, 0 /* IfSingle */);
    };
    FixAllAction.Id = 'editor.action.fixAll';
    return FixAllAction;
}(EditorAction));
export { FixAllAction };
var AutoFixAction = /** @class */ (function (_super) {
    __extends(AutoFixAction, _super);
    function AutoFixAction() {
        return _super.call(this, {
            id: AutoFixAction.Id,
            label: nls.localize('autoFix.label', "Auto Fix..."),
            alias: 'Auto Fix...',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, contextKeyForSupportedActions(CodeActionKind.QuickFix)),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 512 /* Alt */ | 1024 /* Shift */ | 84 /* US_DOT */,
                mac: {
                    primary: 2048 /* CtrlCmd */ | 512 /* Alt */ | 84 /* US_DOT */
                },
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    AutoFixAction.prototype.run = function (_accessor, editor) {
        return triggerCodeActionsForEditorSelection(editor, nls.localize('editor.action.autoFix.noneMessage', "No auto fixes available"), {
            kind: CodeActionKind.QuickFix,
            onlyIncludePreferredActions: true
        }, 0 /* IfSingle */);
    };
    AutoFixAction.Id = 'editor.action.autoFix';
    return AutoFixAction;
}(EditorAction));
export { AutoFixAction };
