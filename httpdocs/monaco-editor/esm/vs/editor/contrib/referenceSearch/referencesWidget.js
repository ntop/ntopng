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
import * as dom from '../../../base/browser/dom.js';
import { Color } from '../../../base/common/color.js';
import { Emitter, Event } from '../../../base/common/event.js';
import { dispose, DisposableStore } from '../../../base/common/lifecycle.js';
import { Schemas } from '../../../base/common/network.js';
import { basenameOrAuthority, dirname } from '../../../base/common/resources.js';
import './media/referencesWidget.css';
import { EmbeddedCodeEditorWidget } from '../../browser/widget/embeddedCodeEditorWidget.js';
import { Range } from '../../common/core/range.js';
import { ModelDecorationOptions, TextModel } from '../../common/model/textModel.js';
import { ITextModelService } from '../../common/services/resolverService.js';
import { AriaProvider, DataSource, Delegate, FileReferencesRenderer, OneReferenceRenderer, StringRepresentationProvider, IdentityProvider } from './referencesTree.js';
import * as nls from '../../../nls.js';
import { RawContextKey } from '../../../platform/contextkey/common/contextkey.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { ILabelService } from '../../../platform/label/common/label.js';
import { WorkbenchAsyncDataTree } from '../../../platform/list/browser/listService.js';
import { activeContrastBorder, contrastBorder, registerColor } from '../../../platform/theme/common/colorRegistry.js';
import { IThemeService, registerThemingParticipant } from '../../../platform/theme/common/themeService.js';
import { PeekViewWidget, IPeekViewService } from './peekViewWidget.js';
import { FileReferences, OneReference } from './referencesModel.js';
import { SplitView, Sizing } from '../../../base/browser/ui/splitview/splitview.js';
var DecorationsManager = /** @class */ (function () {
    function DecorationsManager(_editor, _model) {
        var _this = this;
        this._editor = _editor;
        this._model = _model;
        this._decorations = new Map();
        this._decorationIgnoreSet = new Set();
        this._callOnDispose = new DisposableStore();
        this._callOnModelChange = new DisposableStore();
        this._callOnDispose.add(this._editor.onDidChangeModel(function () { return _this._onModelChanged(); }));
        this._onModelChanged();
    }
    DecorationsManager.prototype.dispose = function () {
        this._callOnModelChange.dispose();
        this._callOnDispose.dispose();
        this.removeDecorations();
    };
    DecorationsManager.prototype._onModelChanged = function () {
        this._callOnModelChange.clear();
        var model = this._editor.getModel();
        if (model) {
            for (var _i = 0, _a = this._model.groups; _i < _a.length; _i++) {
                var ref = _a[_i];
                if (ref.uri.toString() === model.uri.toString()) {
                    this._addDecorations(ref);
                    return;
                }
            }
        }
    };
    DecorationsManager.prototype._addDecorations = function (reference) {
        var _this = this;
        if (!this._editor.hasModel()) {
            return;
        }
        this._callOnModelChange.add(this._editor.getModel().onDidChangeDecorations(function (event) { return _this._onDecorationChanged(); }));
        var newDecorations = [];
        var newDecorationsActualIndex = [];
        for (var i = 0, len = reference.children.length; i < len; i++) {
            var oneReference = reference.children[i];
            if (this._decorationIgnoreSet.has(oneReference.id)) {
                continue;
            }
            newDecorations.push({
                range: oneReference.range,
                options: DecorationsManager.DecorationOptions
            });
            newDecorationsActualIndex.push(i);
        }
        var decorations = this._editor.deltaDecorations([], newDecorations);
        for (var i = 0; i < decorations.length; i++) {
            this._decorations.set(decorations[i], reference.children[newDecorationsActualIndex[i]]);
        }
    };
    DecorationsManager.prototype._onDecorationChanged = function () {
        var _this = this;
        var toRemove = [];
        var model = this._editor.getModel();
        if (!model) {
            return;
        }
        this._decorations.forEach(function (reference, decorationId) {
            var newRange = model.getDecorationRange(decorationId);
            if (!newRange) {
                return;
            }
            var ignore = false;
            if (Range.equalsRange(newRange, reference.range)) {
                return;
            }
            else if (Range.spansMultipleLines(newRange)) {
                ignore = true;
            }
            else {
                var lineLength = reference.range.endColumn - reference.range.startColumn;
                var newLineLength = newRange.endColumn - newRange.startColumn;
                if (lineLength !== newLineLength) {
                    ignore = true;
                }
            }
            if (ignore) {
                _this._decorationIgnoreSet.add(reference.id);
                toRemove.push(decorationId);
            }
            else {
                reference.range = newRange;
            }
        });
        for (var i = 0, len = toRemove.length; i < len; i++) {
            this._decorations.delete(toRemove[i]);
        }
        this._editor.deltaDecorations(toRemove, []);
    };
    DecorationsManager.prototype.removeDecorations = function () {
        var toRemove = [];
        this._decorations.forEach(function (value, key) {
            toRemove.push(key);
        });
        this._editor.deltaDecorations(toRemove, []);
        this._decorations.clear();
    };
    DecorationsManager.DecorationOptions = ModelDecorationOptions.register({
        stickiness: 1 /* NeverGrowsWhenTypingAtEdges */,
        className: 'reference-decoration'
    });
    return DecorationsManager;
}());
var LayoutData = /** @class */ (function () {
    function LayoutData() {
        this.ratio = 0.7;
        this.heightInLines = 18;
    }
    LayoutData.fromJSON = function (raw) {
        var ratio;
        var heightInLines;
        try {
            var data = JSON.parse(raw);
            ratio = data.ratio;
            heightInLines = data.heightInLines;
        }
        catch (_a) {
            //
        }
        return {
            ratio: ratio || 0.7,
            heightInLines: heightInLines || 18
        };
    };
    return LayoutData;
}());
export { LayoutData };
export var ctxReferenceWidgetSearchTreeFocused = new RawContextKey('referenceSearchTreeFocused', true);
/**
 * ZoneWidget that is shown inside the editor
 */
var ReferenceWidget = /** @class */ (function (_super) {
    __extends(ReferenceWidget, _super);
    function ReferenceWidget(editor, _defaultTreeKeyboardSupport, layoutData, themeService, _textModelResolverService, _instantiationService, _peekViewService, _uriLabel) {
        var _this = _super.call(this, editor, { showFrame: false, showArrow: true, isResizeable: true, isAccessible: true }) || this;
        _this._defaultTreeKeyboardSupport = _defaultTreeKeyboardSupport;
        _this.layoutData = layoutData;
        _this._textModelResolverService = _textModelResolverService;
        _this._instantiationService = _instantiationService;
        _this._peekViewService = _peekViewService;
        _this._uriLabel = _uriLabel;
        _this._disposeOnNewModel = new DisposableStore();
        _this._callOnDispose = new DisposableStore();
        _this._onDidSelectReference = new Emitter();
        _this._dim = { height: 0, width: 0 };
        _this._applyTheme(themeService.getTheme());
        _this._callOnDispose.add(themeService.onThemeChange(_this._applyTheme.bind(_this)));
        _this._peekViewService.addExclusiveWidget(editor, _this);
        _this.create();
        return _this;
    }
    ReferenceWidget.prototype.dispose = function () {
        this.setModel(undefined);
        this._callOnDispose.dispose();
        this._disposeOnNewModel.dispose();
        dispose(this._preview);
        dispose(this._previewNotAvailableMessage);
        dispose(this._tree);
        dispose(this._previewModelReference);
        this._splitView.dispose();
        _super.prototype.dispose.call(this);
    };
    ReferenceWidget.prototype._applyTheme = function (theme) {
        var borderColor = theme.getColor(peekViewBorder) || Color.transparent;
        this.style({
            arrowColor: borderColor,
            frameColor: borderColor,
            headerBackgroundColor: theme.getColor(peekViewTitleBackground) || Color.transparent,
            primaryHeadingColor: theme.getColor(peekViewTitleForeground),
            secondaryHeadingColor: theme.getColor(peekViewTitleInfoForeground)
        });
    };
    Object.defineProperty(ReferenceWidget.prototype, "onDidSelectReference", {
        get: function () {
            return this._onDidSelectReference.event;
        },
        enumerable: true,
        configurable: true
    });
    ReferenceWidget.prototype.show = function (where) {
        this.editor.revealRangeInCenterIfOutsideViewport(where, 0 /* Smooth */);
        _super.prototype.show.call(this, where, this.layoutData.heightInLines || 18);
    };
    ReferenceWidget.prototype.focus = function () {
        this._tree.domFocus();
    };
    ReferenceWidget.prototype._onTitleClick = function (e) {
        if (this._preview && this._preview.getModel()) {
            this._onDidSelectReference.fire({
                element: this._getFocusedReference(),
                kind: e.ctrlKey || e.metaKey || e.altKey ? 'side' : 'open',
                source: 'title'
            });
        }
    };
    ReferenceWidget.prototype._fillBody = function (containerElement) {
        var _this = this;
        this.setCssClass('reference-zone-widget');
        // message pane
        this._messageContainer = dom.append(containerElement, dom.$('div.messages'));
        dom.hide(this._messageContainer);
        this._splitView = new SplitView(containerElement, { orientation: 1 /* HORIZONTAL */ });
        // editor
        this._previewContainer = dom.append(containerElement, dom.$('div.preview.inline'));
        var options = {
            scrollBeyondLastLine: false,
            scrollbar: {
                verticalScrollbarSize: 14,
                horizontal: 'auto',
                useShadows: true,
                verticalHasArrows: false,
                horizontalHasArrows: false
            },
            overviewRulerLanes: 2,
            fixedOverflowWidgets: true,
            minimap: {
                enabled: false
            }
        };
        this._preview = this._instantiationService.createInstance(EmbeddedCodeEditorWidget, this._previewContainer, options, this.editor);
        dom.hide(this._previewContainer);
        this._previewNotAvailableMessage = TextModel.createFromString(nls.localize('missingPreviewMessage', "no preview available"));
        // tree
        this._treeContainer = dom.append(containerElement, dom.$('div.ref-tree.inline'));
        var treeOptions = {
            ariaLabel: nls.localize('treeAriaLabel', "References"),
            keyboardSupport: this._defaultTreeKeyboardSupport,
            accessibilityProvider: new AriaProvider(),
            keyboardNavigationLabelProvider: this._instantiationService.createInstance(StringRepresentationProvider),
            identityProvider: new IdentityProvider()
        };
        this._tree = this._instantiationService.createInstance(WorkbenchAsyncDataTree, this._treeContainer, new Delegate(), [
            this._instantiationService.createInstance(FileReferencesRenderer),
            this._instantiationService.createInstance(OneReferenceRenderer),
        ], this._instantiationService.createInstance(DataSource), treeOptions);
        ctxReferenceWidgetSearchTreeFocused.bindTo(this._tree.contextKeyService);
        // split stuff
        this._splitView.addView({
            onDidChange: Event.None,
            element: this._previewContainer,
            minimumSize: 200,
            maximumSize: Number.MAX_VALUE,
            layout: function (width) {
                _this._preview.layout({ height: _this._dim.height, width: width });
            }
        }, Sizing.Distribute);
        this._splitView.addView({
            onDidChange: Event.None,
            element: this._treeContainer,
            minimumSize: 100,
            maximumSize: Number.MAX_VALUE,
            layout: function (width) {
                _this._treeContainer.style.height = _this._dim.height + "px";
                _this._treeContainer.style.width = width + "px";
                _this._tree.layout(_this._dim.height, width);
            }
        }, Sizing.Distribute);
        this._disposables.add(this._splitView.onDidSashChange(function () {
            if (_this._dim.width) {
                _this.layoutData.ratio = _this._splitView.getViewSize(0) / _this._dim.width;
            }
        }, undefined));
        // listen on selection and focus
        var onEvent = function (element, kind) {
            if (element instanceof OneReference) {
                if (kind === 'show') {
                    _this._revealReference(element, false);
                }
                _this._onDidSelectReference.fire({ element: element, kind: kind, source: 'tree' });
            }
        };
        this._tree.onDidChangeFocus(function (e) {
            onEvent(e.elements[0], 'show');
        });
        this._tree.onDidChangeSelection(function (e) {
            var aside = false;
            var goto = false;
            if (e.browserEvent instanceof KeyboardEvent) {
                // todo@joh make this a command
                goto = true;
            }
            if (aside) {
                onEvent(e.elements[0], 'side');
            }
            else if (goto) {
                onEvent(e.elements[0], 'goto');
            }
            else {
                onEvent(e.elements[0], 'show');
            }
        });
        this._tree.onDidOpen(function (e) {
            var aside = (e.browserEvent instanceof MouseEvent) && (e.browserEvent.ctrlKey || e.browserEvent.metaKey || e.browserEvent.altKey);
            var goto = !e.browserEvent || ((e.browserEvent instanceof MouseEvent) && e.browserEvent.detail === 2);
            if (aside) {
                onEvent(e.elements[0], 'side');
            }
            else if (goto) {
                onEvent(e.elements[0], 'goto');
            }
            else {
                onEvent(e.elements[0], 'show');
            }
        });
        dom.hide(this._treeContainer);
    };
    ReferenceWidget.prototype._onWidth = function (width) {
        if (this._dim) {
            this._doLayoutBody(this._dim.height, width);
        }
    };
    ReferenceWidget.prototype._doLayoutBody = function (heightInPixel, widthInPixel) {
        _super.prototype._doLayoutBody.call(this, heightInPixel, widthInPixel);
        this._dim = { height: heightInPixel, width: widthInPixel };
        this.layoutData.heightInLines = this._viewZone ? this._viewZone.heightInLines : this.layoutData.heightInLines;
        this._splitView.layout(widthInPixel);
        this._splitView.resizeView(0, widthInPixel * this.layoutData.ratio);
    };
    ReferenceWidget.prototype.setSelection = function (selection) {
        var _this = this;
        return this._revealReference(selection, true).then(function () {
            if (!_this._model) {
                // disposed
                return;
            }
            // show in tree
            _this._tree.setSelection([selection]);
            _this._tree.setFocus([selection]);
        });
    };
    ReferenceWidget.prototype.setModel = function (newModel) {
        // clean up
        this._disposeOnNewModel.clear();
        this._model = newModel;
        if (this._model) {
            return this._onNewModel();
        }
        return Promise.resolve();
    };
    ReferenceWidget.prototype._onNewModel = function () {
        var _this = this;
        if (!this._model) {
            return Promise.resolve(undefined);
        }
        if (this._model.empty) {
            this.setTitle('');
            this._messageContainer.innerHTML = nls.localize('noResults', "No results");
            dom.show(this._messageContainer);
            return Promise.resolve(undefined);
        }
        dom.hide(this._messageContainer);
        this._decorationsManager = new DecorationsManager(this._preview, this._model);
        this._disposeOnNewModel.add(this._decorationsManager);
        // listen on model changes
        this._disposeOnNewModel.add(this._model.onDidChangeReferenceRange(function (reference) { return _this._tree.rerender(reference); }));
        // listen on editor
        this._disposeOnNewModel.add(this._preview.onMouseDown(function (e) {
            var event = e.event, target = e.target;
            if (event.detail !== 2) {
                return;
            }
            var element = _this._getFocusedReference();
            if (!element) {
                return;
            }
            _this._onDidSelectReference.fire({
                element: { uri: element.uri, range: target.range },
                kind: (event.ctrlKey || event.metaKey || event.altKey) ? 'side' : 'open',
                source: 'editor'
            });
        }));
        // make sure things are rendered
        dom.addClass(this.container, 'results-loaded');
        dom.show(this._treeContainer);
        dom.show(this._previewContainer);
        this._splitView.layout(this._dim.width);
        this.focus();
        // pick input and a reference to begin with
        return this._tree.setInput(this._model.groups.length === 1 ? this._model.groups[0] : this._model);
    };
    ReferenceWidget.prototype._getFocusedReference = function () {
        var element = this._tree.getFocus()[0];
        if (element instanceof OneReference) {
            return element;
        }
        else if (element instanceof FileReferences) {
            if (element.children.length > 0) {
                return element.children[0];
            }
        }
        return undefined;
    };
    ReferenceWidget.prototype._revealReference = function (reference, revealParent) {
        return __awaiter(this, void 0, void 0, function () {
            var promise, ref, model, scrollType, sel;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        // check if there is anything to do...
                        if (this._revealedReference === reference) {
                            return [2 /*return*/];
                        }
                        this._revealedReference = reference;
                        // Update widget header
                        if (reference.uri.scheme !== Schemas.inMemory) {
                            this.setTitle(basenameOrAuthority(reference.uri), this._uriLabel.getUriLabel(dirname(reference.uri)));
                        }
                        else {
                            this.setTitle(nls.localize('peekView.alternateTitle', "References"));
                        }
                        promise = this._textModelResolverService.createModelReference(reference.uri);
                        if (!(this._tree.getInput() === reference.parent)) return [3 /*break*/, 1];
                        this._tree.reveal(reference);
                        return [3 /*break*/, 3];
                    case 1:
                        if (revealParent) {
                            this._tree.reveal(reference.parent);
                        }
                        return [4 /*yield*/, this._tree.expand(reference.parent)];
                    case 2:
                        _a.sent();
                        this._tree.reveal(reference);
                        _a.label = 3;
                    case 3: return [4 /*yield*/, promise];
                    case 4:
                        ref = _a.sent();
                        if (!this._model) {
                            // disposed
                            ref.dispose();
                            return [2 /*return*/];
                        }
                        dispose(this._previewModelReference);
                        model = ref.object;
                        if (model) {
                            scrollType = this._preview.getModel() === model.textEditorModel ? 0 /* Smooth */ : 1 /* Immediate */;
                            sel = Range.lift(reference.range).collapseToStart();
                            this._previewModelReference = ref;
                            this._preview.setModel(model.textEditorModel);
                            this._preview.setSelection(sel);
                            this._preview.revealRangeInCenter(sel, scrollType);
                        }
                        else {
                            this._preview.setModel(this._previewNotAvailableMessage);
                            ref.dispose();
                        }
                        return [2 /*return*/];
                }
            });
        });
    };
    ReferenceWidget = __decorate([
        __param(3, IThemeService),
        __param(4, ITextModelService),
        __param(5, IInstantiationService),
        __param(6, IPeekViewService),
        __param(7, ILabelService)
    ], ReferenceWidget);
    return ReferenceWidget;
}(PeekViewWidget));
export { ReferenceWidget };
// theming
export var peekViewTitleBackground = registerColor('peekViewTitle.background', { dark: '#1E1E1E', light: '#FFFFFF', hc: '#0C141F' }, nls.localize('peekViewTitleBackground', 'Background color of the peek view title area.'));
export var peekViewTitleForeground = registerColor('peekViewTitleLabel.foreground', { dark: '#FFFFFF', light: '#333333', hc: '#FFFFFF' }, nls.localize('peekViewTitleForeground', 'Color of the peek view title.'));
export var peekViewTitleInfoForeground = registerColor('peekViewTitleDescription.foreground', { dark: '#ccccccb3', light: '#6c6c6cb3', hc: '#FFFFFF99' }, nls.localize('peekViewTitleInfoForeground', 'Color of the peek view title info.'));
export var peekViewBorder = registerColor('peekView.border', { dark: '#007acc', light: '#007acc', hc: contrastBorder }, nls.localize('peekViewBorder', 'Color of the peek view borders and arrow.'));
export var peekViewResultsBackground = registerColor('peekViewResult.background', { dark: '#252526', light: '#F3F3F3', hc: Color.black }, nls.localize('peekViewResultsBackground', 'Background color of the peek view result list.'));
export var peekViewResultsMatchForeground = registerColor('peekViewResult.lineForeground', { dark: '#bbbbbb', light: '#646465', hc: Color.white }, nls.localize('peekViewResultsMatchForeground', 'Foreground color for line nodes in the peek view result list.'));
export var peekViewResultsFileForeground = registerColor('peekViewResult.fileForeground', { dark: Color.white, light: '#1E1E1E', hc: Color.white }, nls.localize('peekViewResultsFileForeground', 'Foreground color for file nodes in the peek view result list.'));
export var peekViewResultsSelectionBackground = registerColor('peekViewResult.selectionBackground', { dark: '#3399ff33', light: '#3399ff33', hc: null }, nls.localize('peekViewResultsSelectionBackground', 'Background color of the selected entry in the peek view result list.'));
export var peekViewResultsSelectionForeground = registerColor('peekViewResult.selectionForeground', { dark: Color.white, light: '#6C6C6C', hc: Color.white }, nls.localize('peekViewResultsSelectionForeground', 'Foreground color of the selected entry in the peek view result list.'));
export var peekViewEditorBackground = registerColor('peekViewEditor.background', { dark: '#001F33', light: '#F2F8FC', hc: Color.black }, nls.localize('peekViewEditorBackground', 'Background color of the peek view editor.'));
export var peekViewEditorGutterBackground = registerColor('peekViewEditorGutter.background', { dark: peekViewEditorBackground, light: peekViewEditorBackground, hc: peekViewEditorBackground }, nls.localize('peekViewEditorGutterBackground', 'Background color of the gutter in the peek view editor.'));
export var peekViewResultsMatchHighlight = registerColor('peekViewResult.matchHighlightBackground', { dark: '#ea5c004d', light: '#ea5c004d', hc: null }, nls.localize('peekViewResultsMatchHighlight', 'Match highlight color in the peek view result list.'));
export var peekViewEditorMatchHighlight = registerColor('peekViewEditor.matchHighlightBackground', { dark: '#ff8f0099', light: '#f5d802de', hc: null }, nls.localize('peekViewEditorMatchHighlight', 'Match highlight color in the peek view editor.'));
export var peekViewEditorMatchHighlightBorder = registerColor('peekViewEditor.matchHighlightBorder', { dark: null, light: null, hc: activeContrastBorder }, nls.localize('peekViewEditorMatchHighlightBorder', 'Match highlight border in the peek view editor.'));
registerThemingParticipant(function (theme, collector) {
    var findMatchHighlightColor = theme.getColor(peekViewResultsMatchHighlight);
    if (findMatchHighlightColor) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree .referenceMatch .highlight { background-color: " + findMatchHighlightColor + "; }");
    }
    var referenceHighlightColor = theme.getColor(peekViewEditorMatchHighlight);
    if (referenceHighlightColor) {
        collector.addRule(".monaco-editor .reference-zone-widget .preview .reference-decoration { background-color: " + referenceHighlightColor + "; }");
    }
    var referenceHighlightBorder = theme.getColor(peekViewEditorMatchHighlightBorder);
    if (referenceHighlightBorder) {
        collector.addRule(".monaco-editor .reference-zone-widget .preview .reference-decoration { border: 2px solid " + referenceHighlightBorder + "; box-sizing: border-box; }");
    }
    var hcOutline = theme.getColor(activeContrastBorder);
    if (hcOutline) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree .referenceMatch .highlight { border: 1px dotted " + hcOutline + "; box-sizing: border-box; }");
    }
    var resultsBackground = theme.getColor(peekViewResultsBackground);
    if (resultsBackground) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree { background-color: " + resultsBackground + "; }");
    }
    var resultsMatchForeground = theme.getColor(peekViewResultsMatchForeground);
    if (resultsMatchForeground) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree { color: " + resultsMatchForeground + "; }");
    }
    var resultsFileForeground = theme.getColor(peekViewResultsFileForeground);
    if (resultsFileForeground) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree .reference-file { color: " + resultsFileForeground + "; }");
    }
    var resultsSelectedBackground = theme.getColor(peekViewResultsSelectionBackground);
    if (resultsSelectedBackground) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree .monaco-list:focus .monaco-list-rows > .monaco-list-row.selected:not(.highlighted) { background-color: " + resultsSelectedBackground + "; }");
    }
    var resultsSelectedForeground = theme.getColor(peekViewResultsSelectionForeground);
    if (resultsSelectedForeground) {
        collector.addRule(".monaco-editor .reference-zone-widget .ref-tree .monaco-list:focus .monaco-list-rows > .monaco-list-row.selected:not(.highlighted) { color: " + resultsSelectedForeground + " !important; }");
    }
    var editorBackground = theme.getColor(peekViewEditorBackground);
    if (editorBackground) {
        collector.addRule(".monaco-editor .reference-zone-widget .preview .monaco-editor .monaco-editor-background," +
            ".monaco-editor .reference-zone-widget .preview .monaco-editor .inputarea.ime-input {" +
            ("\tbackground-color: " + editorBackground + ";") +
            "}");
    }
    var editorGutterBackground = theme.getColor(peekViewEditorGutterBackground);
    if (editorGutterBackground) {
        collector.addRule(".monaco-editor .reference-zone-widget .preview .monaco-editor .margin {" +
            ("\tbackground-color: " + editorGutterBackground + ";") +
            "}");
    }
});
