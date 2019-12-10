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
import './media/gotoErrorWidget.css';
import * as nls from '../../../nls.js';
import * as dom from '../../../base/browser/dom.js';
import { dispose, DisposableStore } from '../../../base/common/lifecycle.js';
import { MarkerSeverity } from '../../../platform/markers/common/markers.js';
import { Range } from '../../common/core/range.js';
import { registerColor, oneOf, textLinkForeground, editorErrorForeground, editorErrorBorder, editorWarningForeground, editorWarningBorder, editorInfoForeground, editorInfoBorder } from '../../../platform/theme/common/colorRegistry.js';
import { registerThemingParticipant } from '../../../platform/theme/common/themeService.js';
import { Color } from '../../../base/common/color.js';
import { ScrollableElement } from '../../../base/browser/ui/scrollbar/scrollableElement.js';
import { getBaseLabel, getPathLabel } from '../../../base/common/labels.js';
import { isNonEmptyArray } from '../../../base/common/arrays.js';
import { Emitter } from '../../../base/common/event.js';
import { PeekViewWidget } from '../referenceSearch/peekViewWidget.js';
import { basename } from '../../../base/common/resources.js';
import { peekViewTitleForeground, peekViewTitleInfoForeground } from '../referenceSearch/referencesWidget.js';
import { SeverityIcon } from '../../../platform/severityIcon/common/severityIcon.js';
var MessageWidget = /** @class */ (function () {
    function MessageWidget(parent, editor, onRelatedInformation) {
        var _this = this;
        this._lines = 0;
        this._longestLineLength = 0;
        this._relatedDiagnostics = new WeakMap();
        this._disposables = [];
        this._editor = editor;
        var domNode = document.createElement('div');
        domNode.className = 'descriptioncontainer';
        domNode.setAttribute('aria-live', 'assertive');
        domNode.setAttribute('role', 'alert');
        this._messageBlock = document.createElement('div');
        dom.addClass(this._messageBlock, 'message');
        domNode.appendChild(this._messageBlock);
        this._relatedBlock = document.createElement('div');
        domNode.appendChild(this._relatedBlock);
        this._disposables.push(dom.addStandardDisposableListener(this._relatedBlock, 'click', function (event) {
            event.preventDefault();
            var related = _this._relatedDiagnostics.get(event.target);
            if (related) {
                onRelatedInformation(related);
            }
        }));
        this._scrollable = new ScrollableElement(domNode, {
            horizontal: 1 /* Auto */,
            vertical: 1 /* Auto */,
            useShadows: false,
            horizontalScrollbarSize: 3,
            verticalScrollbarSize: 3
        });
        parent.appendChild(this._scrollable.getDomNode());
        this._disposables.push(this._scrollable.onScroll(function (e) {
            domNode.style.left = "-" + e.scrollLeft + "px";
            domNode.style.top = "-" + e.scrollTop + "px";
        }));
        this._disposables.push(this._scrollable);
    }
    MessageWidget.prototype.dispose = function () {
        dispose(this._disposables);
    };
    MessageWidget.prototype.update = function (_a) {
        var source = _a.source, message = _a.message, relatedInformation = _a.relatedInformation, code = _a.code;
        var lines = message.split(/\r\n|\r|\n/g);
        this._lines = lines.length;
        this._longestLineLength = 0;
        for (var _i = 0, lines_1 = lines; _i < lines_1.length; _i++) {
            var line = lines_1[_i];
            this._longestLineLength = Math.max(line.length, this._longestLineLength);
        }
        dom.clearNode(this._messageBlock);
        this._editor.applyFontInfo(this._messageBlock);
        var lastLineElement = this._messageBlock;
        for (var _b = 0, lines_2 = lines; _b < lines_2.length; _b++) {
            var line = lines_2[_b];
            lastLineElement = document.createElement('div');
            lastLineElement.innerText = line;
            if (line === '') {
                lastLineElement.style.height = this._messageBlock.style.lineHeight;
            }
            this._messageBlock.appendChild(lastLineElement);
        }
        if (source || code) {
            var detailsElement = document.createElement('span');
            dom.addClass(detailsElement, 'details');
            lastLineElement.appendChild(detailsElement);
            if (source) {
                var sourceElement = document.createElement('span');
                sourceElement.innerText = source;
                dom.addClass(sourceElement, 'source');
                detailsElement.appendChild(sourceElement);
            }
            if (code) {
                var codeElement = document.createElement('span');
                codeElement.innerText = "(" + code + ")";
                dom.addClass(codeElement, 'code');
                detailsElement.appendChild(codeElement);
            }
        }
        dom.clearNode(this._relatedBlock);
        this._editor.applyFontInfo(this._relatedBlock);
        if (isNonEmptyArray(relatedInformation)) {
            var relatedInformationNode = this._relatedBlock.appendChild(document.createElement('div'));
            relatedInformationNode.style.paddingTop = Math.floor(this._editor.getConfiguration().lineHeight * 0.66) + "px";
            this._lines += 1;
            for (var _c = 0, relatedInformation_1 = relatedInformation; _c < relatedInformation_1.length; _c++) {
                var related = relatedInformation_1[_c];
                var container = document.createElement('div');
                var relatedResource = document.createElement('a');
                dom.addClass(relatedResource, 'filename');
                relatedResource.innerHTML = getBaseLabel(related.resource) + "(" + related.startLineNumber + ", " + related.startColumn + "): ";
                relatedResource.title = getPathLabel(related.resource, undefined);
                this._relatedDiagnostics.set(relatedResource, related);
                var relatedMessage = document.createElement('span');
                relatedMessage.innerText = related.message;
                container.appendChild(relatedResource);
                container.appendChild(relatedMessage);
                this._lines += 1;
                relatedInformationNode.appendChild(container);
            }
        }
        var fontInfo = this._editor.getConfiguration().fontInfo;
        var scrollWidth = Math.ceil(fontInfo.typicalFullwidthCharacterWidth * this._longestLineLength * 0.75);
        var scrollHeight = fontInfo.lineHeight * this._lines;
        this._scrollable.setScrollDimensions({ scrollWidth: scrollWidth, scrollHeight: scrollHeight });
    };
    MessageWidget.prototype.layout = function (height, width) {
        this._scrollable.getDomNode().style.height = height + "px";
        this._scrollable.getDomNode().style.width = width + "px";
        this._scrollable.setScrollDimensions({ width: width, height: height });
    };
    MessageWidget.prototype.getHeightInLines = function () {
        return Math.min(17, this._lines);
    };
    return MessageWidget;
}());
var MarkerNavigationWidget = /** @class */ (function (_super) {
    __extends(MarkerNavigationWidget, _super);
    function MarkerNavigationWidget(editor, actions, _themeService) {
        var _this = _super.call(this, editor, { showArrow: true, showFrame: true, isAccessible: true }) || this;
        _this.actions = actions;
        _this._themeService = _themeService;
        _this._callOnDispose = new DisposableStore();
        _this._onDidSelectRelatedInformation = new Emitter();
        _this.onDidSelectRelatedInformation = _this._onDidSelectRelatedInformation.event;
        _this._severity = MarkerSeverity.Warning;
        _this._backgroundColor = Color.white;
        _this._applyTheme(_themeService.getTheme());
        _this._callOnDispose.add(_themeService.onThemeChange(_this._applyTheme.bind(_this)));
        _this.create();
        return _this;
    }
    MarkerNavigationWidget.prototype._applyTheme = function (theme) {
        this._backgroundColor = theme.getColor(editorMarkerNavigationBackground);
        var colorId = editorMarkerNavigationError;
        if (this._severity === MarkerSeverity.Warning) {
            colorId = editorMarkerNavigationWarning;
        }
        else if (this._severity === MarkerSeverity.Info) {
            colorId = editorMarkerNavigationInfo;
        }
        var frameColor = theme.getColor(colorId);
        this.style({
            arrowColor: frameColor,
            frameColor: frameColor,
            headerBackgroundColor: this._backgroundColor,
            primaryHeadingColor: theme.getColor(peekViewTitleForeground),
            secondaryHeadingColor: theme.getColor(peekViewTitleInfoForeground)
        }); // style() will trigger _applyStyles
    };
    MarkerNavigationWidget.prototype._applyStyles = function () {
        if (this._parentContainer) {
            this._parentContainer.style.backgroundColor = this._backgroundColor ? this._backgroundColor.toString() : '';
        }
        _super.prototype._applyStyles.call(this);
    };
    MarkerNavigationWidget.prototype.dispose = function () {
        this._callOnDispose.dispose();
        _super.prototype.dispose.call(this);
    };
    MarkerNavigationWidget.prototype._fillHead = function (container) {
        _super.prototype._fillHead.call(this, container);
        this._actionbarWidget.push(this.actions, { label: false, icon: true });
    };
    MarkerNavigationWidget.prototype._fillTitleIcon = function (container) {
        this._icon = dom.append(container, dom.$(''));
    };
    MarkerNavigationWidget.prototype._getActionBarOptions = function () {
        return {
            orientation: 1 /* HORIZONTAL_REVERSE */
        };
    };
    MarkerNavigationWidget.prototype._fillBody = function (container) {
        var _this = this;
        this._parentContainer = container;
        dom.addClass(container, 'marker-widget');
        this._parentContainer.tabIndex = 0;
        this._parentContainer.setAttribute('role', 'tooltip');
        this._container = document.createElement('div');
        container.appendChild(this._container);
        this._message = new MessageWidget(this._container, this.editor, function (related) { return _this._onDidSelectRelatedInformation.fire(related); });
        this._disposables.add(this._message);
    };
    MarkerNavigationWidget.prototype.show = function (where, heightInLines) {
        throw new Error('call showAtMarker');
    };
    MarkerNavigationWidget.prototype.showAtMarker = function (marker, markerIdx, markerCount) {
        // update:
        // * title
        // * message
        this._container.classList.remove('stale');
        this._message.update(marker);
        // update frame color (only applied on 'show')
        this._severity = marker.severity;
        this._applyTheme(this._themeService.getTheme());
        // show
        var range = Range.lift(marker);
        var editorPosition = this.editor.getPosition();
        var position = editorPosition && range.containsPosition(editorPosition) ? editorPosition : range.getStartPosition();
        _super.prototype.show.call(this, position, this.computeRequiredHeight());
        var model = this.editor.getModel();
        if (model) {
            var detail = markerCount > 1
                ? nls.localize('problems', "{0} of {1} problems", markerIdx, markerCount)
                : nls.localize('change', "{0} of {1} problem", markerIdx, markerCount);
            this.setTitle(basename(model.uri), detail);
        }
        this._icon.className = SeverityIcon.className(MarkerSeverity.toSeverity(this._severity));
        this.editor.revealPositionInCenter(position, 0 /* Smooth */);
    };
    MarkerNavigationWidget.prototype.updateMarker = function (marker) {
        this._container.classList.remove('stale');
        this._message.update(marker);
    };
    MarkerNavigationWidget.prototype.showStale = function () {
        this._container.classList.add('stale');
        this._relayout();
    };
    MarkerNavigationWidget.prototype._doLayoutBody = function (heightInPixel, widthInPixel) {
        _super.prototype._doLayoutBody.call(this, heightInPixel, widthInPixel);
        this._heightInPixel = heightInPixel;
        this._message.layout(heightInPixel, widthInPixel);
        this._container.style.height = heightInPixel + "px";
    };
    MarkerNavigationWidget.prototype._onWidth = function (widthInPixel) {
        this._message.layout(this._heightInPixel, widthInPixel);
    };
    MarkerNavigationWidget.prototype._relayout = function () {
        _super.prototype._relayout.call(this, this.computeRequiredHeight());
    };
    MarkerNavigationWidget.prototype.computeRequiredHeight = function () {
        return 3 + this._message.getHeightInLines();
    };
    return MarkerNavigationWidget;
}(PeekViewWidget));
export { MarkerNavigationWidget };
// theming
var errorDefault = oneOf(editorErrorForeground, editorErrorBorder);
var warningDefault = oneOf(editorWarningForeground, editorWarningBorder);
var infoDefault = oneOf(editorInfoForeground, editorInfoBorder);
export var editorMarkerNavigationError = registerColor('editorMarkerNavigationError.background', { dark: errorDefault, light: errorDefault, hc: errorDefault }, nls.localize('editorMarkerNavigationError', 'Editor marker navigation widget error color.'));
export var editorMarkerNavigationWarning = registerColor('editorMarkerNavigationWarning.background', { dark: warningDefault, light: warningDefault, hc: warningDefault }, nls.localize('editorMarkerNavigationWarning', 'Editor marker navigation widget warning color.'));
export var editorMarkerNavigationInfo = registerColor('editorMarkerNavigationInfo.background', { dark: infoDefault, light: infoDefault, hc: infoDefault }, nls.localize('editorMarkerNavigationInfo', 'Editor marker navigation widget info color.'));
export var editorMarkerNavigationBackground = registerColor('editorMarkerNavigation.background', { dark: '#2D2D30', light: Color.white, hc: '#0C141F' }, nls.localize('editorMarkerNavigationBackground', 'Editor marker navigation widget background.'));
registerThemingParticipant(function (theme, collector) {
    var link = theme.getColor(textLinkForeground);
    if (link) {
        collector.addRule(".monaco-editor .marker-widget a { color: " + link + "; }");
    }
});
