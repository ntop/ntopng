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
import * as nls from '../../../nls.js';
import { Emitter } from '../../../base/common/event.js';
import { DisposableStore } from '../../../base/common/lifecycle.js';
import { RawContextKey, IContextKeyService } from '../../../platform/contextkey/common/contextkey.js';
import { IMarkerService, MarkerSeverity } from '../../../platform/markers/common/markers.js';
import { Range } from '../../common/core/range.js';
import { registerEditorAction, registerEditorContribution, EditorAction, EditorCommand, registerEditorCommand } from '../../browser/editorExtensions.js';
import { IThemeService } from '../../../platform/theme/common/themeService.js';
import { EditorContextKeys } from '../../common/editorContextKeys.js';
import { MarkerNavigationWidget } from './gotoErrorWidget.js';
import { compare } from '../../../base/common/strings.js';
import { binarySearch } from '../../../base/common/arrays.js';
import { ICodeEditorService } from '../../browser/services/codeEditorService.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { MenuRegistry } from '../../../platform/actions/common/actions.js';
import { Action } from '../../../base/common/actions.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
var MarkerModel = /** @class */ (function () {
    function MarkerModel(editor, markers) {
        var _this = this;
        this._toUnbind = new DisposableStore();
        this._editor = editor;
        this._markers = [];
        this._nextIdx = -1;
        this._ignoreSelectionChange = false;
        this._onCurrentMarkerChanged = new Emitter();
        this._onMarkerSetChanged = new Emitter();
        this.setMarkers(markers);
        // listen on editor
        this._toUnbind.add(this._editor.onDidDispose(function () { return _this.dispose(); }));
        this._toUnbind.add(this._editor.onDidChangeCursorPosition(function () {
            if (_this._ignoreSelectionChange) {
                return;
            }
            if (_this.currentMarker && _this._editor.getPosition() && Range.containsPosition(_this.currentMarker, _this._editor.getPosition())) {
                return;
            }
            _this._nextIdx = -1;
        }));
    }
    Object.defineProperty(MarkerModel.prototype, "onCurrentMarkerChanged", {
        get: function () {
            return this._onCurrentMarkerChanged.event;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(MarkerModel.prototype, "onMarkerSetChanged", {
        get: function () {
            return this._onMarkerSetChanged.event;
        },
        enumerable: true,
        configurable: true
    });
    MarkerModel.prototype.setMarkers = function (markers) {
        var oldMarker = this._nextIdx >= 0 ? this._markers[this._nextIdx] : undefined;
        this._markers = markers || [];
        this._markers.sort(MarkerNavigationAction.compareMarker);
        if (!oldMarker) {
            this._nextIdx = -1;
        }
        else {
            this._nextIdx = Math.max(-1, binarySearch(this._markers, oldMarker, MarkerNavigationAction.compareMarker));
        }
        this._onMarkerSetChanged.fire(this);
    };
    MarkerModel.prototype.withoutWatchingEditorPosition = function (callback) {
        this._ignoreSelectionChange = true;
        try {
            callback();
        }
        finally {
            this._ignoreSelectionChange = false;
        }
    };
    MarkerModel.prototype._initIdx = function (fwd) {
        var found = false;
        var position = this._editor.getPosition();
        for (var i = 0; i < this._markers.length; i++) {
            var range = Range.lift(this._markers[i]);
            if (range.isEmpty() && this._editor.getModel()) {
                var word = this._editor.getModel().getWordAtPosition(range.getStartPosition());
                if (word) {
                    range = new Range(range.startLineNumber, word.startColumn, range.startLineNumber, word.endColumn);
                }
            }
            if (position && (range.containsPosition(position) || position.isBeforeOrEqual(range.getStartPosition()))) {
                this._nextIdx = i;
                found = true;
                break;
            }
        }
        if (!found) {
            // after the last change
            this._nextIdx = fwd ? 0 : this._markers.length - 1;
        }
        if (this._nextIdx < 0) {
            this._nextIdx = this._markers.length - 1;
        }
    };
    Object.defineProperty(MarkerModel.prototype, "currentMarker", {
        get: function () {
            return this.canNavigate() ? this._markers[this._nextIdx] : undefined;
        },
        set: function (marker) {
            var idx = this._nextIdx;
            this._nextIdx = -1;
            if (marker) {
                this._nextIdx = this.indexOf(marker);
            }
            if (this._nextIdx !== idx) {
                this._onCurrentMarkerChanged.fire(marker);
            }
        },
        enumerable: true,
        configurable: true
    });
    MarkerModel.prototype.move = function (fwd, inCircles) {
        if (!this.canNavigate()) {
            this._onCurrentMarkerChanged.fire(undefined);
            return !inCircles;
        }
        var oldIdx = this._nextIdx;
        var atEdge = false;
        if (this._nextIdx === -1) {
            this._initIdx(fwd);
        }
        else if (fwd) {
            if (inCircles || this._nextIdx + 1 < this._markers.length) {
                this._nextIdx = (this._nextIdx + 1) % this._markers.length;
            }
            else {
                atEdge = true;
            }
        }
        else if (!fwd) {
            if (inCircles || this._nextIdx > 0) {
                this._nextIdx = (this._nextIdx - 1 + this._markers.length) % this._markers.length;
            }
            else {
                atEdge = true;
            }
        }
        if (oldIdx !== this._nextIdx) {
            var marker = this._markers[this._nextIdx];
            this._onCurrentMarkerChanged.fire(marker);
        }
        return atEdge;
    };
    MarkerModel.prototype.canNavigate = function () {
        return this._markers.length > 0;
    };
    MarkerModel.prototype.findMarkerAtPosition = function (pos) {
        for (var _i = 0, _a = this._markers; _i < _a.length; _i++) {
            var marker = _a[_i];
            if (Range.containsPosition(marker, pos)) {
                return marker;
            }
        }
        return undefined;
    };
    Object.defineProperty(MarkerModel.prototype, "total", {
        get: function () {
            return this._markers.length;
        },
        enumerable: true,
        configurable: true
    });
    MarkerModel.prototype.indexOf = function (marker) {
        return 1 + this._markers.indexOf(marker);
    };
    MarkerModel.prototype.dispose = function () {
        this._toUnbind.dispose();
    };
    return MarkerModel;
}());
var MarkerController = /** @class */ (function () {
    function MarkerController(editor, _markerService, _contextKeyService, _themeService, _editorService, _keybindingService) {
        this._markerService = _markerService;
        this._contextKeyService = _contextKeyService;
        this._themeService = _themeService;
        this._editorService = _editorService;
        this._keybindingService = _keybindingService;
        this._model = null;
        this._widget = null;
        this._disposeOnClose = new DisposableStore();
        this._editor = editor;
        this._widgetVisible = CONTEXT_MARKERS_NAVIGATION_VISIBLE.bindTo(this._contextKeyService);
    }
    MarkerController.get = function (editor) {
        return editor.getContribution(MarkerController.ID);
    };
    MarkerController.prototype.getId = function () {
        return MarkerController.ID;
    };
    MarkerController.prototype.dispose = function () {
        this._cleanUp();
        this._disposeOnClose.dispose();
    };
    MarkerController.prototype._cleanUp = function () {
        this._widgetVisible.reset();
        this._disposeOnClose.clear();
        this._widget = null;
        this._model = null;
    };
    MarkerController.prototype.getOrCreateModel = function () {
        var _this = this;
        if (this._model) {
            return this._model;
        }
        var markers = this._getMarkers();
        this._model = new MarkerModel(this._editor, markers);
        this._markerService.onMarkerChanged(this._onMarkerChanged, this, this._disposeOnClose);
        var prevMarkerKeybinding = this._keybindingService.lookupKeybinding(PrevMarkerAction.ID);
        var nextMarkerKeybinding = this._keybindingService.lookupKeybinding(NextMarkerAction.ID);
        var actions = [
            new Action(PrevMarkerAction.ID, PrevMarkerAction.LABEL + (prevMarkerKeybinding ? " (" + prevMarkerKeybinding.getLabel() + ")" : ''), 'show-previous-problem chevron-up', this._model.canNavigate(), function () { return __awaiter(_this, void 0, void 0, function () { return __generator(this, function (_a) {
                if (this._model) {
                    this._model.move(false, true);
                }
                return [2 /*return*/];
            }); }); }),
            new Action(NextMarkerAction.ID, NextMarkerAction.LABEL + (nextMarkerKeybinding ? " (" + nextMarkerKeybinding.getLabel() + ")" : ''), 'show-next-problem chevron-down', this._model.canNavigate(), function () { return __awaiter(_this, void 0, void 0, function () { return __generator(this, function (_a) {
                if (this._model) {
                    this._model.move(true, true);
                }
                return [2 /*return*/];
            }); }); })
        ];
        this._widget = new MarkerNavigationWidget(this._editor, actions, this._themeService);
        this._widgetVisible.set(true);
        this._widget.onDidClose(function () { return _this._cleanUp(); }, this, this._disposeOnClose);
        this._disposeOnClose.add(this._model);
        this._disposeOnClose.add(this._widget);
        for (var _i = 0, actions_1 = actions; _i < actions_1.length; _i++) {
            var action = actions_1[_i];
            this._disposeOnClose.add(action);
        }
        this._disposeOnClose.add(this._widget.onDidSelectRelatedInformation(function (related) {
            _this._editorService.openCodeEditor({
                resource: related.resource,
                options: { pinned: true, revealIfOpened: true, selection: Range.lift(related).collapseToStart() }
            }, _this._editor).then(undefined, onUnexpectedError);
            _this.closeMarkersNavigation(false);
        }));
        this._disposeOnClose.add(this._editor.onDidChangeModel(function () { return _this._cleanUp(); }));
        this._disposeOnClose.add(this._model.onCurrentMarkerChanged(function (marker) {
            if (!marker || !_this._model) {
                _this._cleanUp();
            }
            else {
                _this._model.withoutWatchingEditorPosition(function () {
                    if (!_this._widget || !_this._model) {
                        return;
                    }
                    _this._widget.showAtMarker(marker, _this._model.indexOf(marker), _this._model.total);
                });
            }
        }));
        this._disposeOnClose.add(this._model.onMarkerSetChanged(function () {
            if (!_this._widget || !_this._widget.position || !_this._model) {
                return;
            }
            var marker = _this._model.findMarkerAtPosition(_this._widget.position);
            if (marker) {
                _this._widget.updateMarker(marker);
            }
            else {
                _this._widget.showStale();
            }
        }));
        return this._model;
    };
    MarkerController.prototype.closeMarkersNavigation = function (focusEditor) {
        if (focusEditor === void 0) { focusEditor = true; }
        this._cleanUp();
        if (focusEditor) {
            this._editor.focus();
        }
    };
    MarkerController.prototype.show = function (marker) {
        var model = this.getOrCreateModel();
        model.currentMarker = marker;
    };
    MarkerController.prototype._onMarkerChanged = function (changedResources) {
        var editorModel = this._editor.getModel();
        if (!editorModel) {
            return;
        }
        if (!this._model) {
            return;
        }
        if (!changedResources.some(function (r) { return editorModel.uri.toString() === r.toString(); })) {
            return;
        }
        this._model.setMarkers(this._getMarkers());
    };
    MarkerController.prototype._getMarkers = function () {
        var model = this._editor.getModel();
        if (!model) {
            return [];
        }
        return this._markerService.read({
            resource: model.uri,
            severities: MarkerSeverity.Error | MarkerSeverity.Warning | MarkerSeverity.Info
        });
    };
    MarkerController.ID = 'editor.contrib.markerController';
    MarkerController = __decorate([
        __param(1, IMarkerService),
        __param(2, IContextKeyService),
        __param(3, IThemeService),
        __param(4, ICodeEditorService),
        __param(5, IKeybindingService)
    ], MarkerController);
    return MarkerController;
}());
export { MarkerController };
var MarkerNavigationAction = /** @class */ (function (_super) {
    __extends(MarkerNavigationAction, _super);
    function MarkerNavigationAction(next, multiFile, opts) {
        var _this = _super.call(this, opts) || this;
        _this._isNext = next;
        _this._multiFile = multiFile;
        return _this;
    }
    MarkerNavigationAction.prototype.run = function (accessor, editor) {
        var _this = this;
        var markerService = accessor.get(IMarkerService);
        var editorService = accessor.get(ICodeEditorService);
        var controller = MarkerController.get(editor);
        if (!controller) {
            return Promise.resolve(undefined);
        }
        var model = controller.getOrCreateModel();
        var atEdge = model.move(this._isNext, !this._multiFile);
        if (!atEdge || !this._multiFile) {
            return Promise.resolve(undefined);
        }
        // try with the next/prev file
        var markers = markerService.read({ severities: MarkerSeverity.Error | MarkerSeverity.Warning | MarkerSeverity.Info }).sort(MarkerNavigationAction.compareMarker);
        if (markers.length === 0) {
            return Promise.resolve(undefined);
        }
        var editorModel = editor.getModel();
        if (!editorModel) {
            return Promise.resolve(undefined);
        }
        var oldMarker = model.currentMarker || { resource: editorModel.uri, severity: MarkerSeverity.Error, startLineNumber: 1, startColumn: 1, endLineNumber: 1, endColumn: 1 };
        var idx = binarySearch(markers, oldMarker, MarkerNavigationAction.compareMarker);
        if (idx < 0) {
            // find best match...
            idx = ~idx;
            idx %= markers.length;
        }
        else if (this._isNext) {
            idx = (idx + 1) % markers.length;
        }
        else {
            idx = (idx + markers.length - 1) % markers.length;
        }
        var newMarker = markers[idx];
        if (newMarker.resource.toString() === editorModel.uri.toString()) {
            // the next `resource` is this resource which
            // means we cycle within this file
            model.move(this._isNext, true);
            return Promise.resolve(undefined);
        }
        // close the widget for this editor-instance, open the resource
        // for the next marker and re-start marker navigation in there
        controller.closeMarkersNavigation();
        return editorService.openCodeEditor({
            resource: newMarker.resource,
            options: { pinned: false, revealIfOpened: true, revealInCenterIfOutsideViewport: true, selection: newMarker }
        }, editor).then(function (editor) {
            if (!editor) {
                return undefined;
            }
            return editor.getAction(_this.id).run();
        });
    };
    MarkerNavigationAction.compareMarker = function (a, b) {
        var res = compare(a.resource.toString(), b.resource.toString());
        if (res === 0) {
            res = MarkerSeverity.compare(a.severity, b.severity);
        }
        if (res === 0) {
            res = Range.compareRangesUsingStarts(a, b);
        }
        return res;
    };
    return MarkerNavigationAction;
}(EditorAction));
var NextMarkerAction = /** @class */ (function (_super) {
    __extends(NextMarkerAction, _super);
    function NextMarkerAction() {
        return _super.call(this, true, false, {
            id: NextMarkerAction.ID,
            label: NextMarkerAction.LABEL,
            alias: 'Go to Next Problem (Error, Warning, Info)',
            precondition: EditorContextKeys.writable,
            kbOpts: { kbExpr: EditorContextKeys.editorTextFocus, primary: 512 /* Alt */ | 66 /* F8 */, weight: 100 /* EditorContrib */ }
        }) || this;
    }
    NextMarkerAction.ID = 'editor.action.marker.next';
    NextMarkerAction.LABEL = nls.localize('markerAction.next.label', "Go to Next Problem (Error, Warning, Info)");
    return NextMarkerAction;
}(MarkerNavigationAction));
export { NextMarkerAction };
var PrevMarkerAction = /** @class */ (function (_super) {
    __extends(PrevMarkerAction, _super);
    function PrevMarkerAction() {
        return _super.call(this, false, false, {
            id: PrevMarkerAction.ID,
            label: PrevMarkerAction.LABEL,
            alias: 'Go to Previous Problem (Error, Warning, Info)',
            precondition: EditorContextKeys.writable,
            kbOpts: { kbExpr: EditorContextKeys.editorTextFocus, primary: 1024 /* Shift */ | 512 /* Alt */ | 66 /* F8 */, weight: 100 /* EditorContrib */ }
        }) || this;
    }
    PrevMarkerAction.ID = 'editor.action.marker.prev';
    PrevMarkerAction.LABEL = nls.localize('markerAction.previous.label', "Go to Previous Problem (Error, Warning, Info)");
    return PrevMarkerAction;
}(MarkerNavigationAction));
var NextMarkerInFilesAction = /** @class */ (function (_super) {
    __extends(NextMarkerInFilesAction, _super);
    function NextMarkerInFilesAction() {
        return _super.call(this, true, true, {
            id: 'editor.action.marker.nextInFiles',
            label: nls.localize('markerAction.nextInFiles.label', "Go to Next Problem in Files (Error, Warning, Info)"),
            alias: 'Go to Next Problem in Files (Error, Warning, Info)',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: 66 /* F8 */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    return NextMarkerInFilesAction;
}(MarkerNavigationAction));
var PrevMarkerInFilesAction = /** @class */ (function (_super) {
    __extends(PrevMarkerInFilesAction, _super);
    function PrevMarkerInFilesAction() {
        return _super.call(this, false, true, {
            id: 'editor.action.marker.prevInFiles',
            label: nls.localize('markerAction.previousInFiles.label', "Go to Previous Problem in Files (Error, Warning, Info)"),
            alias: 'Go to Previous Problem in Files (Error, Warning, Info)',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: 1024 /* Shift */ | 66 /* F8 */,
                weight: 100 /* EditorContrib */
            }
        }) || this;
    }
    return PrevMarkerInFilesAction;
}(MarkerNavigationAction));
registerEditorContribution(MarkerController);
registerEditorAction(NextMarkerAction);
registerEditorAction(PrevMarkerAction);
registerEditorAction(NextMarkerInFilesAction);
registerEditorAction(PrevMarkerInFilesAction);
var CONTEXT_MARKERS_NAVIGATION_VISIBLE = new RawContextKey('markersNavigationVisible', false);
var MarkerCommand = EditorCommand.bindToContribution(MarkerController.get);
registerEditorCommand(new MarkerCommand({
    id: 'closeMarkersNavigation',
    precondition: CONTEXT_MARKERS_NAVIGATION_VISIBLE,
    handler: function (x) { return x.closeMarkersNavigation(); },
    kbOpts: {
        weight: 100 /* EditorContrib */ + 50,
        kbExpr: EditorContextKeys.focus,
        primary: 9 /* Escape */,
        secondary: [1024 /* Shift */ | 9 /* Escape */]
    }
}));
// Go to menu
MenuRegistry.appendMenuItem(16 /* MenubarGoMenu */, {
    group: '6_problem_nav',
    command: {
        id: 'editor.action.marker.nextInFiles',
        title: nls.localize({ key: 'miGotoNextProblem', comment: ['&& denotes a mnemonic'] }, "Next &&Problem")
    },
    order: 1
});
MenuRegistry.appendMenuItem(16 /* MenubarGoMenu */, {
    group: '6_problem_nav',
    command: {
        id: 'editor.action.marker.prevInFiles',
        title: nls.localize({ key: 'miGotoPreviousProblem', comment: ['&& denotes a mnemonic'] }, "Previous &&Problem")
    },
    order: 2
});
