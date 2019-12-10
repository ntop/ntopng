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
import { alert } from '../../../base/browser/ui/aria/aria.js';
import { createCancelablePromise, raceCancellation } from '../../../base/common/async.js';
import { KeyChord } from '../../../base/common/keyCodes.js';
import * as platform from '../../../base/common/platform.js';
import { EditorAction, registerEditorAction } from '../../browser/editorExtensions.js';
import { ICodeEditorService } from '../../browser/services/codeEditorService.js';
import { Range } from '../../common/core/range.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import { isLocationLink } from '../../common/modes.js';
import { MessageController } from '../message/messageController.js';
import { PeekContext } from '../referenceSearch/peekViewWidget.js';
import { ReferencesController } from '../referenceSearch/referencesController.js';
import { ReferencesModel } from '../referenceSearch/referencesModel.js';
import * as nls from '../../../nls.js';
import { MenuRegistry } from '../../../platform/actions/common/actions.js';
import { ContextKeyExpr } from '../../../platform/contextkey/common/contextkey.js';
import { INotificationService } from '../../../platform/notification/common/notification.js';
import { IEditorProgressService } from '../../../platform/progress/common/progress.js';
import { getDefinitionsAtPosition, getImplementationsAtPosition, getTypeDefinitionsAtPosition, getDeclarationsAtPosition } from './goToDefinition.js';
import { CommandsRegistry } from '../../../platform/commands/common/commands.js';
import { EditorStateCancellationTokenSource } from '../../browser/core/editorState.js';
import { ISymbolNavigationService } from './goToDefinitionResultsNavigation.js';
var DefinitionActionConfig = /** @class */ (function () {
    function DefinitionActionConfig(openToSide, openInPeek, filterCurrent, showMessage) {
        if (openToSide === void 0) { openToSide = false; }
        if (openInPeek === void 0) { openInPeek = false; }
        if (filterCurrent === void 0) { filterCurrent = true; }
        if (showMessage === void 0) { showMessage = true; }
        this.openToSide = openToSide;
        this.openInPeek = openInPeek;
        this.filterCurrent = filterCurrent;
        this.showMessage = showMessage;
        //
    }
    return DefinitionActionConfig;
}());
export { DefinitionActionConfig };
var DefinitionAction = /** @class */ (function (_super) {
    __extends(DefinitionAction, _super);
    function DefinitionAction(configuration, opts) {
        var _this = _super.call(this, opts) || this;
        _this._configuration = configuration;
        return _this;
    }
    DefinitionAction.prototype.run = function (accessor, editor) {
        var _this = this;
        if (!editor.hasModel()) {
            return Promise.resolve(undefined);
        }
        var notificationService = accessor.get(INotificationService);
        var editorService = accessor.get(ICodeEditorService);
        var progressService = accessor.get(IEditorProgressService);
        var symbolNavService = accessor.get(ISymbolNavigationService);
        var model = editor.getModel();
        var pos = editor.getPosition();
        var cts = new EditorStateCancellationTokenSource(editor, 1 /* Value */ | 4 /* Position */);
        var definitionPromise = raceCancellation(this._getTargetLocationForPosition(model, pos, cts.token), cts.token).then(function (references) { return __awaiter(_this, void 0, void 0, function () {
            var idxOfCurrent, result, _i, references_1, reference, newLen, info, current;
            return __generator(this, function (_a) {
                if (!references || model.isDisposed()) {
                    // new model, no more model
                    return [2 /*return*/];
                }
                idxOfCurrent = -1;
                result = [];
                for (_i = 0, references_1 = references; _i < references_1.length; _i++) {
                    reference = references_1[_i];
                    if (!reference || !reference.range) {
                        continue;
                    }
                    newLen = result.push(reference);
                    if (this._configuration.filterCurrent
                        && reference.uri.toString() === model.uri.toString()
                        && Range.containsPosition(reference.range, pos)
                        && idxOfCurrent === -1) {
                        idxOfCurrent = newLen - 1;
                    }
                }
                if (result.length === 0) {
                    // no result -> show message
                    if (this._configuration.showMessage) {
                        info = model.getWordAtPosition(pos);
                        MessageController.get(editor).showMessage(this._getNoResultFoundMessage(info), pos);
                    }
                }
                else if (result.length === 1 && idxOfCurrent !== -1) {
                    current = result[0];
                    return [2 /*return*/, this._openReference(editor, editorService, current, false).then(function () { return undefined; })];
                }
                else {
                    // handle multile results
                    return [2 /*return*/, this._onResult(editorService, symbolNavService, editor, new ReferencesModel(result))];
                }
                return [2 /*return*/];
            });
        }); }, function (err) {
            // report an error
            notificationService.error(err);
        }).finally(function () {
            cts.dispose();
        });
        progressService.showWhile(definitionPromise, 250);
        return definitionPromise;
    };
    DefinitionAction.prototype._getTargetLocationForPosition = function (model, position, token) {
        return getDefinitionsAtPosition(model, position, token);
    };
    DefinitionAction.prototype._getNoResultFoundMessage = function (info) {
        return info && info.word
            ? nls.localize('noResultWord', "No definition found for '{0}'", info.word)
            : nls.localize('generic.noResults', "No definition found");
    };
    DefinitionAction.prototype._getMetaTitle = function (model) {
        return model.references.length > 1 ? nls.localize('meta.title', " – {0} definitions", model.references.length) : '';
    };
    DefinitionAction.prototype._onResult = function (editorService, symbolNavService, editor, model) {
        return __awaiter(this, void 0, void 0, function () {
            var msg, gotoLocation, next, targetEditor;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        msg = model.getAriaMessage();
                        alert(msg);
                        gotoLocation = editor.getConfiguration().contribInfo.gotoLocation;
                        if (!(this._configuration.openInPeek || (gotoLocation.multiple === 'peek' && model.references.length > 1))) return [3 /*break*/, 1];
                        this._openInPeek(editorService, editor, model);
                        return [3 /*break*/, 3];
                    case 1:
                        if (!editor.hasModel()) return [3 /*break*/, 3];
                        next = model.firstReference();
                        if (!next) {
                            return [2 /*return*/];
                        }
                        return [4 /*yield*/, this._openReference(editor, editorService, next, this._configuration.openToSide)];
                    case 2:
                        targetEditor = _a.sent();
                        if (targetEditor && model.references.length > 1 && gotoLocation.multiple === 'gotoAndPeek') {
                            this._openInPeek(editorService, targetEditor, model);
                        }
                        else {
                            model.dispose();
                        }
                        // keep remaining locations around when using
                        // 'goto'-mode
                        if (gotoLocation.multiple === 'goto') {
                            symbolNavService.put(next);
                        }
                        _a.label = 3;
                    case 3: return [2 /*return*/];
                }
            });
        });
    };
    DefinitionAction.prototype._openReference = function (editor, editorService, reference, sideBySide) {
        // range is the target-selection-range when we have one
        // and the the fallback is the 'full' range
        var range = undefined;
        if (isLocationLink(reference)) {
            range = reference.targetSelectionRange;
        }
        if (!range) {
            range = reference.range;
        }
        return editorService.openCodeEditor({
            resource: reference.uri,
            options: {
                selection: Range.collapseToStart(range),
                revealInCenterIfOutsideViewport: true
            }
        }, editor, sideBySide);
    };
    DefinitionAction.prototype._openInPeek = function (editorService, target, model) {
        var _this = this;
        var controller = ReferencesController.get(target);
        if (controller && target.hasModel()) {
            controller.toggleWidget(target.getSelection(), createCancelablePromise(function (_) { return Promise.resolve(model); }), {
                getMetaTitle: function (model) {
                    return _this._getMetaTitle(model);
                },
                onGoto: function (reference) {
                    controller.closeWidget();
                    return _this._openReference(target, editorService, reference, false);
                }
            });
        }
        else {
            model.dispose();
        }
    };
    return DefinitionAction;
}(EditorAction));
export { DefinitionAction };
var goToDefinitionKb = platform.isWeb
    ? 2048 /* CtrlCmd */ | 70 /* F12 */
    : 70 /* F12 */;
var GoToDefinitionAction = /** @class */ (function (_super) {
    __extends(GoToDefinitionAction, _super);
    function GoToDefinitionAction() {
        var _this = _super.call(this, new DefinitionActionConfig(), {
            id: GoToDefinitionAction.id,
            label: nls.localize('actions.goToDecl.label', "Go to Definition"),
            alias: 'Go to Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDefinitionProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: goToDefinitionKb,
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                group: 'navigation',
                order: 1.1
            }
        }) || this;
        CommandsRegistry.registerCommandAlias('editor.action.goToDeclaration', GoToDefinitionAction.id);
        return _this;
    }
    GoToDefinitionAction.id = 'editor.action.revealDefinition';
    return GoToDefinitionAction;
}(DefinitionAction));
export { GoToDefinitionAction };
var OpenDefinitionToSideAction = /** @class */ (function (_super) {
    __extends(OpenDefinitionToSideAction, _super);
    function OpenDefinitionToSideAction() {
        var _this = _super.call(this, new DefinitionActionConfig(true), {
            id: OpenDefinitionToSideAction.id,
            label: nls.localize('actions.goToDeclToSide.label', "Open Definition to the Side"),
            alias: 'Open Definition to the Side',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDefinitionProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyChord(2048 /* CtrlCmd */ | 41 /* KEY_K */, goToDefinitionKb),
                weight: 100 /* EditorContrib */
            }
        }) || this;
        CommandsRegistry.registerCommandAlias('editor.action.openDeclarationToTheSide', OpenDefinitionToSideAction.id);
        return _this;
    }
    OpenDefinitionToSideAction.id = 'editor.action.revealDefinitionAside';
    return OpenDefinitionToSideAction;
}(DefinitionAction));
export { OpenDefinitionToSideAction };
var PeekDefinitionAction = /** @class */ (function (_super) {
    __extends(PeekDefinitionAction, _super);
    function PeekDefinitionAction() {
        var _this = _super.call(this, new DefinitionActionConfig(undefined, true, false), {
            id: PeekDefinitionAction.id,
            label: nls.localize('actions.previewDecl.label', "Peek Definition"),
            alias: 'Peek Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDefinitionProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 512 /* Alt */ | 70 /* F12 */,
                linux: { primary: 2048 /* CtrlCmd */ | 1024 /* Shift */ | 68 /* F10 */ },
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                group: 'navigation',
                order: 1.2
            }
        }) || this;
        CommandsRegistry.registerCommandAlias('editor.action.previewDeclaration', PeekDefinitionAction.id);
        return _this;
    }
    PeekDefinitionAction.id = 'editor.action.peekDefinition';
    return PeekDefinitionAction;
}(DefinitionAction));
export { PeekDefinitionAction };
var DeclarationAction = /** @class */ (function (_super) {
    __extends(DeclarationAction, _super);
    function DeclarationAction() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    DeclarationAction.prototype._getTargetLocationForPosition = function (model, position, token) {
        return getDeclarationsAtPosition(model, position, token);
    };
    DeclarationAction.prototype._getNoResultFoundMessage = function (info) {
        return info && info.word
            ? nls.localize('decl.noResultWord', "No declaration found for '{0}'", info.word)
            : nls.localize('decl.generic.noResults', "No declaration found");
    };
    DeclarationAction.prototype._getMetaTitle = function (model) {
        return model.references.length > 1 ? nls.localize('decl.meta.title', " – {0} declarations", model.references.length) : '';
    };
    return DeclarationAction;
}(DefinitionAction));
export { DeclarationAction };
var GoToDeclarationAction = /** @class */ (function (_super) {
    __extends(GoToDeclarationAction, _super);
    function GoToDeclarationAction() {
        return _super.call(this, new DefinitionActionConfig(), {
            id: GoToDeclarationAction.id,
            label: nls.localize('actions.goToDeclaration.label', "Go to Declaration"),
            alias: 'Go to Declaration',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDeclarationProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            menuOpts: {
                group: 'navigation',
                order: 1.3
            }
        }) || this;
    }
    GoToDeclarationAction.prototype._getNoResultFoundMessage = function (info) {
        return info && info.word
            ? nls.localize('decl.noResultWord', "No declaration found for '{0}'", info.word)
            : nls.localize('decl.generic.noResults', "No declaration found");
    };
    GoToDeclarationAction.prototype._getMetaTitle = function (model) {
        return model.references.length > 1 ? nls.localize('decl.meta.title', " – {0} declarations", model.references.length) : '';
    };
    GoToDeclarationAction.id = 'editor.action.revealDeclaration';
    return GoToDeclarationAction;
}(DeclarationAction));
export { GoToDeclarationAction };
var PeekDeclarationAction = /** @class */ (function (_super) {
    __extends(PeekDeclarationAction, _super);
    function PeekDeclarationAction() {
        return _super.call(this, new DefinitionActionConfig(undefined, true, false), {
            id: 'editor.action.peekDeclaration',
            label: nls.localize('actions.peekDecl.label', "Peek Declaration"),
            alias: 'Peek Declaration',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasDeclarationProvider, PeekContext.notInPeekEditor, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            menuOpts: {
                group: 'navigation',
                order: 1.31
            }
        }) || this;
    }
    return PeekDeclarationAction;
}(DeclarationAction));
export { PeekDeclarationAction };
var ImplementationAction = /** @class */ (function (_super) {
    __extends(ImplementationAction, _super);
    function ImplementationAction() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    ImplementationAction.prototype._getTargetLocationForPosition = function (model, position, token) {
        return getImplementationsAtPosition(model, position, token);
    };
    ImplementationAction.prototype._getNoResultFoundMessage = function (info) {
        return info && info.word
            ? nls.localize('goToImplementation.noResultWord', "No implementation found for '{0}'", info.word)
            : nls.localize('goToImplementation.generic.noResults', "No implementation found");
    };
    ImplementationAction.prototype._getMetaTitle = function (model) {
        return model.references.length > 1 ? nls.localize('meta.implementations.title', " – {0} implementations", model.references.length) : '';
    };
    return ImplementationAction;
}(DefinitionAction));
export { ImplementationAction };
var GoToImplementationAction = /** @class */ (function (_super) {
    __extends(GoToImplementationAction, _super);
    function GoToImplementationAction() {
        return _super.call(this, new DefinitionActionConfig(), {
            id: GoToImplementationAction.ID,
            label: nls.localize('actions.goToImplementation.label', "Go to Implementation"),
            alias: 'Go to Implementation',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasImplementationProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 2048 /* CtrlCmd */ | 70 /* F12 */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    GoToImplementationAction.ID = 'editor.action.goToImplementation';
    return GoToImplementationAction;
}(ImplementationAction));
export { GoToImplementationAction };
var PeekImplementationAction = /** @class */ (function (_super) {
    __extends(PeekImplementationAction, _super);
    function PeekImplementationAction() {
        return _super.call(this, new DefinitionActionConfig(false, true, false), {
            id: PeekImplementationAction.ID,
            label: nls.localize('actions.peekImplementation.label', "Peek Implementation"),
            alias: 'Peek Implementation',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasImplementationProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 2048 /* CtrlCmd */ | 1024 /* Shift */ | 70 /* F12 */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    PeekImplementationAction.ID = 'editor.action.peekImplementation';
    return PeekImplementationAction;
}(ImplementationAction));
export { PeekImplementationAction };
var TypeDefinitionAction = /** @class */ (function (_super) {
    __extends(TypeDefinitionAction, _super);
    function TypeDefinitionAction() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    TypeDefinitionAction.prototype._getTargetLocationForPosition = function (model, position, token) {
        return getTypeDefinitionsAtPosition(model, position, token);
    };
    TypeDefinitionAction.prototype._getNoResultFoundMessage = function (info) {
        return info && info.word
            ? nls.localize('goToTypeDefinition.noResultWord', "No type definition found for '{0}'", info.word)
            : nls.localize('goToTypeDefinition.generic.noResults', "No type definition found");
    };
    TypeDefinitionAction.prototype._getMetaTitle = function (model) {
        return model.references.length > 1 ? nls.localize('meta.typeDefinitions.title', " – {0} type definitions", model.references.length) : '';
    };
    return TypeDefinitionAction;
}(DefinitionAction));
export { TypeDefinitionAction };
var GoToTypeDefinitionAction = /** @class */ (function (_super) {
    __extends(GoToTypeDefinitionAction, _super);
    function GoToTypeDefinitionAction() {
        return _super.call(this, new DefinitionActionConfig(), {
            id: GoToTypeDefinitionAction.ID,
            label: nls.localize('actions.goToTypeDefinition.label', "Go to Type Definition"),
            alias: 'Go to Type Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasTypeDefinitionProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 0,
                weight: 100 /* EditorContrib */
            },
            menuOpts: {
                group: 'navigation',
                order: 1.4
            }
        }) || this;
    }
    GoToTypeDefinitionAction.ID = 'editor.action.goToTypeDefinition';
    return GoToTypeDefinitionAction;
}(TypeDefinitionAction));
export { GoToTypeDefinitionAction };
var PeekTypeDefinitionAction = /** @class */ (function (_super) {
    __extends(PeekTypeDefinitionAction, _super);
    function PeekTypeDefinitionAction() {
        return _super.call(this, new DefinitionActionConfig(false, true, false), {
            id: PeekTypeDefinitionAction.ID,
            label: nls.localize('actions.peekTypeDefinition.label', "Peek Type Definition"),
            alias: 'Peek Type Definition',
            precondition: ContextKeyExpr.and(EditorContextKeys.hasTypeDefinitionProvider, EditorContextKeys.isInEmbeddedEditor.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 0,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    PeekTypeDefinitionAction.ID = 'editor.action.peekTypeDefinition';
    return PeekTypeDefinitionAction;
}(TypeDefinitionAction));
export { PeekTypeDefinitionAction };
registerEditorAction(GoToDefinitionAction);
registerEditorAction(OpenDefinitionToSideAction);
registerEditorAction(PeekDefinitionAction);
registerEditorAction(GoToDeclarationAction);
registerEditorAction(PeekDeclarationAction);
registerEditorAction(GoToImplementationAction);
registerEditorAction(PeekImplementationAction);
registerEditorAction(GoToTypeDefinitionAction);
registerEditorAction(PeekTypeDefinitionAction);
// Go to menu
MenuRegistry.appendMenuItem(16 /* MenubarGoMenu */, {
    group: '4_symbol_nav',
    command: {
        id: 'editor.action.goToDeclaration',
        title: nls.localize({ key: 'miGotoDefinition', comment: ['&& denotes a mnemonic'] }, "Go to &&Definition")
    },
    order: 2
});
MenuRegistry.appendMenuItem(16 /* MenubarGoMenu */, {
    group: '4_symbol_nav',
    command: {
        id: 'editor.action.goToTypeDefinition',
        title: nls.localize({ key: 'miGotoTypeDefinition', comment: ['&& denotes a mnemonic'] }, "Go to &&Type Definition")
    },
    order: 3
});
MenuRegistry.appendMenuItem(16 /* MenubarGoMenu */, {
    group: '4_symbol_nav',
    command: {
        id: 'editor.action.goToImplementation',
        title: nls.localize({ key: 'miGotoImplementation', comment: ['&& denotes a mnemonic'] }, "Go to &&Implementation")
    },
    order: 4
});
