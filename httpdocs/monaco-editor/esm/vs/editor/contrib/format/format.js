/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
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
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { illegalArgument, onUnexpectedExternalError } from '../../../base/common/errors.js';
import { URI } from '../../../base/common/uri.js';
import { EditorStateCancellationTokenSource, TextModelCancellationTokenSource } from '../../browser/core/editorState.js';
import { isCodeEditor } from '../../browser/editorBrowser.js';
import { registerLanguageCommand } from '../../browser/editorExtensions.js';
import { Position } from '../../common/core/position.js';
import { Range } from '../../common/core/range.js';
import { Selection } from '../../common/core/selection.js';
import { DocumentFormattingEditProviderRegistry, DocumentRangeFormattingEditProviderRegistry, OnTypeFormattingEditProviderRegistry } from '../../common/modes.js';
import { IEditorWorkerService } from '../../common/services/editorWorkerService.js';
import { IModelService } from '../../common/services/modelService.js';
import { FormattingEdit } from './formattingEdit.js';
import * as nls from '../../../nls.js';
import { ExtensionIdentifier } from '../../../platform/extensions/common/extensions.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { LinkedList } from '../../../base/common/linkedList.js';
export function alertFormattingEdits(edits) {
    edits = edits.filter(function (edit) { return edit.range; });
    if (!edits.length) {
        return;
    }
    var range = edits[0].range;
    for (var i = 1; i < edits.length; i++) {
        range = Range.plusRange(range, edits[i].range);
    }
    var startLineNumber = range.startLineNumber, endLineNumber = range.endLineNumber;
    if (startLineNumber === endLineNumber) {
        if (edits.length === 1) {
            alert(nls.localize('hint11', "Made 1 formatting edit on line {0}", startLineNumber));
        }
        else {
            alert(nls.localize('hintn1', "Made {0} formatting edits on line {1}", edits.length, startLineNumber));
        }
    }
    else {
        if (edits.length === 1) {
            alert(nls.localize('hint1n', "Made 1 formatting edit between lines {0} and {1}", startLineNumber, endLineNumber));
        }
        else {
            alert(nls.localize('hintnn', "Made {0} formatting edits between lines {1} and {2}", edits.length, startLineNumber, endLineNumber));
        }
    }
}
export function getRealAndSyntheticDocumentFormattersOrdered(model) {
    var result = [];
    var seen = new Set();
    // (1) add all document formatter
    var docFormatter = DocumentFormattingEditProviderRegistry.ordered(model);
    for (var _i = 0, docFormatter_1 = docFormatter; _i < docFormatter_1.length; _i++) {
        var formatter = docFormatter_1[_i];
        result.push(formatter);
        if (formatter.extensionId) {
            seen.add(ExtensionIdentifier.toKey(formatter.extensionId));
        }
    }
    // (2) add all range formatter as document formatter (unless the same extension already did that)
    var rangeFormatter = DocumentRangeFormattingEditProviderRegistry.ordered(model);
    var _loop_1 = function (formatter) {
        if (formatter.extensionId) {
            if (seen.has(ExtensionIdentifier.toKey(formatter.extensionId))) {
                return "continue";
            }
            seen.add(ExtensionIdentifier.toKey(formatter.extensionId));
        }
        result.push({
            displayName: formatter.displayName,
            extensionId: formatter.extensionId,
            provideDocumentFormattingEdits: function (model, options, token) {
                return formatter.provideDocumentRangeFormattingEdits(model, model.getFullModelRange(), options, token);
            }
        });
    };
    for (var _a = 0, rangeFormatter_1 = rangeFormatter; _a < rangeFormatter_1.length; _a++) {
        var formatter = rangeFormatter_1[_a];
        _loop_1(formatter);
    }
    return result;
}
var FormattingConflicts = /** @class */ (function () {
    function FormattingConflicts() {
    }
    FormattingConflicts.select = function (formatter, document, mode) {
        return __awaiter(this, void 0, void 0, function () {
            var selector;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (formatter.length === 0) {
                            return [2 /*return*/, undefined];
                        }
                        selector = FormattingConflicts._selectors.iterator().next().value;
                        if (!selector) return [3 /*break*/, 2];
                        return [4 /*yield*/, selector(formatter, document, mode)];
                    case 1: return [2 /*return*/, _a.sent()];
                    case 2: return [2 /*return*/, formatter[0]];
                }
            });
        });
    };
    FormattingConflicts._selectors = new LinkedList();
    return FormattingConflicts;
}());
export { FormattingConflicts };
export function formatDocumentRangeWithSelectedProvider(accessor, editorOrModel, range, mode, token) {
    return __awaiter(this, void 0, void 0, function () {
        var instaService, model, provider, selected;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    instaService = accessor.get(IInstantiationService);
                    model = isCodeEditor(editorOrModel) ? editorOrModel.getModel() : editorOrModel;
                    provider = DocumentRangeFormattingEditProviderRegistry.ordered(model);
                    return [4 /*yield*/, FormattingConflicts.select(provider, model, mode)];
                case 1:
                    selected = _a.sent();
                    if (!selected) return [3 /*break*/, 3];
                    return [4 /*yield*/, instaService.invokeFunction(formatDocumentRangeWithProvider, selected, editorOrModel, range, token)];
                case 2:
                    _a.sent();
                    _a.label = 3;
                case 3: return [2 /*return*/];
            }
        });
    });
}
export function formatDocumentRangeWithProvider(accessor, provider, editorOrModel, range, token) {
    return __awaiter(this, void 0, void 0, function () {
        var workerService, model, cts, edits, rawEdits, range_1, initialSelection_1;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    workerService = accessor.get(IEditorWorkerService);
                    if (isCodeEditor(editorOrModel)) {
                        model = editorOrModel.getModel();
                        cts = new EditorStateCancellationTokenSource(editorOrModel, 1 /* Value */ | 4 /* Position */, token);
                    }
                    else {
                        model = editorOrModel;
                        cts = new TextModelCancellationTokenSource(editorOrModel, token);
                    }
                    _a.label = 1;
                case 1:
                    _a.trys.push([1, , 4, 5]);
                    return [4 /*yield*/, provider.provideDocumentRangeFormattingEdits(model, range, model.getFormattingOptions(), cts.token)];
                case 2:
                    rawEdits = _a.sent();
                    return [4 /*yield*/, workerService.computeMoreMinimalEdits(model.uri, rawEdits)];
                case 3:
                    edits = _a.sent();
                    if (cts.token.isCancellationRequested) {
                        return [2 /*return*/, true];
                    }
                    return [3 /*break*/, 5];
                case 4:
                    cts.dispose();
                    return [7 /*endfinally*/];
                case 5:
                    if (!edits || edits.length === 0) {
                        return [2 /*return*/, false];
                    }
                    if (isCodeEditor(editorOrModel)) {
                        // use editor to apply edits
                        FormattingEdit.execute(editorOrModel, edits);
                        alertFormattingEdits(edits);
                        editorOrModel.pushUndoStop();
                        editorOrModel.focus();
                        editorOrModel.revealPositionInCenterIfOutsideViewport(editorOrModel.getPosition(), 1 /* Immediate */);
                    }
                    else {
                        range_1 = edits[0].range;
                        initialSelection_1 = new Selection(range_1.startLineNumber, range_1.startColumn, range_1.endLineNumber, range_1.endColumn);
                        model.pushEditOperations([initialSelection_1], edits.map(function (edit) {
                            return {
                                text: edit.text,
                                range: Range.lift(edit.range),
                                forceMoveMarkers: true
                            };
                        }), function (undoEdits) {
                            for (var _i = 0, undoEdits_1 = undoEdits; _i < undoEdits_1.length; _i++) {
                                var range_2 = undoEdits_1[_i].range;
                                if (Range.areIntersectingOrTouching(range_2, initialSelection_1)) {
                                    return [new Selection(range_2.startLineNumber, range_2.startColumn, range_2.endLineNumber, range_2.endColumn)];
                                }
                            }
                            return null;
                        });
                    }
                    return [2 /*return*/, true];
            }
        });
    });
}
export function formatDocumentWithSelectedProvider(accessor, editorOrModel, mode, token) {
    return __awaiter(this, void 0, void 0, function () {
        var instaService, model, provider, selected;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    instaService = accessor.get(IInstantiationService);
                    model = isCodeEditor(editorOrModel) ? editorOrModel.getModel() : editorOrModel;
                    provider = getRealAndSyntheticDocumentFormattersOrdered(model);
                    return [4 /*yield*/, FormattingConflicts.select(provider, model, mode)];
                case 1:
                    selected = _a.sent();
                    if (!selected) return [3 /*break*/, 3];
                    return [4 /*yield*/, instaService.invokeFunction(formatDocumentWithProvider, selected, editorOrModel, mode, token)];
                case 2:
                    _a.sent();
                    _a.label = 3;
                case 3: return [2 /*return*/];
            }
        });
    });
}
export function formatDocumentWithProvider(accessor, provider, editorOrModel, mode, token) {
    return __awaiter(this, void 0, void 0, function () {
        var workerService, model, cts, edits, rawEdits, range, initialSelection_2;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    workerService = accessor.get(IEditorWorkerService);
                    if (isCodeEditor(editorOrModel)) {
                        model = editorOrModel.getModel();
                        cts = new EditorStateCancellationTokenSource(editorOrModel, 1 /* Value */ | 4 /* Position */, token);
                    }
                    else {
                        model = editorOrModel;
                        cts = new TextModelCancellationTokenSource(editorOrModel, token);
                    }
                    _a.label = 1;
                case 1:
                    _a.trys.push([1, , 4, 5]);
                    return [4 /*yield*/, provider.provideDocumentFormattingEdits(model, model.getFormattingOptions(), cts.token)];
                case 2:
                    rawEdits = _a.sent();
                    return [4 /*yield*/, workerService.computeMoreMinimalEdits(model.uri, rawEdits)];
                case 3:
                    edits = _a.sent();
                    if (cts.token.isCancellationRequested) {
                        return [2 /*return*/, true];
                    }
                    return [3 /*break*/, 5];
                case 4:
                    cts.dispose();
                    return [7 /*endfinally*/];
                case 5:
                    if (!edits || edits.length === 0) {
                        return [2 /*return*/, false];
                    }
                    if (isCodeEditor(editorOrModel)) {
                        // use editor to apply edits
                        FormattingEdit.execute(editorOrModel, edits);
                        if (mode !== 2 /* Silent */) {
                            alertFormattingEdits(edits);
                            editorOrModel.pushUndoStop();
                            editorOrModel.focus();
                            editorOrModel.revealPositionInCenterIfOutsideViewport(editorOrModel.getPosition(), 1 /* Immediate */);
                        }
                    }
                    else {
                        range = edits[0].range;
                        initialSelection_2 = new Selection(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn);
                        model.pushEditOperations([initialSelection_2], edits.map(function (edit) {
                            return {
                                text: edit.text,
                                range: Range.lift(edit.range),
                                forceMoveMarkers: true
                            };
                        }), function (undoEdits) {
                            for (var _i = 0, undoEdits_2 = undoEdits; _i < undoEdits_2.length; _i++) {
                                var range_3 = undoEdits_2[_i].range;
                                if (Range.areIntersectingOrTouching(range_3, initialSelection_2)) {
                                    return [new Selection(range_3.startLineNumber, range_3.startColumn, range_3.endLineNumber, range_3.endColumn)];
                                }
                            }
                            return null;
                        });
                    }
                    return [2 /*return*/, true];
            }
        });
    });
}
export function getDocumentRangeFormattingEditsUntilResult(workerService, model, range, options, token) {
    return __awaiter(this, void 0, void 0, function () {
        var providers, _i, providers_1, provider, rawEdits;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    providers = DocumentRangeFormattingEditProviderRegistry.ordered(model);
                    _i = 0, providers_1 = providers;
                    _a.label = 1;
                case 1:
                    if (!(_i < providers_1.length)) return [3 /*break*/, 5];
                    provider = providers_1[_i];
                    return [4 /*yield*/, Promise.resolve(provider.provideDocumentRangeFormattingEdits(model, range, options, token)).catch(onUnexpectedExternalError)];
                case 2:
                    rawEdits = _a.sent();
                    if (!isNonEmptyArray(rawEdits)) return [3 /*break*/, 4];
                    return [4 /*yield*/, workerService.computeMoreMinimalEdits(model.uri, rawEdits)];
                case 3: return [2 /*return*/, _a.sent()];
                case 4:
                    _i++;
                    return [3 /*break*/, 1];
                case 5: return [2 /*return*/, undefined];
            }
        });
    });
}
export function getDocumentFormattingEditsUntilResult(workerService, model, options, token) {
    return __awaiter(this, void 0, void 0, function () {
        var providers, _i, providers_2, provider, rawEdits;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    providers = getRealAndSyntheticDocumentFormattersOrdered(model);
                    _i = 0, providers_2 = providers;
                    _a.label = 1;
                case 1:
                    if (!(_i < providers_2.length)) return [3 /*break*/, 5];
                    provider = providers_2[_i];
                    return [4 /*yield*/, Promise.resolve(provider.provideDocumentFormattingEdits(model, options, token)).catch(onUnexpectedExternalError)];
                case 2:
                    rawEdits = _a.sent();
                    if (!isNonEmptyArray(rawEdits)) return [3 /*break*/, 4];
                    return [4 /*yield*/, workerService.computeMoreMinimalEdits(model.uri, rawEdits)];
                case 3: return [2 /*return*/, _a.sent()];
                case 4:
                    _i++;
                    return [3 /*break*/, 1];
                case 5: return [2 /*return*/, undefined];
            }
        });
    });
}
export function getOnTypeFormattingEdits(workerService, model, position, ch, options) {
    var providers = OnTypeFormattingEditProviderRegistry.ordered(model);
    if (providers.length === 0) {
        return Promise.resolve(undefined);
    }
    if (providers[0].autoFormatTriggerCharacters.indexOf(ch) < 0) {
        return Promise.resolve(undefined);
    }
    return Promise.resolve(providers[0].provideOnTypeFormattingEdits(model, position, ch, options, CancellationToken.None)).catch(onUnexpectedExternalError).then(function (edits) {
        return workerService.computeMoreMinimalEdits(model.uri, edits);
    });
}
registerLanguageCommand('_executeFormatRangeProvider', function (accessor, args) {
    var resource = args.resource, range = args.range, options = args.options;
    if (!(resource instanceof URI) || !Range.isIRange(range)) {
        throw illegalArgument();
    }
    var model = accessor.get(IModelService).getModel(resource);
    if (!model) {
        throw illegalArgument('resource');
    }
    return getDocumentRangeFormattingEditsUntilResult(accessor.get(IEditorWorkerService), model, Range.lift(range), options, CancellationToken.None);
});
registerLanguageCommand('_executeFormatDocumentProvider', function (accessor, args) {
    var resource = args.resource, options = args.options;
    if (!(resource instanceof URI)) {
        throw illegalArgument('resource');
    }
    var model = accessor.get(IModelService).getModel(resource);
    if (!model) {
        throw illegalArgument('resource');
    }
    return getDocumentFormattingEditsUntilResult(accessor.get(IEditorWorkerService), model, options, CancellationToken.None);
});
registerLanguageCommand('_executeFormatOnTypeProvider', function (accessor, args) {
    var resource = args.resource, position = args.position, ch = args.ch, options = args.options;
    if (!(resource instanceof URI) || !Position.isIPosition(position) || typeof ch !== 'string') {
        throw illegalArgument();
    }
    var model = accessor.get(IModelService).getModel(resource);
    if (!model) {
        throw illegalArgument('resource');
    }
    return getOnTypeFormattingEdits(accessor.get(IEditorWorkerService), model, Position.lift(position), ch, options);
});
