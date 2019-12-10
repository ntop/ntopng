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
import * as nls from '../../../nls.js';
import * as dom from '../../../base/browser/dom.js';
import { CancellationToken } from '../../../base/common/cancellation.js';
import { Color, RGBA } from '../../../base/common/color.js';
import { MarkdownString, isEmptyMarkdownString, markedStringsEquals } from '../../../base/common/htmlContent.js';
import { toDisposable, DisposableStore, combinedDisposable, MutableDisposable } from '../../../base/common/lifecycle.js';
import { Position } from '../../common/core/position.js';
import { Range } from '../../common/core/range.js';
import { ModelDecorationOptions } from '../../common/model/textModel.js';
import { HoverProviderRegistry } from '../../common/modes.js';
import { getColorPresentations } from '../colorPicker/color.js';
import { ColorDetector } from '../colorPicker/colorDetector.js';
import { ColorPickerModel } from '../colorPicker/colorPickerModel.js';
import { ColorPickerWidget } from '../colorPicker/colorPickerWidget.js';
import { getHover } from './getHover.js';
import { HoverOperation } from './hoverOperation.js';
import { ContentHoverWidget } from './hoverWidgets.js';
import { MarkdownRenderer } from '../markdown/markdownRenderer.js';
import { coalesce, isNonEmptyArray, asArray } from '../../../base/common/arrays.js';
import { IMarkerData, MarkerSeverity } from '../../../platform/markers/common/markers.js';
import { basename } from '../../../base/common/resources.js';
import { onUnexpectedError } from '../../../base/common/errors.js';
import { NullOpenerService } from '../../../platform/opener/common/opener.js';
import { MarkerController, NextMarkerAction } from '../gotoError/gotoError.js';
import { createCancelablePromise } from '../../../base/common/async.js';
import { getCodeActions } from '../codeAction/codeAction.js';
import { QuickFixAction, QuickFixController } from '../codeAction/codeActionCommands.js';
import { CodeActionKind } from '../codeAction/codeActionTrigger.js';
var $ = dom.$;
var ColorHover = /** @class */ (function () {
    function ColorHover(range, color, provider) {
        this.range = range;
        this.color = color;
        this.provider = provider;
    }
    return ColorHover;
}());
var MarkerHover = /** @class */ (function () {
    function MarkerHover(range, marker) {
        this.range = range;
        this.marker = marker;
    }
    return MarkerHover;
}());
var ModesContentComputer = /** @class */ (function () {
    function ModesContentComputer(editor, _markerDecorationsService) {
        this._markerDecorationsService = _markerDecorationsService;
        this._editor = editor;
        this._result = [];
    }
    ModesContentComputer.prototype.setRange = function (range) {
        this._range = range;
        this._result = [];
    };
    ModesContentComputer.prototype.clearResult = function () {
        this._result = [];
    };
    ModesContentComputer.prototype.computeAsync = function (token) {
        if (!this._editor.hasModel() || !this._range) {
            return Promise.resolve([]);
        }
        var model = this._editor.getModel();
        if (!HoverProviderRegistry.has(model)) {
            return Promise.resolve([]);
        }
        return getHover(model, new Position(this._range.startLineNumber, this._range.startColumn), token);
    };
    ModesContentComputer.prototype.computeSync = function () {
        var _this = this;
        if (!this._editor.hasModel() || !this._range) {
            return [];
        }
        var model = this._editor.getModel();
        var lineNumber = this._range.startLineNumber;
        if (lineNumber > this._editor.getModel().getLineCount()) {
            // Illegal line number => no results
            return [];
        }
        var colorDetector = ColorDetector.get(this._editor);
        var maxColumn = model.getLineMaxColumn(lineNumber);
        var lineDecorations = this._editor.getLineDecorations(lineNumber);
        var didFindColor = false;
        var hoverRange = this._range;
        var result = lineDecorations.map(function (d) {
            var startColumn = (d.range.startLineNumber === lineNumber) ? d.range.startColumn : 1;
            var endColumn = (d.range.endLineNumber === lineNumber) ? d.range.endColumn : maxColumn;
            if (startColumn > hoverRange.startColumn || hoverRange.endColumn > endColumn) {
                return null;
            }
            var range = new Range(hoverRange.startLineNumber, startColumn, hoverRange.startLineNumber, endColumn);
            var marker = _this._markerDecorationsService.getMarker(model, d);
            if (marker) {
                return new MarkerHover(range, marker);
            }
            var colorData = colorDetector.getColorData(d.range.getStartPosition());
            if (!didFindColor && colorData) {
                didFindColor = true;
                var _a = colorData.colorInfo, color = _a.color, range_1 = _a.range;
                return new ColorHover(range_1, color, colorData.provider);
            }
            else {
                if (isEmptyMarkdownString(d.options.hoverMessage)) {
                    return null;
                }
                var contents = d.options.hoverMessage ? asArray(d.options.hoverMessage) : [];
                return { contents: contents, range: range };
            }
        });
        return coalesce(result);
    };
    ModesContentComputer.prototype.onResult = function (result, isFromSynchronousComputation) {
        // Always put synchronous messages before asynchronous ones
        if (isFromSynchronousComputation) {
            this._result = result.concat(this._result.sort(function (a, b) {
                if (a instanceof ColorHover) { // sort picker messages at to the top
                    return -1;
                }
                else if (b instanceof ColorHover) {
                    return 1;
                }
                return 0;
            }));
        }
        else {
            this._result = this._result.concat(result);
        }
    };
    ModesContentComputer.prototype.getResult = function () {
        return this._result.slice(0);
    };
    ModesContentComputer.prototype.getResultWithLoadingMessage = function () {
        return this._result.slice(0).concat([this._getLoadingMessage()]);
    };
    ModesContentComputer.prototype._getLoadingMessage = function () {
        return {
            range: this._range,
            contents: [new MarkdownString().appendText(nls.localize('modesContentHover.loading', "Loading..."))]
        };
    };
    return ModesContentComputer;
}());
var ModesContentHoverWidget = /** @class */ (function (_super) {
    __extends(ModesContentHoverWidget, _super);
    function ModesContentHoverWidget(editor, markerDecorationsService, _themeService, _keybindingService, _modeService, _openerService) {
        if (_openerService === void 0) { _openerService = NullOpenerService; }
        var _this = _super.call(this, ModesContentHoverWidget.ID, editor) || this;
        _this._themeService = _themeService;
        _this._keybindingService = _keybindingService;
        _this._modeService = _modeService;
        _this._openerService = _openerService;
        _this.renderDisposable = _this._register(new MutableDisposable());
        _this._messages = [];
        _this._lastRange = null;
        _this._computer = new ModesContentComputer(_this._editor, markerDecorationsService);
        _this._highlightDecorations = [];
        _this._isChangingDecorations = false;
        _this._shouldFocus = false;
        _this._colorPicker = null;
        _this._hoverOperation = new HoverOperation(_this._computer, function (result) { return _this._withResult(result, true); }, null, function (result) { return _this._withResult(result, false); }, _this._editor.getConfiguration().contribInfo.hover.delay);
        _this._register(dom.addStandardDisposableListener(_this.getDomNode(), dom.EventType.FOCUS, function () {
            if (_this._colorPicker) {
                dom.addClass(_this.getDomNode(), 'colorpicker-hover');
            }
        }));
        _this._register(dom.addStandardDisposableListener(_this.getDomNode(), dom.EventType.BLUR, function () {
            dom.removeClass(_this.getDomNode(), 'colorpicker-hover');
        }));
        _this._register(editor.onDidChangeConfiguration(function (e) {
            _this._hoverOperation.setHoverTime(_this._editor.getConfiguration().contribInfo.hover.delay);
        }));
        return _this;
    }
    ModesContentHoverWidget.prototype.dispose = function () {
        this._hoverOperation.cancel();
        _super.prototype.dispose.call(this);
    };
    ModesContentHoverWidget.prototype.onModelDecorationsChanged = function () {
        if (this._isChangingDecorations) {
            return;
        }
        if (this.isVisible) {
            // The decorations have changed and the hover is visible,
            // we need to recompute the displayed text
            this._hoverOperation.cancel();
            this._computer.clearResult();
            if (!this._colorPicker) { // TODO@Michel ensure that displayed text for other decorations is computed even if color picker is in place
                this._hoverOperation.start(0 /* Delayed */);
            }
        }
    };
    ModesContentHoverWidget.prototype.startShowingAt = function (range, mode, focus) {
        if (this._lastRange && this._lastRange.equalsRange(range)) {
            // We have to show the widget at the exact same range as before, so no work is needed
            return;
        }
        this._hoverOperation.cancel();
        if (this.isVisible) {
            // The range might have changed, but the hover is visible
            // Instead of hiding it completely, filter out messages that are still in the new range and
            // kick off a new computation
            if (!this._showAtPosition || this._showAtPosition.lineNumber !== range.startLineNumber) {
                this.hide();
            }
            else {
                var filteredMessages = [];
                for (var i = 0, len = this._messages.length; i < len; i++) {
                    var msg = this._messages[i];
                    var rng = msg.range;
                    if (rng && rng.startColumn <= range.startColumn && rng.endColumn >= range.endColumn) {
                        filteredMessages.push(msg);
                    }
                }
                if (filteredMessages.length > 0) {
                    if (hoverContentsEquals(filteredMessages, this._messages)) {
                        return;
                    }
                    this._renderMessages(range, filteredMessages);
                }
                else {
                    this.hide();
                }
            }
        }
        this._lastRange = range;
        this._computer.setRange(range);
        this._shouldFocus = focus;
        this._hoverOperation.start(mode);
    };
    ModesContentHoverWidget.prototype.hide = function () {
        this._lastRange = null;
        this._hoverOperation.cancel();
        _super.prototype.hide.call(this);
        this._isChangingDecorations = true;
        this._highlightDecorations = this._editor.deltaDecorations(this._highlightDecorations, []);
        this._isChangingDecorations = false;
        this.renderDisposable.clear();
        this._colorPicker = null;
    };
    ModesContentHoverWidget.prototype.isColorPickerVisible = function () {
        if (this._colorPicker) {
            return true;
        }
        return false;
    };
    ModesContentHoverWidget.prototype._withResult = function (result, complete) {
        this._messages = result;
        if (this._lastRange && this._messages.length > 0) {
            this._renderMessages(this._lastRange, this._messages);
        }
        else if (complete) {
            this.hide();
        }
    };
    ModesContentHoverWidget.prototype._renderMessages = function (renderRange, messages) {
        var _this = this;
        this.renderDisposable.dispose();
        this._colorPicker = null;
        // update column from which to show
        var renderColumn = Number.MAX_VALUE;
        var highlightRange = messages[0].range ? Range.lift(messages[0].range) : null;
        var fragment = document.createDocumentFragment();
        var isEmptyHoverContent = true;
        var containColorPicker = false;
        var markdownDisposeables = new DisposableStore();
        var markerMessages = [];
        messages.forEach(function (msg) {
            if (!msg.range) {
                return;
            }
            renderColumn = Math.min(renderColumn, msg.range.startColumn);
            highlightRange = highlightRange ? Range.plusRange(highlightRange, msg.range) : Range.lift(msg.range);
            if (msg instanceof ColorHover) {
                containColorPicker = true;
                var _a = msg.color, red = _a.red, green = _a.green, blue = _a.blue, alpha = _a.alpha;
                var rgba = new RGBA(red * 255, green * 255, blue * 255, alpha);
                var color_1 = new Color(rgba);
                if (!_this._editor.hasModel()) {
                    return;
                }
                var editorModel_1 = _this._editor.getModel();
                var range_2 = new Range(msg.range.startLineNumber, msg.range.startColumn, msg.range.endLineNumber, msg.range.endColumn);
                var colorInfo = { range: msg.range, color: msg.color };
                // create blank olor picker model and widget first to ensure it's positioned correctly.
                var model_1 = new ColorPickerModel(color_1, [], 0);
                var widget_1 = new ColorPickerWidget(fragment, model_1, _this._editor.getConfiguration().pixelRatio, _this._themeService);
                getColorPresentations(editorModel_1, colorInfo, msg.provider, CancellationToken.None).then(function (colorPresentations) {
                    model_1.colorPresentations = colorPresentations || [];
                    if (!_this._editor.hasModel()) {
                        // gone...
                        return;
                    }
                    var originalText = _this._editor.getModel().getValueInRange(msg.range);
                    model_1.guessColorPresentation(color_1, originalText);
                    var updateEditorModel = function () {
                        var textEdits;
                        var newRange;
                        if (model_1.presentation.textEdit) {
                            textEdits = [model_1.presentation.textEdit];
                            newRange = new Range(model_1.presentation.textEdit.range.startLineNumber, model_1.presentation.textEdit.range.startColumn, model_1.presentation.textEdit.range.endLineNumber, model_1.presentation.textEdit.range.endColumn);
                            newRange = newRange.setEndPosition(newRange.endLineNumber, newRange.startColumn + model_1.presentation.textEdit.text.length);
                        }
                        else {
                            textEdits = [{ identifier: null, range: range_2, text: model_1.presentation.label, forceMoveMarkers: false }];
                            newRange = range_2.setEndPosition(range_2.endLineNumber, range_2.startColumn + model_1.presentation.label.length);
                        }
                        _this._editor.pushUndoStop();
                        _this._editor.executeEdits('colorpicker', textEdits);
                        if (model_1.presentation.additionalTextEdits) {
                            textEdits = model_1.presentation.additionalTextEdits.slice();
                            _this._editor.executeEdits('colorpicker', textEdits);
                            _this.hide();
                        }
                        _this._editor.pushUndoStop();
                        range_2 = newRange;
                    };
                    var updateColorPresentations = function (color) {
                        return getColorPresentations(editorModel_1, {
                            range: range_2,
                            color: {
                                red: color.rgba.r / 255,
                                green: color.rgba.g / 255,
                                blue: color.rgba.b / 255,
                                alpha: color.rgba.a
                            }
                        }, msg.provider, CancellationToken.None).then(function (colorPresentations) {
                            model_1.colorPresentations = colorPresentations || [];
                        });
                    };
                    var colorListener = model_1.onColorFlushed(function (color) {
                        updateColorPresentations(color).then(updateEditorModel);
                    });
                    var colorChangeListener = model_1.onDidChangeColor(updateColorPresentations);
                    _this._colorPicker = widget_1;
                    _this.showAt(range_2.getStartPosition(), range_2, _this._shouldFocus);
                    _this.updateContents(fragment);
                    _this._colorPicker.layout();
                    _this.renderDisposable.value = combinedDisposable(colorListener, colorChangeListener, widget_1, markdownDisposeables);
                });
            }
            else {
                if (msg instanceof MarkerHover) {
                    markerMessages.push(msg);
                    isEmptyHoverContent = false;
                }
                else {
                    msg.contents
                        .filter(function (contents) { return !isEmptyMarkdownString(contents); })
                        .forEach(function (contents) {
                        var markdownHoverElement = $('div.hover-row.markdown-hover');
                        var hoverContentsElement = dom.append(markdownHoverElement, $('div.hover-contents'));
                        var renderer = markdownDisposeables.add(new MarkdownRenderer(_this._editor, _this._modeService, _this._openerService));
                        markdownDisposeables.add(renderer.onDidRenderCodeBlock(function () {
                            hoverContentsElement.className = 'hover-contents code-hover-contents';
                            _this.onContentsChange();
                        }));
                        var renderedContents = markdownDisposeables.add(renderer.render(contents));
                        hoverContentsElement.appendChild(renderedContents.element);
                        fragment.appendChild(markdownHoverElement);
                        isEmptyHoverContent = false;
                    });
                }
            }
        });
        if (markerMessages.length) {
            markerMessages.forEach(function (msg) { return fragment.appendChild(_this.renderMarkerHover(msg)); });
            var markerHoverForStatusbar = markerMessages.length === 1 ? markerMessages[0] : markerMessages.sort(function (a, b) { return MarkerSeverity.compare(a.marker.severity, b.marker.severity); })[0];
            fragment.appendChild(this.renderMarkerStatusbar(markerHoverForStatusbar));
        }
        // show
        if (!containColorPicker && !isEmptyHoverContent) {
            this.showAt(new Position(renderRange.startLineNumber, renderColumn), highlightRange, this._shouldFocus);
            this.updateContents(fragment);
        }
        this._isChangingDecorations = true;
        this._highlightDecorations = this._editor.deltaDecorations(this._highlightDecorations, highlightRange ? [{
                range: highlightRange,
                options: ModesContentHoverWidget._DECORATION_OPTIONS
            }] : []);
        this._isChangingDecorations = false;
    };
    ModesContentHoverWidget.prototype.renderMarkerHover = function (markerHover) {
        var _this = this;
        var hoverElement = $('div.hover-row');
        var markerElement = dom.append(hoverElement, $('div.marker.hover-contents'));
        var _a = markerHover.marker, source = _a.source, message = _a.message, code = _a.code, relatedInformation = _a.relatedInformation;
        this._editor.applyFontInfo(markerElement);
        var messageElement = dom.append(markerElement, $('span'));
        messageElement.style.whiteSpace = 'pre-wrap';
        messageElement.innerText = message;
        if (source || code) {
            var detailsElement = dom.append(markerElement, $('span'));
            detailsElement.style.opacity = '0.6';
            detailsElement.style.paddingLeft = '6px';
            detailsElement.innerText = source && code ? source + "(" + code + ")" : source ? source : "(" + code + ")";
        }
        if (isNonEmptyArray(relatedInformation)) {
            var _loop_1 = function (message_1, resource, startLineNumber, startColumn) {
                var relatedInfoContainer = dom.append(markerElement, $('div'));
                relatedInfoContainer.style.marginTop = '8px';
                var a = dom.append(relatedInfoContainer, $('a'));
                a.innerText = basename(resource) + "(" + startLineNumber + ", " + startColumn + "): ";
                a.style.cursor = 'pointer';
                a.onclick = function (e) {
                    e.stopPropagation();
                    e.preventDefault();
                    if (_this._openerService) {
                        _this._openerService.open(resource.with({ fragment: startLineNumber + "," + startColumn })).catch(onUnexpectedError);
                    }
                };
                var messageElement_1 = dom.append(relatedInfoContainer, $('span'));
                messageElement_1.innerText = message_1;
                this_1._editor.applyFontInfo(messageElement_1);
            };
            var this_1 = this;
            for (var _i = 0, relatedInformation_1 = relatedInformation; _i < relatedInformation_1.length; _i++) {
                var _b = relatedInformation_1[_i], message_1 = _b.message, resource = _b.resource, startLineNumber = _b.startLineNumber, startColumn = _b.startColumn;
                _loop_1(message_1, resource, startLineNumber, startColumn);
            }
        }
        return hoverElement;
    };
    ModesContentHoverWidget.prototype.renderMarkerStatusbar = function (markerHover) {
        var _this = this;
        var hoverElement = $('div.hover-row.status-bar');
        var disposables = new DisposableStore();
        var actionsElement = dom.append(hoverElement, $('div.actions'));
        if (markerHover.marker.severity === MarkerSeverity.Error || markerHover.marker.severity === MarkerSeverity.Warning || markerHover.marker.severity === MarkerSeverity.Info) {
            disposables.add(this.renderAction(actionsElement, {
                label: nls.localize('peek problem', "Peek Problem"),
                commandId: NextMarkerAction.ID,
                run: function () {
                    _this.hide();
                    MarkerController.get(_this._editor).show(markerHover.marker);
                    _this._editor.focus();
                }
            }));
        }
        var quickfixPlaceholderElement = dom.append(actionsElement, $('div'));
        quickfixPlaceholderElement.style.opacity = '0';
        quickfixPlaceholderElement.style.transition = 'opacity 0.2s';
        setTimeout(function () { return quickfixPlaceholderElement.style.opacity = '1'; }, 200);
        quickfixPlaceholderElement.textContent = nls.localize('checkingForQuickFixes', "Checking for quick fixes...");
        disposables.add(toDisposable(function () { return quickfixPlaceholderElement.remove(); }));
        var codeActionsPromise = this.getCodeActions(markerHover.marker);
        disposables.add(toDisposable(function () { return codeActionsPromise.cancel(); }));
        codeActionsPromise.then(function (actions) {
            quickfixPlaceholderElement.style.transition = '';
            quickfixPlaceholderElement.style.opacity = '1';
            if (!actions.actions.length) {
                actions.dispose();
                quickfixPlaceholderElement.textContent = nls.localize('noQuickFixes', "No quick fixes available");
                return;
            }
            quickfixPlaceholderElement.remove();
            var showing = false;
            disposables.add(toDisposable(function () {
                if (!showing) {
                    actions.dispose();
                }
            }));
            disposables.add(_this.renderAction(actionsElement, {
                label: nls.localize('quick fixes', "Quick Fix..."),
                commandId: QuickFixAction.Id,
                run: function (target) {
                    showing = true;
                    var controller = QuickFixController.get(_this._editor);
                    var elementPosition = dom.getDomNodePagePosition(target);
                    controller.showCodeActions(actions, {
                        x: elementPosition.left + 6,
                        y: elementPosition.top + elementPosition.height + 6
                    });
                }
            }));
        });
        this.renderDisposable.value = disposables;
        return hoverElement;
    };
    ModesContentHoverWidget.prototype.getCodeActions = function (marker) {
        var _this = this;
        return createCancelablePromise(function (cancellationToken) {
            return getCodeActions(_this._editor.getModel(), new Range(marker.startLineNumber, marker.startColumn, marker.endLineNumber, marker.endColumn), { type: 'manual', filter: { kind: CodeActionKind.QuickFix } }, cancellationToken);
        });
    };
    ModesContentHoverWidget.prototype.renderAction = function (parent, actionOptions) {
        var actionContainer = dom.append(parent, $('div.action-container'));
        var action = dom.append(actionContainer, $('a.action'));
        if (actionOptions.iconClass) {
            dom.append(action, $("span.icon." + actionOptions.iconClass));
        }
        var label = dom.append(action, $('span'));
        label.textContent = actionOptions.label;
        var keybinding = this._keybindingService.lookupKeybinding(actionOptions.commandId);
        if (keybinding) {
            label.title = actionOptions.label + " (" + keybinding.getLabel() + ")";
        }
        return dom.addDisposableListener(actionContainer, dom.EventType.CLICK, function (e) {
            e.stopPropagation();
            e.preventDefault();
            actionOptions.run(actionContainer);
        });
    };
    ModesContentHoverWidget.ID = 'editor.contrib.modesContentHoverWidget';
    ModesContentHoverWidget._DECORATION_OPTIONS = ModelDecorationOptions.register({
        className: 'hoverHighlight'
    });
    return ModesContentHoverWidget;
}(ContentHoverWidget));
export { ModesContentHoverWidget };
function hoverContentsEquals(first, second) {
    if ((!first && second) || (first && !second) || first.length !== second.length) {
        return false;
    }
    for (var i = 0; i < first.length; i++) {
        var firstElement = first[i];
        var secondElement = second[i];
        if (firstElement instanceof MarkerHover && secondElement instanceof MarkerHover) {
            return IMarkerData.makeKey(firstElement.marker) === IMarkerData.makeKey(secondElement.marker);
        }
        if (firstElement instanceof ColorHover || secondElement instanceof ColorHover) {
            return false;
        }
        if (firstElement instanceof MarkerHover || secondElement instanceof MarkerHover) {
            return false;
        }
        if (!markedStringsEquals(firstElement.contents, secondElement.contents)) {
            return false;
        }
    }
    return true;
}
