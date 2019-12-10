/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
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
import './media/suggest.css';
import * as nls from '../../../nls.js';
import { createMatches } from '../../../base/common/filters.js';
import * as strings from '../../../base/common/strings.js';
import { Event, Emitter } from '../../../base/common/event.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { dispose, toDisposable, DisposableStore, Disposable } from '../../../base/common/lifecycle.js';
import { addClass, append, $, hide, removeClass, show, toggleClass, getDomNodePagePosition, hasClass, addDisposableListener } from '../../../base/browser/dom.js';
import { List } from '../../../base/browser/ui/list/listWidget.js';
import { DomScrollableElement } from '../../../base/browser/ui/scrollbar/scrollableElement.js';
import { IKeybindingService } from '../../../platform/keybinding/common/keybinding.js';
import { IContextKeyService } from '../../../platform/contextkey/common/contextkey.js';
import { Context as SuggestContext } from './suggest.js';
import { alert } from '../../../base/browser/ui/aria/aria.js';
import { ITelemetryService } from '../../../platform/telemetry/common/telemetry.js';
import { attachListStyler } from '../../../platform/theme/common/styler.js';
import { IThemeService, registerThemingParticipant } from '../../../platform/theme/common/themeService.js';
import { registerColor, editorWidgetBackground, listFocusBackground, activeContrastBorder, listHighlightForeground, editorForeground, editorWidgetBorder, focusBorder, textLinkForeground, textCodeBlockBackground } from '../../../platform/theme/common/colorRegistry.js';
import { IStorageService } from '../../../platform/storage/common/storage.js';
import { MarkdownRenderer } from '../markdown/markdownRenderer.js';
import { IModeService } from '../../common/services/modeService.js';
import { IOpenerService } from '../../../platform/opener/common/opener.js';
import { TimeoutTimer, createCancelablePromise, disposableTimeout } from '../../../base/common/async.js';
import { completionKindToCssClass } from '../../common/modes.js';
import { IconLabel } from '../../../base/browser/ui/iconLabel/iconLabel.js';
import { getIconClasses } from '../../common/services/getIconClasses.js';
import { IModelService } from '../../common/services/modelService.js';
import { URI } from '../../../base/common/uri.js';
import { IInstantiationService } from '../../../platform/instantiation/common/instantiation.js';
import { FileKind } from '../../../platform/files/common/files.js';
import { MarkdownString } from '../../../base/common/htmlContent.js';
import { flatten } from '../../../base/common/arrays.js';
var expandSuggestionDocsByDefault = false;
/**
 * Suggest widget colors
 */
export var editorSuggestWidgetBackground = registerColor('editorSuggestWidget.background', { dark: editorWidgetBackground, light: editorWidgetBackground, hc: editorWidgetBackground }, nls.localize('editorSuggestWidgetBackground', 'Background color of the suggest widget.'));
export var editorSuggestWidgetBorder = registerColor('editorSuggestWidget.border', { dark: editorWidgetBorder, light: editorWidgetBorder, hc: editorWidgetBorder }, nls.localize('editorSuggestWidgetBorder', 'Border color of the suggest widget.'));
export var editorSuggestWidgetForeground = registerColor('editorSuggestWidget.foreground', { dark: editorForeground, light: editorForeground, hc: editorForeground }, nls.localize('editorSuggestWidgetForeground', 'Foreground color of the suggest widget.'));
export var editorSuggestWidgetSelectedBackground = registerColor('editorSuggestWidget.selectedBackground', { dark: listFocusBackground, light: listFocusBackground, hc: listFocusBackground }, nls.localize('editorSuggestWidgetSelectedBackground', 'Background color of the selected entry in the suggest widget.'));
export var editorSuggestWidgetHighlightForeground = registerColor('editorSuggestWidget.highlightForeground', { dark: listHighlightForeground, light: listHighlightForeground, hc: listHighlightForeground }, nls.localize('editorSuggestWidgetHighlightForeground', 'Color of the match highlights in the suggest widget.'));
var colorRegExp = /^(#([\da-f]{3}){1,2}|(rgb|hsl)a\(\s*(\d{1,3}%?\s*,\s*){3}(1|0?\.\d+)\)|(rgb|hsl)\(\s*\d{1,3}%?(\s*,\s*\d{1,3}%?){2}\s*\))$/i;
function extractColor(item, out) {
    if (item.completion.label.match(colorRegExp)) {
        out[0] = item.completion.label;
        return true;
    }
    if (typeof item.completion.documentation === 'string' && item.completion.documentation.match(colorRegExp)) {
        out[0] = item.completion.documentation;
        return true;
    }
    return false;
}
function canExpandCompletionItem(item) {
    if (!item) {
        return false;
    }
    var suggestion = item.completion;
    if (suggestion.documentation) {
        return true;
    }
    return (suggestion.detail && suggestion.detail !== suggestion.label);
}
var Renderer = /** @class */ (function () {
    function Renderer(widget, editor, triggerKeybindingLabel, _modelService, _modeService, _themeService) {
        this.widget = widget;
        this.editor = editor;
        this.triggerKeybindingLabel = triggerKeybindingLabel;
        this._modelService = _modelService;
        this._modeService = _modeService;
        this._themeService = _themeService;
    }
    Object.defineProperty(Renderer.prototype, "templateId", {
        get: function () {
            return 'suggestion';
        },
        enumerable: true,
        configurable: true
    });
    Renderer.prototype.renderTemplate = function (container) {
        var _this = this;
        var data = Object.create(null);
        data.disposables = new DisposableStore();
        data.root = container;
        addClass(data.root, 'show-file-icons');
        data.icon = append(container, $('.icon'));
        data.colorspan = append(data.icon, $('span.colorspan'));
        var text = append(container, $('.contents'));
        var main = append(text, $('.main'));
        data.iconLabel = new IconLabel(main, { supportHighlights: true, supportOcticons: true });
        data.disposables.add(data.iconLabel);
        data.typeLabel = append(main, $('span.type-label'));
        data.readMore = append(main, $('span.readMore'));
        data.readMore.title = nls.localize('readMore', "Read More...{0}", this.triggerKeybindingLabel);
        var configureFont = function () {
            var configuration = _this.editor.getConfiguration();
            var fontFamily = configuration.fontInfo.fontFamily;
            var fontSize = configuration.contribInfo.suggestFontSize || configuration.fontInfo.fontSize;
            var lineHeight = configuration.contribInfo.suggestLineHeight || configuration.fontInfo.lineHeight;
            var fontWeight = configuration.fontInfo.fontWeight;
            var fontSizePx = fontSize + "px";
            var lineHeightPx = lineHeight + "px";
            data.root.style.fontSize = fontSizePx;
            data.root.style.fontWeight = fontWeight;
            main.style.fontFamily = fontFamily;
            main.style.lineHeight = lineHeightPx;
            data.icon.style.height = lineHeightPx;
            data.icon.style.width = lineHeightPx;
            data.readMore.style.height = lineHeightPx;
            data.readMore.style.width = lineHeightPx;
        };
        configureFont();
        data.disposables.add(Event.chain(this.editor.onDidChangeConfiguration.bind(this.editor))
            .filter(function (e) { return e.fontInfo || e.contribInfo; })
            .on(configureFont, null));
        return data;
    };
    Renderer.prototype.renderElement = function (element, _index, templateData) {
        var _this = this;
        var data = templateData;
        var suggestion = element.completion;
        data.icon.className = 'icon ' + completionKindToCssClass(suggestion.kind);
        data.colorspan.style.backgroundColor = '';
        var labelOptions = {
            labelEscapeNewLines: true,
            matches: createMatches(element.score)
        };
        var color = [];
        if (suggestion.kind === 19 /* Color */ && extractColor(element, color)) {
            // special logic for 'color' completion items
            data.icon.className = 'icon customcolor';
            data.colorspan.style.backgroundColor = color[0];
        }
        else if (suggestion.kind === 20 /* File */ && this._themeService.getIconTheme().hasFileIcons) {
            // special logic for 'file' completion items
            data.icon.className = 'icon hide';
            labelOptions.extraClasses = flatten([
                getIconClasses(this._modelService, this._modeService, URI.from({ scheme: 'fake', path: suggestion.label }), FileKind.FILE),
                getIconClasses(this._modelService, this._modeService, URI.from({ scheme: 'fake', path: suggestion.detail }), FileKind.FILE)
            ]);
        }
        else if (suggestion.kind === 23 /* Folder */ && this._themeService.getIconTheme().hasFolderIcons) {
            // special logic for 'folder' completion items
            data.icon.className = 'icon hide';
            labelOptions.extraClasses = flatten([
                getIconClasses(this._modelService, this._modeService, URI.from({ scheme: 'fake', path: suggestion.label }), FileKind.FOLDER),
                getIconClasses(this._modelService, this._modeService, URI.from({ scheme: 'fake', path: suggestion.detail }), FileKind.FOLDER)
            ]);
        }
        else {
            // normal icon
            data.icon.className = 'icon hide';
            labelOptions.extraClasses = [
                "suggest-icon " + completionKindToCssClass(suggestion.kind)
            ];
        }
        if (suggestion.tags && suggestion.tags.indexOf(1 /* Deprecated */) >= 0) {
            labelOptions.extraClasses = (labelOptions.extraClasses || []).concat(['deprecated']);
            labelOptions.matches = [];
        }
        data.iconLabel.setLabel(suggestion.label, undefined, labelOptions);
        data.typeLabel.textContent = (suggestion.detail || '').replace(/\n.*$/m, '');
        if (canExpandCompletionItem(element)) {
            show(data.readMore);
            data.readMore.onmousedown = function (e) {
                e.stopPropagation();
                e.preventDefault();
            };
            data.readMore.onclick = function (e) {
                e.stopPropagation();
                e.preventDefault();
                _this.widget.toggleDetails();
            };
        }
        else {
            hide(data.readMore);
            data.readMore.onmousedown = null;
            data.readMore.onclick = null;
        }
    };
    Renderer.prototype.disposeTemplate = function (templateData) {
        templateData.disposables.dispose();
    };
    Renderer = __decorate([
        __param(3, IModelService),
        __param(4, IModeService),
        __param(5, IThemeService)
    ], Renderer);
    return Renderer;
}());
var SuggestionDetails = /** @class */ (function () {
    function SuggestionDetails(container, widget, editor, markdownRenderer, triggerKeybindingLabel) {
        var _this = this;
        this.widget = widget;
        this.editor = editor;
        this.markdownRenderer = markdownRenderer;
        this.triggerKeybindingLabel = triggerKeybindingLabel;
        this.borderWidth = 1;
        this.disposables = new DisposableStore();
        this.el = append(container, $('.details'));
        this.disposables.add(toDisposable(function () { return container.removeChild(_this.el); }));
        this.body = $('.body');
        this.scrollbar = new DomScrollableElement(this.body, {});
        append(this.el, this.scrollbar.getDomNode());
        this.disposables.add(this.scrollbar);
        this.header = append(this.body, $('.header'));
        this.close = append(this.header, $('span.close'));
        this.close.title = nls.localize('readLess', "Read less...{0}", this.triggerKeybindingLabel);
        this.type = append(this.header, $('p.type'));
        this.docs = append(this.body, $('p.docs'));
        this.ariaLabel = null;
        this.configureFont();
        Event.chain(this.editor.onDidChangeConfiguration.bind(this.editor))
            .filter(function (e) { return e.fontInfo; })
            .on(this.configureFont, this, this.disposables);
        markdownRenderer.onDidRenderCodeBlock(function () { return _this.scrollbar.scanDomNode(); }, this, this.disposables);
    }
    Object.defineProperty(SuggestionDetails.prototype, "element", {
        get: function () {
            return this.el;
        },
        enumerable: true,
        configurable: true
    });
    SuggestionDetails.prototype.renderLoading = function () {
        this.type.textContent = nls.localize('loading', "Loading...");
        this.docs.textContent = '';
    };
    SuggestionDetails.prototype.renderItem = function (item, explainMode) {
        var _this = this;
        this.renderDisposeable = dispose(this.renderDisposeable);
        var _a = item.completion, documentation = _a.documentation, detail = _a.detail;
        // --- documentation
        if (explainMode) {
            var md = '';
            md += "score: " + item.score[0] + (item.word ? ", compared '" + (item.completion.filterText && (item.completion.filterText + ' (filterText)') || item.completion.label) + "' with '" + item.word + "'" : ' (no prefix)') + "\n";
            md += "distance: " + item.distance + ", see localityBonus-setting\n";
            md += "index: " + item.idx + ", based on " + (item.completion.sortText && "sortText: \"" + item.completion.sortText + "\"" || 'label') + "\n";
            documentation = new MarkdownString().appendCodeblock('empty', md);
            detail = "Provider: " + item.provider._debugDisplayName;
        }
        if (!explainMode && !canExpandCompletionItem(item)) {
            this.type.textContent = '';
            this.docs.textContent = '';
            addClass(this.el, 'no-docs');
            this.ariaLabel = null;
            return;
        }
        removeClass(this.el, 'no-docs');
        if (typeof documentation === 'string') {
            removeClass(this.docs, 'markdown-docs');
            this.docs.textContent = documentation;
        }
        else {
            addClass(this.docs, 'markdown-docs');
            this.docs.innerHTML = '';
            var renderedContents = this.markdownRenderer.render(documentation);
            this.renderDisposeable = renderedContents;
            this.docs.appendChild(renderedContents.element);
        }
        // --- details
        if (detail) {
            this.type.innerText = detail;
            show(this.type);
        }
        else {
            this.type.innerText = '';
            hide(this.type);
        }
        this.el.style.height = this.header.offsetHeight + this.docs.offsetHeight + (this.borderWidth * 2) + 'px';
        this.close.onmousedown = function (e) {
            e.preventDefault();
            e.stopPropagation();
        };
        this.close.onclick = function (e) {
            e.preventDefault();
            e.stopPropagation();
            _this.widget.toggleDetails();
        };
        this.body.scrollTop = 0;
        this.scrollbar.scanDomNode();
        this.ariaLabel = strings.format('{0}{1}', detail || '', documentation ? (typeof documentation === 'string' ? documentation : documentation.value) : '');
    };
    SuggestionDetails.prototype.getAriaLabel = function () {
        return this.ariaLabel;
    };
    SuggestionDetails.prototype.scrollDown = function (much) {
        if (much === void 0) { much = 8; }
        this.body.scrollTop += much;
    };
    SuggestionDetails.prototype.scrollUp = function (much) {
        if (much === void 0) { much = 8; }
        this.body.scrollTop -= much;
    };
    SuggestionDetails.prototype.scrollTop = function () {
        this.body.scrollTop = 0;
    };
    SuggestionDetails.prototype.scrollBottom = function () {
        this.body.scrollTop = this.body.scrollHeight;
    };
    SuggestionDetails.prototype.pageDown = function () {
        this.scrollDown(80);
    };
    SuggestionDetails.prototype.pageUp = function () {
        this.scrollUp(80);
    };
    SuggestionDetails.prototype.setBorderWidth = function (width) {
        this.borderWidth = width;
    };
    SuggestionDetails.prototype.configureFont = function () {
        var configuration = this.editor.getConfiguration();
        var fontFamily = configuration.fontInfo.fontFamily;
        var fontSize = configuration.contribInfo.suggestFontSize || configuration.fontInfo.fontSize;
        var lineHeight = configuration.contribInfo.suggestLineHeight || configuration.fontInfo.lineHeight;
        var fontWeight = configuration.fontInfo.fontWeight;
        var fontSizePx = fontSize + "px";
        var lineHeightPx = lineHeight + "px";
        this.el.style.fontSize = fontSizePx;
        this.el.style.fontWeight = fontWeight;
        this.type.style.fontFamily = fontFamily;
        this.close.style.height = lineHeightPx;
        this.close.style.width = lineHeightPx;
    };
    SuggestionDetails.prototype.dispose = function () {
        this.disposables.dispose();
        this.renderDisposeable = dispose(this.renderDisposeable);
    };
    return SuggestionDetails;
}());
var SuggestWidget = /** @class */ (function () {
    function SuggestWidget(editor, telemetryService, contextKeyService, themeService, storageService, keybindingService, modeService, openerService, instantiationService) {
        var _this = this;
        this.editor = editor;
        this.telemetryService = telemetryService;
        // Editor.IContentWidget.allowEditorOverflow
        this.allowEditorOverflow = true;
        this.suppressMouseDown = true;
        this.state = null;
        this.isAuto = false;
        this.loadingTimeout = Disposable.None;
        this.currentSuggestionDetails = null;
        this.ignoreFocusEvents = false;
        this.completionModel = null;
        this.showTimeout = new TimeoutTimer();
        this.toDispose = new DisposableStore();
        this.onDidSelectEmitter = new Emitter();
        this.onDidFocusEmitter = new Emitter();
        this.onDidHideEmitter = new Emitter();
        this.onDidShowEmitter = new Emitter();
        this.onDidSelect = this.onDidSelectEmitter.event;
        this.onDidFocus = this.onDidFocusEmitter.event;
        this.onDidHide = this.onDidHideEmitter.event;
        this.onDidShow = this.onDidShowEmitter.event;
        this.maxWidgetWidth = 660;
        this.listWidth = 330;
        this.firstFocusInCurrentList = false;
        this.preferDocPositionTop = false;
        this.docsPositionPreviousWidgetY = null;
        this.explainMode = false;
        this._lastAriaAlertLabel = null;
        var kb = keybindingService.lookupKeybinding('editor.action.triggerSuggest');
        var triggerKeybindingLabel = !kb ? '' : " (" + kb.getLabel() + ")";
        var markdownRenderer = this.toDispose.add(new MarkdownRenderer(editor, modeService, openerService));
        this.isAuto = false;
        this.focusedItem = null;
        this.storageService = storageService;
        this.element = $('.editor-widget.suggest-widget');
        this.toDispose.add(addDisposableListener(this.element, 'click', function (e) {
            if (e.target === _this.element) {
                _this.hideWidget();
            }
        }));
        this.messageElement = append(this.element, $('.message'));
        this.listElement = append(this.element, $('.tree'));
        this.details = instantiationService.createInstance(SuggestionDetails, this.element, this, this.editor, markdownRenderer, triggerKeybindingLabel);
        var applyIconStyle = function () { return toggleClass(_this.element, 'no-icons', !_this.editor.getConfiguration().contribInfo.suggest.showIcons); };
        applyIconStyle();
        var renderer = instantiationService.createInstance(Renderer, this, this.editor, triggerKeybindingLabel);
        this.list = new List(this.listElement, this, [renderer], {
            useShadows: false,
            openController: { shouldOpen: function () { return false; } },
            mouseSupport: false
        });
        this.toDispose.add(attachListStyler(this.list, themeService, {
            listInactiveFocusBackground: editorSuggestWidgetSelectedBackground,
            listInactiveFocusOutline: activeContrastBorder
        }));
        this.toDispose.add(themeService.onThemeChange(function (t) { return _this.onThemeChange(t); }));
        this.toDispose.add(editor.onDidLayoutChange(function () { return _this.onEditorLayoutChange(); }));
        this.toDispose.add(this.list.onMouseDown(function (e) { return _this.onListMouseDown(e); }));
        this.toDispose.add(this.list.onSelectionChange(function (e) { return _this.onListSelection(e); }));
        this.toDispose.add(this.list.onFocusChange(function (e) { return _this.onListFocus(e); }));
        this.toDispose.add(this.editor.onDidChangeCursorSelection(function () { return _this.onCursorSelectionChanged(); }));
        this.toDispose.add(this.editor.onDidChangeConfiguration(function (e) { return e.contribInfo && applyIconStyle(); }));
        this.suggestWidgetVisible = SuggestContext.Visible.bindTo(contextKeyService);
        this.suggestWidgetMultipleSuggestions = SuggestContext.MultipleSuggestions.bindTo(contextKeyService);
        this.editor.addContentWidget(this);
        this.setState(0 /* Hidden */);
        this.onThemeChange(themeService.getTheme());
    }
    SuggestWidget.prototype.onCursorSelectionChanged = function () {
        if (this.state === 0 /* Hidden */) {
            return;
        }
        this.editor.layoutContentWidget(this);
    };
    SuggestWidget.prototype.onEditorLayoutChange = function () {
        if ((this.state === 3 /* Open */ || this.state === 5 /* Details */) && this.expandDocsSettingFromStorage()) {
            this.expandSideOrBelow();
        }
    };
    SuggestWidget.prototype.onListMouseDown = function (e) {
        if (typeof e.element === 'undefined' || typeof e.index === 'undefined') {
            return;
        }
        // prevent stealing browser focus from the editor
        e.browserEvent.preventDefault();
        e.browserEvent.stopPropagation();
        this.select(e.element, e.index);
    };
    SuggestWidget.prototype.onListSelection = function (e) {
        if (!e.elements.length) {
            return;
        }
        this.select(e.elements[0], e.indexes[0]);
    };
    SuggestWidget.prototype.select = function (item, index) {
        var completionModel = this.completionModel;
        if (!completionModel) {
            return;
        }
        this.onDidSelectEmitter.fire({ item: item, index: index, model: completionModel });
        this.editor.focus();
    };
    SuggestWidget.prototype._getSuggestionAriaAlertLabel = function (item) {
        if (this.expandDocsSettingFromStorage()) {
            return nls.localize('ariaCurrenttSuggestionReadDetails', "Item {0}, docs: {1}", item.completion.label, this.details.getAriaLabel());
        }
        else {
            return item.completion.label;
        }
    };
    SuggestWidget.prototype._ariaAlert = function (newAriaAlertLabel) {
        if (this._lastAriaAlertLabel === newAriaAlertLabel) {
            return;
        }
        this._lastAriaAlertLabel = newAriaAlertLabel;
        if (this._lastAriaAlertLabel) {
            alert(this._lastAriaAlertLabel, true);
        }
    };
    SuggestWidget.prototype.onThemeChange = function (theme) {
        var backgroundColor = theme.getColor(editorSuggestWidgetBackground);
        if (backgroundColor) {
            this.listElement.style.backgroundColor = backgroundColor.toString();
            this.details.element.style.backgroundColor = backgroundColor.toString();
            this.messageElement.style.backgroundColor = backgroundColor.toString();
        }
        var borderColor = theme.getColor(editorSuggestWidgetBorder);
        if (borderColor) {
            this.listElement.style.borderColor = borderColor.toString();
            this.details.element.style.borderColor = borderColor.toString();
            this.messageElement.style.borderColor = borderColor.toString();
            this.detailsBorderColor = borderColor.toString();
        }
        var focusBorderColor = theme.getColor(focusBorder);
        if (focusBorderColor) {
            this.detailsFocusBorderColor = focusBorderColor.toString();
        }
        this.details.setBorderWidth(theme.type === 'hc' ? 2 : 1);
    };
    SuggestWidget.prototype.onListFocus = function (e) {
        var _this = this;
        if (this.ignoreFocusEvents) {
            return;
        }
        if (!e.elements.length) {
            if (this.currentSuggestionDetails) {
                this.currentSuggestionDetails.cancel();
                this.currentSuggestionDetails = null;
                this.focusedItem = null;
            }
            this._ariaAlert(null);
            return;
        }
        if (!this.completionModel) {
            return;
        }
        var item = e.elements[0];
        var index = e.indexes[0];
        this.firstFocusInCurrentList = !this.focusedItem;
        if (item !== this.focusedItem) {
            if (this.currentSuggestionDetails) {
                this.currentSuggestionDetails.cancel();
                this.currentSuggestionDetails = null;
            }
            this.focusedItem = item;
            this.list.reveal(index);
            this.currentSuggestionDetails = createCancelablePromise(function (token) { return __awaiter(_this, void 0, void 0, function () {
                var loading, result;
                var _this = this;
                return __generator(this, function (_a) {
                    switch (_a.label) {
                        case 0:
                            loading = disposableTimeout(function () { return _this.showDetails(true); }, 250);
                            token.onCancellationRequested(function () { return loading.dispose(); });
                            return [4 /*yield*/, item.resolve(token)];
                        case 1:
                            result = _a.sent();
                            loading.dispose();
                            return [2 /*return*/, result];
                    }
                });
            }); });
            this.currentSuggestionDetails.then(function () {
                if (index >= _this.list.length || item !== _this.list.element(index)) {
                    return;
                }
                // item can have extra information, so re-render
                _this.ignoreFocusEvents = true;
                _this.list.splice(index, 1, [item]);
                _this.list.setFocus([index]);
                _this.ignoreFocusEvents = false;
                if (_this.expandDocsSettingFromStorage()) {
                    _this.showDetails(false);
                }
                else {
                    removeClass(_this.element, 'docs-side');
                }
                _this._ariaAlert(_this._getSuggestionAriaAlertLabel(item));
            }).catch(onUnexpectedError);
        }
        // emit an event
        this.onDidFocusEmitter.fire({ item: item, index: index, model: this.completionModel });
    };
    SuggestWidget.prototype.setState = function (state) {
        if (!this.element) {
            return;
        }
        var stateChanged = this.state !== state;
        this.state = state;
        toggleClass(this.element, 'frozen', state === 4 /* Frozen */);
        switch (state) {
            case 0 /* Hidden */:
                hide(this.messageElement, this.details.element, this.listElement);
                this.hide();
                this.listHeight = 0;
                if (stateChanged) {
                    this.list.splice(0, this.list.length);
                }
                this.focusedItem = null;
                break;
            case 1 /* Loading */:
                this.messageElement.textContent = SuggestWidget.LOADING_MESSAGE;
                hide(this.listElement, this.details.element);
                show(this.messageElement);
                removeClass(this.element, 'docs-side');
                this.show();
                this.focusedItem = null;
                break;
            case 2 /* Empty */:
                this.messageElement.textContent = SuggestWidget.NO_SUGGESTIONS_MESSAGE;
                hide(this.listElement, this.details.element);
                show(this.messageElement);
                removeClass(this.element, 'docs-side');
                this.show();
                this.focusedItem = null;
                break;
            case 3 /* Open */:
                hide(this.messageElement);
                show(this.listElement);
                this.show();
                break;
            case 4 /* Frozen */:
                hide(this.messageElement);
                show(this.listElement);
                this.show();
                break;
            case 5 /* Details */:
                hide(this.messageElement);
                show(this.details.element, this.listElement);
                this.show();
                this._ariaAlert(this.details.getAriaLabel());
                break;
        }
    };
    SuggestWidget.prototype.showTriggered = function (auto, delay) {
        var _this = this;
        if (this.state !== 0 /* Hidden */) {
            return;
        }
        this.isAuto = !!auto;
        if (!this.isAuto) {
            this.loadingTimeout = disposableTimeout(function () { return _this.setState(1 /* Loading */); }, delay);
        }
    };
    SuggestWidget.prototype.showSuggestions = function (completionModel, selectionIndex, isFrozen, isAuto) {
        this.preferDocPositionTop = false;
        this.docsPositionPreviousWidgetY = null;
        this.loadingTimeout.dispose();
        if (this.currentSuggestionDetails) {
            this.currentSuggestionDetails.cancel();
            this.currentSuggestionDetails = null;
        }
        if (this.completionModel !== completionModel) {
            this.completionModel = completionModel;
        }
        if (isFrozen && this.state !== 2 /* Empty */ && this.state !== 0 /* Hidden */) {
            this.setState(4 /* Frozen */);
            return;
        }
        var visibleCount = this.completionModel.items.length;
        var isEmpty = visibleCount === 0;
        this.suggestWidgetMultipleSuggestions.set(visibleCount > 1);
        if (isEmpty) {
            if (isAuto) {
                this.setState(0 /* Hidden */);
            }
            else {
                this.setState(2 /* Empty */);
            }
            this.completionModel = null;
        }
        else {
            if (this.state !== 3 /* Open */) {
                var stats = this.completionModel.stats;
                stats['wasAutomaticallyTriggered'] = !!isAuto;
                /* __GDPR__
                    "suggestWidget" : {
                        "wasAutomaticallyTriggered" : { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true },
                        "${include}": [
                            "${ICompletionStats}"
                        ]
                    }
                */
                this.telemetryService.publicLog('suggestWidget', __assign({}, stats));
            }
            this.focusedItem = null;
            this.list.splice(0, this.list.length, this.completionModel.items);
            if (isFrozen) {
                this.setState(4 /* Frozen */);
            }
            else {
                this.setState(3 /* Open */);
            }
            this.list.reveal(selectionIndex, 0);
            this.list.setFocus([selectionIndex]);
            // Reset focus border
            if (this.detailsBorderColor) {
                this.details.element.style.borderColor = this.detailsBorderColor;
            }
        }
    };
    SuggestWidget.prototype.selectNextPage = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 5 /* Details */:
                this.details.pageDown();
                return true;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusNextPage();
                return true;
        }
    };
    SuggestWidget.prototype.selectNext = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusNext(1, true);
                return true;
        }
    };
    SuggestWidget.prototype.selectLast = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 5 /* Details */:
                this.details.scrollBottom();
                return true;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusLast();
                return true;
        }
    };
    SuggestWidget.prototype.selectPreviousPage = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 5 /* Details */:
                this.details.pageUp();
                return true;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusPreviousPage();
                return true;
        }
    };
    SuggestWidget.prototype.selectPrevious = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusPrevious(1, true);
                return false;
        }
    };
    SuggestWidget.prototype.selectFirst = function () {
        switch (this.state) {
            case 0 /* Hidden */:
                return false;
            case 5 /* Details */:
                this.details.scrollTop();
                return true;
            case 1 /* Loading */:
                return !this.isAuto;
            default:
                this.list.focusFirst();
                return true;
        }
    };
    SuggestWidget.prototype.getFocusedItem = function () {
        if (this.state !== 0 /* Hidden */
            && this.state !== 2 /* Empty */
            && this.state !== 1 /* Loading */
            && this.completionModel) {
            return {
                item: this.list.getFocusedElements()[0],
                index: this.list.getFocus()[0],
                model: this.completionModel
            };
        }
        return undefined;
    };
    SuggestWidget.prototype.toggleDetailsFocus = function () {
        if (this.state === 5 /* Details */) {
            this.setState(3 /* Open */);
            if (this.detailsBorderColor) {
                this.details.element.style.borderColor = this.detailsBorderColor;
            }
        }
        else if (this.state === 3 /* Open */ && this.expandDocsSettingFromStorage()) {
            this.setState(5 /* Details */);
            if (this.detailsFocusBorderColor) {
                this.details.element.style.borderColor = this.detailsFocusBorderColor;
            }
        }
        this.telemetryService.publicLog2('suggestWidget:toggleDetailsFocus');
    };
    SuggestWidget.prototype.toggleDetails = function () {
        if (!canExpandCompletionItem(this.list.getFocusedElements()[0])) {
            return;
        }
        if (this.expandDocsSettingFromStorage()) {
            this.updateExpandDocsSetting(false);
            hide(this.details.element);
            removeClass(this.element, 'docs-side');
            removeClass(this.element, 'docs-below');
            this.editor.layoutContentWidget(this);
            this.telemetryService.publicLog2('suggestWidget:collapseDetails');
        }
        else {
            if (this.state !== 3 /* Open */ && this.state !== 5 /* Details */ && this.state !== 4 /* Frozen */) {
                return;
            }
            this.updateExpandDocsSetting(true);
            this.showDetails(false);
            this._ariaAlert(this.details.getAriaLabel());
            this.telemetryService.publicLog2('suggestWidget:expandDetails');
        }
    };
    SuggestWidget.prototype.showDetails = function (loading) {
        this.expandSideOrBelow();
        show(this.details.element);
        this.details.element.style.maxHeight = this.maxWidgetHeight + 'px';
        if (loading) {
            this.details.renderLoading();
        }
        else {
            this.details.renderItem(this.list.getFocusedElements()[0], this.explainMode);
        }
        // Reset margin-top that was set as Fix for #26416
        this.listElement.style.marginTop = '0px';
        // with docs showing up widget width/height may change, so reposition the widget
        this.editor.layoutContentWidget(this);
        this.adjustDocsPosition();
        this.editor.focus();
    };
    SuggestWidget.prototype.toggleExplainMode = function () {
        if (this.list.getFocusedElements()[0] && this.expandDocsSettingFromStorage()) {
            this.explainMode = !this.explainMode;
            this.showDetails(false);
        }
    };
    SuggestWidget.prototype.show = function () {
        var _this = this;
        var newHeight = this.updateListHeight();
        if (newHeight !== this.listHeight) {
            this.editor.layoutContentWidget(this);
            this.listHeight = newHeight;
        }
        this.suggestWidgetVisible.set(true);
        this.showTimeout.cancelAndSet(function () {
            addClass(_this.element, 'visible');
            _this.onDidShowEmitter.fire(_this);
        }, 100);
    };
    SuggestWidget.prototype.hide = function () {
        this.suggestWidgetVisible.reset();
        this.suggestWidgetMultipleSuggestions.reset();
        removeClass(this.element, 'visible');
    };
    SuggestWidget.prototype.hideWidget = function () {
        this.loadingTimeout.dispose();
        this.setState(0 /* Hidden */);
        this.onDidHideEmitter.fire(this);
    };
    SuggestWidget.prototype.getPosition = function () {
        if (this.state === 0 /* Hidden */) {
            return null;
        }
        var preference = [2 /* BELOW */, 1 /* ABOVE */];
        if (this.preferDocPositionTop) {
            preference = [1 /* ABOVE */];
        }
        return {
            position: this.editor.getPosition(),
            preference: preference
        };
    };
    SuggestWidget.prototype.getDomNode = function () {
        return this.element;
    };
    SuggestWidget.prototype.getId = function () {
        return SuggestWidget.ID;
    };
    SuggestWidget.prototype.updateListHeight = function () {
        var height = 0;
        if (this.state === 2 /* Empty */ || this.state === 1 /* Loading */) {
            height = this.unfocusedHeight;
        }
        else {
            var suggestionCount = this.list.contentHeight / this.unfocusedHeight;
            var maxVisibleSuggestions = this.editor.getConfiguration().contribInfo.suggest.maxVisibleSuggestions;
            height = Math.min(suggestionCount, maxVisibleSuggestions) * this.unfocusedHeight;
        }
        this.element.style.lineHeight = this.unfocusedHeight + "px";
        this.listElement.style.height = height + "px";
        this.list.layout(height);
        return height;
    };
    /**
     * Adds the propert classes, margins when positioning the docs to the side
     */
    SuggestWidget.prototype.adjustDocsPosition = function () {
        if (!this.editor.hasModel()) {
            return;
        }
        var lineHeight = this.editor.getConfiguration().fontInfo.lineHeight;
        var cursorCoords = this.editor.getScrolledVisiblePosition(this.editor.getPosition());
        var editorCoords = getDomNodePagePosition(this.editor.getDomNode());
        var cursorX = editorCoords.left + cursorCoords.left;
        var cursorY = editorCoords.top + cursorCoords.top + cursorCoords.height;
        var widgetCoords = getDomNodePagePosition(this.element);
        var widgetX = widgetCoords.left;
        var widgetY = widgetCoords.top;
        // Fixes #27649
        // Check if the Y changed to the top of the cursor and keep the widget flagged to prefer top
        if (this.docsPositionPreviousWidgetY &&
            this.docsPositionPreviousWidgetY < widgetY &&
            !this.preferDocPositionTop) {
            this.preferDocPositionTop = true;
            this.adjustDocsPosition();
            return;
        }
        this.docsPositionPreviousWidgetY = widgetY;
        if (widgetX < cursorX - this.listWidth) {
            // Widget is too far to the left of cursor, swap list and docs
            addClass(this.element, 'list-right');
        }
        else {
            removeClass(this.element, 'list-right');
        }
        // Compare top of the cursor (cursorY - lineheight) with widgetTop to determine if
        // margin-top needs to be applied on list to make it appear right above the cursor
        // Cannot compare cursorY directly as it may be a few decimals off due to zoooming
        if (hasClass(this.element, 'docs-side')
            && cursorY - lineHeight > widgetY
            && this.details.element.offsetHeight > this.listElement.offsetHeight) {
            // Fix for #26416
            // Docs is bigger than list and widget is above cursor, apply margin-top so that list appears right above cursor
            this.listElement.style.marginTop = this.details.element.offsetHeight - this.listElement.offsetHeight + "px";
        }
    };
    /**
     * Adds the proper classes for positioning the docs to the side or below
     */
    SuggestWidget.prototype.expandSideOrBelow = function () {
        if (!canExpandCompletionItem(this.focusedItem) && this.firstFocusInCurrentList) {
            removeClass(this.element, 'docs-side');
            removeClass(this.element, 'docs-below');
            return;
        }
        var matches = this.element.style.maxWidth.match(/(\d+)px/);
        if (!matches || Number(matches[1]) < this.maxWidgetWidth) {
            addClass(this.element, 'docs-below');
            removeClass(this.element, 'docs-side');
        }
        else if (canExpandCompletionItem(this.focusedItem)) {
            addClass(this.element, 'docs-side');
            removeClass(this.element, 'docs-below');
        }
    };
    Object.defineProperty(SuggestWidget.prototype, "maxWidgetHeight", {
        // Heights
        get: function () {
            return this.unfocusedHeight * this.editor.getConfiguration().contribInfo.suggest.maxVisibleSuggestions;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(SuggestWidget.prototype, "unfocusedHeight", {
        get: function () {
            var configuration = this.editor.getConfiguration();
            return configuration.contribInfo.suggestLineHeight || configuration.fontInfo.lineHeight;
        },
        enumerable: true,
        configurable: true
    });
    // IDelegate
    SuggestWidget.prototype.getHeight = function (element) {
        return this.unfocusedHeight;
    };
    SuggestWidget.prototype.getTemplateId = function (element) {
        return 'suggestion';
    };
    SuggestWidget.prototype.expandDocsSettingFromStorage = function () {
        return this.storageService.getBoolean('expandSuggestionDocs', 0 /* GLOBAL */, expandSuggestionDocsByDefault);
    };
    SuggestWidget.prototype.updateExpandDocsSetting = function (value) {
        this.storageService.store('expandSuggestionDocs', value, 0 /* GLOBAL */);
    };
    SuggestWidget.prototype.dispose = function () {
        this.details.dispose();
        this.list.dispose();
        this.toDispose.dispose();
        this.loadingTimeout.dispose();
        this.showTimeout.dispose();
    };
    SuggestWidget.ID = 'editor.widget.suggestWidget';
    SuggestWidget.LOADING_MESSAGE = nls.localize('suggestWidget.loading', "Loading...");
    SuggestWidget.NO_SUGGESTIONS_MESSAGE = nls.localize('suggestWidget.noSuggestions', "No suggestions.");
    SuggestWidget = __decorate([
        __param(1, ITelemetryService),
        __param(2, IContextKeyService),
        __param(3, IThemeService),
        __param(4, IStorageService),
        __param(5, IKeybindingService),
        __param(6, IModeService),
        __param(7, IOpenerService),
        __param(8, IInstantiationService)
    ], SuggestWidget);
    return SuggestWidget;
}());
export { SuggestWidget };
registerThemingParticipant(function (theme, collector) {
    var matchHighlight = theme.getColor(editorSuggestWidgetHighlightForeground);
    if (matchHighlight) {
        collector.addRule(".monaco-editor .suggest-widget .monaco-list .monaco-list-row .monaco-highlighted-label .highlight { color: " + matchHighlight + "; }");
    }
    var foreground = theme.getColor(editorSuggestWidgetForeground);
    if (foreground) {
        collector.addRule(".monaco-editor .suggest-widget { color: " + foreground + "; }");
    }
    var link = theme.getColor(textLinkForeground);
    if (link) {
        collector.addRule(".monaco-editor .suggest-widget a { color: " + link + "; }");
    }
    var codeBackground = theme.getColor(textCodeBlockBackground);
    if (codeBackground) {
        collector.addRule(".monaco-editor .suggest-widget code { background-color: " + codeBackground + "; }");
    }
});
