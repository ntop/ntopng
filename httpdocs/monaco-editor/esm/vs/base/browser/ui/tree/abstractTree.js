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
import './media/tree.css';
import { dispose, Disposable, toDisposable, DisposableStore } from '../../../common/lifecycle.js';
import { List, mightProducePrintableCharacter, MouseController } from '../list/listWidget.js';
import { append, $, toggleClass, getDomNodePagePosition, removeClass, addClass, hasClass, createStyleSheet, clearNode } from '../../dom.js';
import { Event, Relay, Emitter, EventBufferer } from '../../../common/event.js';
import { StandardKeyboardEvent } from '../../keyboardEvent.js';
import { StaticDND, DragAndDropData } from '../../dnd.js';
import { range, equals, distinctES6 } from '../../../common/arrays.js';
import { ElementsDragAndDropData } from '../list/listView.js';
import { domEvent } from '../../event.js';
import { fuzzyScore, FuzzyScore } from '../../../common/filters.js';
import { getVisibleState, isFilterResult } from './indexTreeModel.js';
import { localize } from '../../../../nls.js';
import { disposableTimeout } from '../../../common/async.js';
import { isMacintosh } from '../../../common/platform.js';
import { values } from '../../../common/map.js';
import { clamp } from '../../../common/numbers.js';
import { SetMap } from '../../../common/collections.js';
function asTreeDragAndDropData(data) {
    if (data instanceof ElementsDragAndDropData) {
        var nodes = data.elements;
        return new ElementsDragAndDropData(nodes.map(function (node) { return node.element; }));
    }
    return data;
}
var TreeNodeListDragAndDrop = /** @class */ (function () {
    function TreeNodeListDragAndDrop(modelProvider, dnd) {
        this.modelProvider = modelProvider;
        this.dnd = dnd;
        this.autoExpandDisposable = Disposable.None;
    }
    TreeNodeListDragAndDrop.prototype.getDragURI = function (node) {
        return this.dnd.getDragURI(node.element);
    };
    TreeNodeListDragAndDrop.prototype.getDragLabel = function (nodes) {
        if (this.dnd.getDragLabel) {
            return this.dnd.getDragLabel(nodes.map(function (node) { return node.element; }));
        }
        return undefined;
    };
    TreeNodeListDragAndDrop.prototype.onDragStart = function (data, originalEvent) {
        if (this.dnd.onDragStart) {
            this.dnd.onDragStart(asTreeDragAndDropData(data), originalEvent);
        }
    };
    TreeNodeListDragAndDrop.prototype.onDragOver = function (data, targetNode, targetIndex, originalEvent, raw) {
        var _this = this;
        if (raw === void 0) { raw = true; }
        var result = this.dnd.onDragOver(asTreeDragAndDropData(data), targetNode && targetNode.element, targetIndex, originalEvent);
        var didChangeAutoExpandNode = this.autoExpandNode !== targetNode;
        if (didChangeAutoExpandNode) {
            this.autoExpandDisposable.dispose();
            this.autoExpandNode = targetNode;
        }
        if (typeof targetNode === 'undefined') {
            return result;
        }
        if (didChangeAutoExpandNode && typeof result !== 'boolean' && result.autoExpand) {
            this.autoExpandDisposable = disposableTimeout(function () {
                var model = _this.modelProvider();
                var ref = model.getNodeLocation(targetNode);
                if (model.isCollapsed(ref)) {
                    model.setCollapsed(ref, false);
                }
                _this.autoExpandNode = undefined;
            }, 500);
        }
        if (typeof result === 'boolean' || !result.accept || typeof result.bubble === 'undefined') {
            if (!raw) {
                var accept = typeof result === 'boolean' ? result : result.accept;
                var effect = typeof result === 'boolean' ? undefined : result.effect;
                return { accept: accept, effect: effect, feedback: [targetIndex] };
            }
            return result;
        }
        if (result.bubble === 1 /* Up */) {
            var parentNode = targetNode.parent;
            var model_1 = this.modelProvider();
            var parentIndex = parentNode && model_1.getListIndex(model_1.getNodeLocation(parentNode));
            return this.onDragOver(data, parentNode, parentIndex, originalEvent, false);
        }
        var model = this.modelProvider();
        var ref = model.getNodeLocation(targetNode);
        var start = model.getListIndex(ref);
        var length = model.getListRenderCount(ref);
        return __assign({}, result, { feedback: range(start, start + length) });
    };
    TreeNodeListDragAndDrop.prototype.drop = function (data, targetNode, targetIndex, originalEvent) {
        this.autoExpandDisposable.dispose();
        this.autoExpandNode = undefined;
        this.dnd.drop(asTreeDragAndDropData(data), targetNode && targetNode.element, targetIndex, originalEvent);
    };
    return TreeNodeListDragAndDrop;
}());
function asListOptions(modelProvider, options) {
    return options && __assign({}, options, { identityProvider: options.identityProvider && {
            getId: function (el) {
                return options.identityProvider.getId(el.element);
            }
        }, dnd: options.dnd && new TreeNodeListDragAndDrop(modelProvider, options.dnd), multipleSelectionController: options.multipleSelectionController && {
            isSelectionSingleChangeEvent: function (e) {
                return options.multipleSelectionController.isSelectionSingleChangeEvent(__assign({}, e, { element: e.element }));
            },
            isSelectionRangeChangeEvent: function (e) {
                return options.multipleSelectionController.isSelectionRangeChangeEvent(__assign({}, e, { element: e.element }));
            }
        }, accessibilityProvider: options.accessibilityProvider && {
            getAriaLabel: function (e) {
                return options.accessibilityProvider.getAriaLabel(e.element);
            },
            getAriaLevel: function (node) {
                return node.depth;
            }
        }, keyboardNavigationLabelProvider: options.keyboardNavigationLabelProvider && __assign({}, options.keyboardNavigationLabelProvider, { getKeyboardNavigationLabel: function (node) {
                return options.keyboardNavigationLabelProvider.getKeyboardNavigationLabel(node.element);
            } }), enableKeyboardNavigation: options.simpleKeyboardNavigation, ariaProvider: {
            getSetSize: function (node) {
                return node.parent.visibleChildrenCount;
            },
            getPosInSet: function (node) {
                return node.visibleChildIndex + 1;
            }
        } });
}
var ComposedTreeDelegate = /** @class */ (function () {
    function ComposedTreeDelegate(delegate) {
        this.delegate = delegate;
    }
    ComposedTreeDelegate.prototype.getHeight = function (element) {
        return this.delegate.getHeight(element.element);
    };
    ComposedTreeDelegate.prototype.getTemplateId = function (element) {
        return this.delegate.getTemplateId(element.element);
    };
    ComposedTreeDelegate.prototype.hasDynamicHeight = function (element) {
        return !!this.delegate.hasDynamicHeight && this.delegate.hasDynamicHeight(element.element);
    };
    ComposedTreeDelegate.prototype.setDynamicHeight = function (element, height) {
        if (this.delegate.setDynamicHeight) {
            this.delegate.setDynamicHeight(element.element, height);
        }
    };
    return ComposedTreeDelegate;
}());
export { ComposedTreeDelegate };
export var RenderIndentGuides;
(function (RenderIndentGuides) {
    RenderIndentGuides["None"] = "none";
    RenderIndentGuides["OnHover"] = "onHover";
    RenderIndentGuides["Always"] = "always";
})(RenderIndentGuides || (RenderIndentGuides = {}));
var EventCollection = /** @class */ (function () {
    function EventCollection(onDidChange, _elements) {
        var _this = this;
        if (_elements === void 0) { _elements = []; }
        this.onDidChange = onDidChange;
        this._elements = _elements;
        this.disposables = new DisposableStore();
        onDidChange(function (e) { return _this._elements = e; }, null, this.disposables);
    }
    Object.defineProperty(EventCollection.prototype, "elements", {
        get: function () {
            return this._elements;
        },
        enumerable: true,
        configurable: true
    });
    EventCollection.prototype.dispose = function () {
        this.disposables.dispose();
    };
    return EventCollection;
}());
var TreeRenderer = /** @class */ (function () {
    function TreeRenderer(renderer, onDidChangeCollapseState, activeNodes, options) {
        if (options === void 0) { options = {}; }
        this.renderer = renderer;
        this.activeNodes = activeNodes;
        this.renderedElements = new Map();
        this.renderedNodes = new Map();
        this.indent = TreeRenderer.DefaultIndent;
        this._renderIndentGuides = RenderIndentGuides.None;
        this.renderedIndentGuides = new SetMap();
        this.activeIndentNodes = new Set();
        this.indentGuidesDisposable = Disposable.None;
        this.disposables = [];
        this.templateId = renderer.templateId;
        this.updateOptions(options);
        Event.map(onDidChangeCollapseState, function (e) { return e.node; })(this.onDidChangeNodeTwistieState, this, this.disposables);
        if (renderer.onDidChangeTwistieState) {
            renderer.onDidChangeTwistieState(this.onDidChangeTwistieState, this, this.disposables);
        }
    }
    TreeRenderer.prototype.updateOptions = function (options) {
        if (options === void 0) { options = {}; }
        if (typeof options.indent !== 'undefined') {
            this.indent = clamp(options.indent, 0, 40);
        }
        if (typeof options.renderIndentGuides !== 'undefined') {
            var renderIndentGuides = options.renderIndentGuides;
            if (renderIndentGuides !== this._renderIndentGuides) {
                this._renderIndentGuides = renderIndentGuides;
                if (renderIndentGuides) {
                    var disposables = new DisposableStore();
                    this.activeNodes.onDidChange(this._onDidChangeActiveNodes, this, disposables);
                    this.indentGuidesDisposable = disposables;
                    this._onDidChangeActiveNodes(this.activeNodes.elements);
                }
                else {
                    this.indentGuidesDisposable.dispose();
                }
            }
        }
    };
    TreeRenderer.prototype.renderTemplate = function (container) {
        var el = append(container, $('.monaco-tl-row'));
        var indent = append(el, $('.monaco-tl-indent'));
        var twistie = append(el, $('.monaco-tl-twistie'));
        var contents = append(el, $('.monaco-tl-contents'));
        var templateData = this.renderer.renderTemplate(contents);
        return { container: container, indent: indent, twistie: twistie, indentGuidesDisposable: Disposable.None, templateData: templateData };
    };
    TreeRenderer.prototype.renderElement = function (node, index, templateData, height) {
        if (typeof height === 'number') {
            this.renderedNodes.set(node, { templateData: templateData, height: height });
            this.renderedElements.set(node.element, node);
        }
        var indent = TreeRenderer.DefaultIndent + (node.depth - 1) * this.indent;
        templateData.twistie.style.marginLeft = indent + "px";
        templateData.indent.style.width = indent + this.indent - 16 + "px";
        this.renderTwistie(node, templateData);
        if (typeof height === 'number') {
            this.renderIndentGuides(node, templateData);
        }
        this.renderer.renderElement(node, index, templateData.templateData, height);
    };
    TreeRenderer.prototype.disposeElement = function (node, index, templateData, height) {
        templateData.indentGuidesDisposable.dispose();
        if (this.renderer.disposeElement) {
            this.renderer.disposeElement(node, index, templateData.templateData, height);
        }
        if (typeof height === 'number') {
            this.renderedNodes.delete(node);
            this.renderedElements.delete(node.element);
        }
    };
    TreeRenderer.prototype.disposeTemplate = function (templateData) {
        this.renderer.disposeTemplate(templateData.templateData);
    };
    TreeRenderer.prototype.onDidChangeTwistieState = function (element) {
        var node = this.renderedElements.get(element);
        if (!node) {
            return;
        }
        this.onDidChangeNodeTwistieState(node);
    };
    TreeRenderer.prototype.onDidChangeNodeTwistieState = function (node) {
        var data = this.renderedNodes.get(node);
        if (!data) {
            return;
        }
        this.renderTwistie(node, data.templateData);
        this._onDidChangeActiveNodes(this.activeNodes.elements);
        this.renderIndentGuides(node, data.templateData);
    };
    TreeRenderer.prototype.renderTwistie = function (node, templateData) {
        if (this.renderer.renderTwistie) {
            this.renderer.renderTwistie(node.element, templateData.twistie);
        }
        toggleClass(templateData.twistie, 'collapsible', node.collapsible);
        toggleClass(templateData.twistie, 'collapsed', node.collapsible && node.collapsed);
        if (node.collapsible) {
            templateData.container.setAttribute('aria-expanded', String(!node.collapsed));
        }
        else {
            templateData.container.removeAttribute('aria-expanded');
        }
    };
    TreeRenderer.prototype.renderIndentGuides = function (target, templateData) {
        var _this = this;
        clearNode(templateData.indent);
        templateData.indentGuidesDisposable.dispose();
        if (this._renderIndentGuides === RenderIndentGuides.None) {
            return;
        }
        var disposableStore = new DisposableStore();
        var node = target;
        var _loop_1 = function () {
            var parent_1 = node.parent;
            var guide = $('.indent-guide', { style: "width: " + this_1.indent + "px" });
            if (this_1.activeIndentNodes.has(parent_1)) {
                addClass(guide, 'active');
            }
            if (templateData.indent.childElementCount === 0) {
                templateData.indent.appendChild(guide);
            }
            else {
                templateData.indent.insertBefore(guide, templateData.indent.firstElementChild);
            }
            this_1.renderedIndentGuides.add(parent_1, guide);
            disposableStore.add(toDisposable(function () { return _this.renderedIndentGuides.delete(parent_1, guide); }));
            node = parent_1;
        };
        var this_1 = this;
        while (node.parent && node.parent.parent) {
            _loop_1();
        }
        templateData.indentGuidesDisposable = disposableStore;
    };
    TreeRenderer.prototype._onDidChangeActiveNodes = function (nodes) {
        var _this = this;
        if (this._renderIndentGuides === RenderIndentGuides.None) {
            return;
        }
        var set = new Set();
        nodes.forEach(function (node) {
            if (node.collapsible && node.children.length > 0 && !node.collapsed) {
                set.add(node);
            }
            else if (node.parent) {
                set.add(node.parent);
            }
        });
        this.activeIndentNodes.forEach(function (node) {
            if (!set.has(node)) {
                _this.renderedIndentGuides.forEach(node, function (line) { return removeClass(line, 'active'); });
            }
        });
        set.forEach(function (node) {
            if (!_this.activeIndentNodes.has(node)) {
                _this.renderedIndentGuides.forEach(node, function (line) { return addClass(line, 'active'); });
            }
        });
        this.activeIndentNodes = set;
    };
    TreeRenderer.prototype.dispose = function () {
        this.renderedNodes.clear();
        this.renderedElements.clear();
        this.indentGuidesDisposable.dispose();
        this.disposables = dispose(this.disposables);
    };
    TreeRenderer.DefaultIndent = 8;
    return TreeRenderer;
}());
var TypeFilter = /** @class */ (function () {
    function TypeFilter(tree, keyboardNavigationLabelProvider, _filter) {
        this.tree = tree;
        this.keyboardNavigationLabelProvider = keyboardNavigationLabelProvider;
        this._filter = _filter;
        this._totalCount = 0;
        this._matchCount = 0;
        this._pattern = '';
        this._lowercasePattern = '';
        this.disposables = [];
        tree.onWillRefilter(this.reset, this, this.disposables);
    }
    Object.defineProperty(TypeFilter.prototype, "totalCount", {
        get: function () { return this._totalCount; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(TypeFilter.prototype, "matchCount", {
        get: function () { return this._matchCount; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(TypeFilter.prototype, "pattern", {
        set: function (pattern) {
            this._pattern = pattern;
            this._lowercasePattern = pattern.toLowerCase();
        },
        enumerable: true,
        configurable: true
    });
    TypeFilter.prototype.filter = function (element, parentVisibility) {
        if (this._filter) {
            var result = this._filter.filter(element, parentVisibility);
            if (this.tree.options.simpleKeyboardNavigation) {
                return result;
            }
            var visibility = void 0;
            if (typeof result === 'boolean') {
                visibility = result ? 1 /* Visible */ : 0 /* Hidden */;
            }
            else if (isFilterResult(result)) {
                visibility = getVisibleState(result.visibility);
            }
            else {
                visibility = result;
            }
            if (visibility === 0 /* Hidden */) {
                return false;
            }
        }
        this._totalCount++;
        if (this.tree.options.simpleKeyboardNavigation || !this._pattern) {
            this._matchCount++;
            return { data: FuzzyScore.Default, visibility: true };
        }
        var label = this.keyboardNavigationLabelProvider.getKeyboardNavigationLabel(element);
        var labelStr = label && label.toString();
        if (typeof labelStr === 'undefined') {
            return { data: FuzzyScore.Default, visibility: true };
        }
        var score = fuzzyScore(this._pattern, this._lowercasePattern, 0, labelStr, labelStr.toLowerCase(), 0, true);
        if (!score) {
            if (this.tree.options.filterOnType) {
                return 2 /* Recurse */;
            }
            else {
                return { data: FuzzyScore.Default, visibility: true };
            }
            // DEMO: smarter filter ?
            // return parentVisibility === TreeVisibility.Visible ? true : TreeVisibility.Recurse;
        }
        this._matchCount++;
        return { data: score, visibility: true };
    };
    TypeFilter.prototype.reset = function () {
        this._totalCount = 0;
        this._matchCount = 0;
    };
    TypeFilter.prototype.dispose = function () {
        this.disposables = dispose(this.disposables);
    };
    return TypeFilter;
}());
var TypeFilterController = /** @class */ (function () {
    function TypeFilterController(tree, model, view, filter, keyboardNavigationLabelProvider) {
        this.tree = tree;
        this.view = view;
        this.filter = filter;
        this.keyboardNavigationLabelProvider = keyboardNavigationLabelProvider;
        this._enabled = false;
        this._pattern = '';
        this._empty = false;
        this._onDidChangeEmptyState = new Emitter();
        this.positionClassName = 'ne';
        this.automaticKeyboardNavigation = true;
        this.triggered = false;
        this._onDidChangePattern = new Emitter();
        this.enabledDisposables = [];
        this.disposables = [];
        this.domNode = $(".monaco-list-type-filter." + this.positionClassName);
        this.domNode.draggable = true;
        domEvent(this.domNode, 'dragstart')(this.onDragStart, this, this.disposables);
        this.messageDomNode = append(view.getHTMLElement(), $(".monaco-list-type-filter-message"));
        this.labelDomNode = append(this.domNode, $('span.label'));
        var controls = append(this.domNode, $('.controls'));
        this._filterOnType = !!tree.options.filterOnType;
        this.filterOnTypeDomNode = append(controls, $('input.filter'));
        this.filterOnTypeDomNode.type = 'checkbox';
        this.filterOnTypeDomNode.checked = this._filterOnType;
        this.filterOnTypeDomNode.tabIndex = -1;
        this.updateFilterOnTypeTitle();
        domEvent(this.filterOnTypeDomNode, 'input')(this.onDidChangeFilterOnType, this, this.disposables);
        this.clearDomNode = append(controls, $('button.clear'));
        this.clearDomNode.tabIndex = -1;
        this.clearDomNode.title = localize('clear', "Clear");
        this.keyboardNavigationEventFilter = tree.options.keyboardNavigationEventFilter;
        model.onDidSplice(this.onDidSpliceModel, this, this.disposables);
        this.updateOptions(tree.options);
    }
    Object.defineProperty(TypeFilterController.prototype, "enabled", {
        get: function () { return this._enabled; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(TypeFilterController.prototype, "pattern", {
        get: function () { return this._pattern; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(TypeFilterController.prototype, "filterOnType", {
        get: function () { return this._filterOnType; },
        enumerable: true,
        configurable: true
    });
    TypeFilterController.prototype.updateOptions = function (options) {
        if (options.simpleKeyboardNavigation) {
            this.disable();
        }
        else {
            this.enable();
        }
        if (typeof options.filterOnType !== 'undefined') {
            this._filterOnType = !!options.filterOnType;
            this.filterOnTypeDomNode.checked = this._filterOnType;
        }
        if (typeof options.automaticKeyboardNavigation !== 'undefined') {
            this.automaticKeyboardNavigation = options.automaticKeyboardNavigation;
        }
        this.tree.refilter();
        this.render();
        if (!this.automaticKeyboardNavigation) {
            this.onEventOrInput('');
        }
    };
    TypeFilterController.prototype.enable = function () {
        var _this = this;
        if (this._enabled) {
            return;
        }
        var isPrintableCharEvent = this.keyboardNavigationLabelProvider.mightProducePrintableCharacter ? function (e) { return _this.keyboardNavigationLabelProvider.mightProducePrintableCharacter(e); } : function (e) { return mightProducePrintableCharacter(e); };
        var onKeyDown = Event.chain(domEvent(this.view.getHTMLElement(), 'keydown'))
            .filter(function (e) { return !isInputElement(e.target) || e.target === _this.filterOnTypeDomNode; })
            .map(function (e) { return new StandardKeyboardEvent(e); })
            .filter(this.keyboardNavigationEventFilter || (function () { return true; }))
            .filter(function () { return _this.automaticKeyboardNavigation || _this.triggered; })
            .filter(function (e) { return isPrintableCharEvent(e) || ((_this.pattern.length > 0 || _this.triggered) && ((e.keyCode === 9 /* Escape */ || e.keyCode === 1 /* Backspace */) && !e.altKey && !e.ctrlKey && !e.metaKey) || (e.keyCode === 1 /* Backspace */ && (isMacintosh ? (e.altKey && !e.metaKey) : e.ctrlKey) && !e.shiftKey)); })
            .forEach(function (e) { e.stopPropagation(); e.preventDefault(); })
            .event;
        var onClear = domEvent(this.clearDomNode, 'click');
        Event.chain(Event.any(onKeyDown, onClear))
            .event(this.onEventOrInput, this, this.enabledDisposables);
        this.filter.pattern = '';
        this.tree.refilter();
        this.render();
        this._enabled = true;
        this.triggered = false;
    };
    TypeFilterController.prototype.disable = function () {
        if (!this._enabled) {
            return;
        }
        this.domNode.remove();
        this.enabledDisposables = dispose(this.enabledDisposables);
        this.tree.refilter();
        this.render();
        this._enabled = false;
        this.triggered = false;
    };
    TypeFilterController.prototype.onEventOrInput = function (e) {
        if (typeof e === 'string') {
            this.onInput(e);
        }
        else if (e instanceof MouseEvent || e.keyCode === 9 /* Escape */ || (e.keyCode === 1 /* Backspace */ && (isMacintosh ? e.altKey : e.ctrlKey))) {
            this.onInput('');
        }
        else if (e.keyCode === 1 /* Backspace */) {
            this.onInput(this.pattern.length === 0 ? '' : this.pattern.substr(0, this.pattern.length - 1));
        }
        else {
            this.onInput(this.pattern + e.browserEvent.key);
        }
    };
    TypeFilterController.prototype.onInput = function (pattern) {
        var container = this.view.getHTMLElement();
        if (pattern && !this.domNode.parentElement) {
            container.append(this.domNode);
        }
        else if (!pattern && this.domNode.parentElement) {
            this.domNode.remove();
            this.tree.domFocus();
        }
        this._pattern = pattern;
        this._onDidChangePattern.fire(pattern);
        this.filter.pattern = pattern;
        this.tree.refilter();
        if (pattern) {
            this.tree.focusNext(0, true, undefined, function (node) { return !FuzzyScore.isDefault(node.filterData); });
        }
        var focus = this.tree.getFocus();
        if (focus.length > 0) {
            var element = focus[0];
            if (this.tree.getRelativeTop(element) === null) {
                this.tree.reveal(element, 0.5);
            }
        }
        this.render();
        if (!pattern) {
            this.triggered = false;
        }
    };
    TypeFilterController.prototype.onDragStart = function () {
        var _this = this;
        var container = this.view.getHTMLElement();
        var left = getDomNodePagePosition(container).left;
        var containerWidth = container.clientWidth;
        var midContainerWidth = containerWidth / 2;
        var width = this.domNode.clientWidth;
        var disposables = [];
        var positionClassName = this.positionClassName;
        var updatePosition = function () {
            switch (positionClassName) {
                case 'nw':
                    _this.domNode.style.top = "4px";
                    _this.domNode.style.left = "4px";
                    break;
                case 'ne':
                    _this.domNode.style.top = "4px";
                    _this.domNode.style.left = containerWidth - width - 6 + "px";
                    break;
            }
        };
        var onDragOver = function (event) {
            event.preventDefault(); // needed so that the drop event fires (https://stackoverflow.com/questions/21339924/drop-event-not-firing-in-chrome)
            var x = event.screenX - left;
            if (event.dataTransfer) {
                event.dataTransfer.dropEffect = 'none';
            }
            if (x < midContainerWidth) {
                positionClassName = 'nw';
            }
            else {
                positionClassName = 'ne';
            }
            updatePosition();
        };
        var onDragEnd = function () {
            _this.positionClassName = positionClassName;
            _this.domNode.className = "monaco-list-type-filter " + _this.positionClassName;
            _this.domNode.style.top = null;
            _this.domNode.style.left = null;
            dispose(disposables);
        };
        updatePosition();
        removeClass(this.domNode, positionClassName);
        addClass(this.domNode, 'dragging');
        disposables.push(toDisposable(function () { return removeClass(_this.domNode, 'dragging'); }));
        domEvent(document, 'dragover')(onDragOver, null, disposables);
        domEvent(this.domNode, 'dragend')(onDragEnd, null, disposables);
        StaticDND.CurrentDragAndDropData = new DragAndDropData('vscode-ui');
        disposables.push(toDisposable(function () { return StaticDND.CurrentDragAndDropData = undefined; }));
    };
    TypeFilterController.prototype.onDidSpliceModel = function () {
        if (!this._enabled || this.pattern.length === 0) {
            return;
        }
        this.tree.refilter();
        this.render();
    };
    TypeFilterController.prototype.onDidChangeFilterOnType = function () {
        this.tree.updateOptions({ filterOnType: this.filterOnTypeDomNode.checked });
        this.tree.refilter();
        this.tree.domFocus();
        this.render();
        this.updateFilterOnTypeTitle();
    };
    TypeFilterController.prototype.updateFilterOnTypeTitle = function () {
        if (this.filterOnType) {
            this.filterOnTypeDomNode.title = localize('disable filter on type', "Disable Filter on Type");
        }
        else {
            this.filterOnTypeDomNode.title = localize('enable filter on type', "Enable Filter on Type");
        }
    };
    TypeFilterController.prototype.render = function () {
        var noMatches = this.filter.totalCount > 0 && this.filter.matchCount === 0;
        if (this.pattern && this.tree.options.filterOnType && noMatches) {
            this.messageDomNode.textContent = localize('empty', "No elements found");
            this._empty = true;
        }
        else {
            this.messageDomNode.innerHTML = '';
            this._empty = false;
        }
        toggleClass(this.domNode, 'no-matches', noMatches);
        this.domNode.title = localize('found', "Matched {0} out of {1} elements", this.filter.matchCount, this.filter.totalCount);
        this.labelDomNode.textContent = this.pattern.length > 16 ? '…' + this.pattern.substr(this.pattern.length - 16) : this.pattern;
        this._onDidChangeEmptyState.fire(this._empty);
    };
    TypeFilterController.prototype.shouldAllowFocus = function (node) {
        if (!this.enabled || !this.pattern || this.filterOnType) {
            return true;
        }
        if (this.filter.totalCount > 0 && this.filter.matchCount <= 1) {
            return true;
        }
        return !FuzzyScore.isDefault(node.filterData);
    };
    TypeFilterController.prototype.dispose = function () {
        this.disable();
        this._onDidChangePattern.dispose();
        this.disposables = dispose(this.disposables);
    };
    return TypeFilterController;
}());
function isInputElement(e) {
    return e.tagName === 'INPUT' || e.tagName === 'TEXTAREA';
}
function asTreeEvent(event) {
    return {
        elements: event.elements.map(function (node) { return node.element; }),
        browserEvent: event.browserEvent
    };
}
function dfs(node, fn) {
    fn(node);
    node.children.forEach(function (child) { return dfs(child, fn); });
}
/**
 * The trait concept needs to exist at the tree level, because collapsed
 * tree nodes will not be known by the list.
 */
var Trait = /** @class */ (function () {
    function Trait(identityProvider) {
        this.identityProvider = identityProvider;
        this.nodes = [];
        this._onDidChange = new Emitter();
        this.onDidChange = this._onDidChange.event;
    }
    Object.defineProperty(Trait.prototype, "nodeSet", {
        get: function () {
            if (!this._nodeSet) {
                this._nodeSet = this.createNodeSet();
            }
            return this._nodeSet;
        },
        enumerable: true,
        configurable: true
    });
    Trait.prototype.set = function (nodes, browserEvent) {
        if (equals(this.nodes, nodes)) {
            return;
        }
        this._set(nodes, false, browserEvent);
    };
    Trait.prototype._set = function (nodes, silent, browserEvent) {
        this.nodes = nodes.slice();
        this.elements = undefined;
        this._nodeSet = undefined;
        if (!silent) {
            var that_1 = this;
            this._onDidChange.fire({ get elements() { return that_1.get(); }, browserEvent: browserEvent });
        }
    };
    Trait.prototype.get = function () {
        if (!this.elements) {
            this.elements = this.nodes.map(function (node) { return node.element; });
        }
        return this.elements.slice();
    };
    Trait.prototype.getNodes = function () {
        return this.nodes;
    };
    Trait.prototype.has = function (node) {
        return this.nodeSet.has(node);
    };
    Trait.prototype.onDidModelSplice = function (_a) {
        var _this = this;
        var insertedNodes = _a.insertedNodes, deletedNodes = _a.deletedNodes;
        if (!this.identityProvider) {
            var set_1 = this.createNodeSet();
            var visit_1 = function (node) { return set_1.delete(node); };
            deletedNodes.forEach(function (node) { return dfs(node, visit_1); });
            this.set(values(set_1));
            return;
        }
        var deletedNodesIdSet = new Set();
        var deletedNodesVisitor = function (node) { return deletedNodesIdSet.add(_this.identityProvider.getId(node.element).toString()); };
        deletedNodes.forEach(function (node) { return dfs(node, deletedNodesVisitor); });
        var insertedNodesMap = new Map();
        var insertedNodesVisitor = function (node) { return insertedNodesMap.set(_this.identityProvider.getId(node.element).toString(), node); };
        insertedNodes.forEach(function (node) { return dfs(node, insertedNodesVisitor); });
        var nodes = [];
        var silent = true;
        for (var _i = 0, _b = this.nodes; _i < _b.length; _i++) {
            var node = _b[_i];
            var id = this.identityProvider.getId(node.element).toString();
            var wasDeleted = deletedNodesIdSet.has(id);
            if (!wasDeleted) {
                nodes.push(node);
            }
            else {
                var insertedNode = insertedNodesMap.get(id);
                if (insertedNode) {
                    nodes.push(insertedNode);
                }
                else {
                    silent = false;
                }
            }
        }
        this._set(nodes, silent);
    };
    Trait.prototype.createNodeSet = function () {
        var set = new Set();
        for (var _i = 0, _a = this.nodes; _i < _a.length; _i++) {
            var node = _a[_i];
            set.add(node);
        }
        return set;
    };
    return Trait;
}());
var TreeNodeListMouseController = /** @class */ (function (_super) {
    __extends(TreeNodeListMouseController, _super);
    function TreeNodeListMouseController(list, tree) {
        var _this = _super.call(this, list) || this;
        _this.tree = tree;
        return _this;
    }
    TreeNodeListMouseController.prototype.onPointer = function (e) {
        if (isInputElement(e.browserEvent.target)) {
            return;
        }
        var node = e.element;
        if (!node) {
            return _super.prototype.onPointer.call(this, e);
        }
        if (this.isSelectionRangeChangeEvent(e) || this.isSelectionSingleChangeEvent(e)) {
            return _super.prototype.onPointer.call(this, e);
        }
        var onTwistie = hasClass(e.browserEvent.target, 'monaco-tl-twistie');
        if (!this.tree.openOnSingleClick && e.browserEvent.detail !== 2 && !onTwistie) {
            return _super.prototype.onPointer.call(this, e);
        }
        var expandOnlyOnTwistieClick = false;
        if (typeof this.tree.expandOnlyOnTwistieClick === 'function') {
            expandOnlyOnTwistieClick = this.tree.expandOnlyOnTwistieClick(node.element);
        }
        else {
            expandOnlyOnTwistieClick = !!this.tree.expandOnlyOnTwistieClick;
        }
        if (expandOnlyOnTwistieClick && !onTwistie) {
            return _super.prototype.onPointer.call(this, e);
        }
        var model = this.tree.model; // internal
        var location = model.getNodeLocation(node);
        var recursive = e.browserEvent.altKey;
        model.setCollapsed(location, undefined, recursive);
        if (expandOnlyOnTwistieClick && onTwistie) {
            return;
        }
        _super.prototype.onPointer.call(this, e);
    };
    TreeNodeListMouseController.prototype.onDoubleClick = function (e) {
        var onTwistie = hasClass(e.browserEvent.target, 'monaco-tl-twistie');
        if (onTwistie) {
            return;
        }
        _super.prototype.onDoubleClick.call(this, e);
    };
    return TreeNodeListMouseController;
}(MouseController));
/**
 * We use this List subclass to restore selection and focus as nodes
 * get rendered in the list, possibly due to a node expand() call.
 */
var TreeNodeList = /** @class */ (function (_super) {
    __extends(TreeNodeList, _super);
    function TreeNodeList(container, virtualDelegate, renderers, focusTrait, selectionTrait, options) {
        var _this = _super.call(this, container, virtualDelegate, renderers, options) || this;
        _this.focusTrait = focusTrait;
        _this.selectionTrait = selectionTrait;
        return _this;
    }
    TreeNodeList.prototype.createMouseController = function (options) {
        return new TreeNodeListMouseController(this, options.tree);
    };
    TreeNodeList.prototype.splice = function (start, deleteCount, elements) {
        var _this = this;
        if (elements === void 0) { elements = []; }
        _super.prototype.splice.call(this, start, deleteCount, elements);
        if (elements.length === 0) {
            return;
        }
        var additionalFocus = [];
        var additionalSelection = [];
        elements.forEach(function (node, index) {
            if (_this.focusTrait.has(node)) {
                additionalFocus.push(start + index);
            }
            if (_this.selectionTrait.has(node)) {
                additionalSelection.push(start + index);
            }
        });
        if (additionalFocus.length > 0) {
            _super.prototype.setFocus.call(this, distinctES6(_super.prototype.getFocus.call(this).concat(additionalFocus)));
        }
        if (additionalSelection.length > 0) {
            _super.prototype.setSelection.call(this, distinctES6(_super.prototype.getSelection.call(this).concat(additionalSelection)));
        }
    };
    TreeNodeList.prototype.setFocus = function (indexes, browserEvent, fromAPI) {
        var _this = this;
        if (fromAPI === void 0) { fromAPI = false; }
        _super.prototype.setFocus.call(this, indexes, browserEvent);
        if (!fromAPI) {
            this.focusTrait.set(indexes.map(function (i) { return _this.element(i); }), browserEvent);
        }
    };
    TreeNodeList.prototype.setSelection = function (indexes, browserEvent, fromAPI) {
        var _this = this;
        if (fromAPI === void 0) { fromAPI = false; }
        _super.prototype.setSelection.call(this, indexes, browserEvent);
        if (!fromAPI) {
            this.selectionTrait.set(indexes.map(function (i) { return _this.element(i); }), browserEvent);
        }
    };
    return TreeNodeList;
}(List));
var AbstractTree = /** @class */ (function () {
    function AbstractTree(container, delegate, renderers, _options) {
        var _a;
        var _this = this;
        if (_options === void 0) { _options = {}; }
        this._options = _options;
        this.eventBufferer = new EventBufferer();
        this.disposables = [];
        this._onWillRefilter = new Emitter();
        this.onWillRefilter = this._onWillRefilter.event;
        this._onDidUpdateOptions = new Emitter();
        var treeDelegate = new ComposedTreeDelegate(delegate);
        var onDidChangeCollapseStateRelay = new Relay();
        var onDidChangeActiveNodes = new Relay();
        var activeNodes = new EventCollection(onDidChangeActiveNodes.event);
        this.disposables.push(activeNodes);
        this.renderers = renderers.map(function (r) { return new TreeRenderer(r, onDidChangeCollapseStateRelay.event, activeNodes, _options); });
        (_a = this.disposables).push.apply(_a, this.renderers);
        var filter;
        if (_options.keyboardNavigationLabelProvider) {
            filter = new TypeFilter(this, _options.keyboardNavigationLabelProvider, _options.filter);
            _options = __assign({}, _options, { filter: filter }); // TODO need typescript help here
            this.disposables.push(filter);
        }
        this.focus = new Trait(_options.identityProvider);
        this.selection = new Trait(_options.identityProvider);
        this.view = new TreeNodeList(container, treeDelegate, this.renderers, this.focus, this.selection, __assign({}, asListOptions(function () { return _this.model; }, _options), { tree: this }));
        this.model = this.createModel(this.view, _options);
        onDidChangeCollapseStateRelay.input = this.model.onDidChangeCollapseState;
        this.model.onDidSplice(function (e) {
            _this.focus.onDidModelSplice(e);
            _this.selection.onDidModelSplice(e);
        }, null, this.disposables);
        onDidChangeActiveNodes.input = Event.map(Event.any(this.focus.onDidChange, this.selection.onDidChange, this.model.onDidSplice), function () { return _this.focus.getNodes().concat(_this.selection.getNodes()); });
        if (_options.keyboardSupport !== false) {
            var onKeyDown = Event.chain(this.view.onKeyDown)
                .filter(function (e) { return !isInputElement(e.target); })
                .map(function (e) { return new StandardKeyboardEvent(e); });
            onKeyDown.filter(function (e) { return e.keyCode === 15 /* LeftArrow */; }).on(this.onLeftArrow, this, this.disposables);
            onKeyDown.filter(function (e) { return e.keyCode === 17 /* RightArrow */; }).on(this.onRightArrow, this, this.disposables);
            onKeyDown.filter(function (e) { return e.keyCode === 10 /* Space */; }).on(this.onSpace, this, this.disposables);
        }
        if (_options.keyboardNavigationLabelProvider) {
            this.typeFilterController = new TypeFilterController(this, this.model, this.view, filter, _options.keyboardNavigationLabelProvider);
            this.focusNavigationFilter = function (node) { return _this.typeFilterController.shouldAllowFocus(node); };
            this.disposables.push(this.typeFilterController);
        }
        this.styleElement = createStyleSheet(this.view.getHTMLElement());
        toggleClass(this.getHTMLElement(), 'always', this._options.renderIndentGuides === RenderIndentGuides.Always);
    }
    Object.defineProperty(AbstractTree.prototype, "onDidChangeFocus", {
        get: function () { return this.eventBufferer.wrapEvent(this.focus.onDidChange); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "onDidChangeSelection", {
        get: function () { return this.eventBufferer.wrapEvent(this.selection.onDidChange); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "onDidOpen", {
        get: function () { return Event.map(this.view.onDidOpen, asTreeEvent); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "onDidFocus", {
        get: function () { return this.view.onDidFocus; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "onDidChangeCollapseState", {
        get: function () { return this.model.onDidChangeCollapseState; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "openOnSingleClick", {
        get: function () { return typeof this._options.openOnSingleClick === 'undefined' ? true : this._options.openOnSingleClick; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "expandOnlyOnTwistieClick", {
        get: function () { return typeof this._options.expandOnlyOnTwistieClick === 'undefined' ? false : this._options.expandOnlyOnTwistieClick; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AbstractTree.prototype, "onDidDispose", {
        get: function () { return this.view.onDidDispose; },
        enumerable: true,
        configurable: true
    });
    AbstractTree.prototype.updateOptions = function (optionsUpdate) {
        if (optionsUpdate === void 0) { optionsUpdate = {}; }
        this._options = __assign({}, this._options, optionsUpdate);
        for (var _i = 0, _a = this.renderers; _i < _a.length; _i++) {
            var renderer = _a[_i];
            renderer.updateOptions(optionsUpdate);
        }
        this.view.updateOptions({
            enableKeyboardNavigation: this._options.simpleKeyboardNavigation,
            automaticKeyboardNavigation: this._options.automaticKeyboardNavigation
        });
        if (this.typeFilterController) {
            this.typeFilterController.updateOptions(this._options);
        }
        this._onDidUpdateOptions.fire(this._options);
        toggleClass(this.getHTMLElement(), 'always', this._options.renderIndentGuides === RenderIndentGuides.Always);
    };
    Object.defineProperty(AbstractTree.prototype, "options", {
        get: function () {
            return this._options;
        },
        enumerable: true,
        configurable: true
    });
    // Widget
    AbstractTree.prototype.getHTMLElement = function () {
        return this.view.getHTMLElement();
    };
    Object.defineProperty(AbstractTree.prototype, "scrollTop", {
        get: function () {
            return this.view.scrollTop;
        },
        set: function (scrollTop) {
            this.view.scrollTop = scrollTop;
        },
        enumerable: true,
        configurable: true
    });
    AbstractTree.prototype.domFocus = function () {
        this.view.domFocus();
    };
    AbstractTree.prototype.layout = function (height, width) {
        this.view.layout(height, width);
    };
    AbstractTree.prototype.style = function (styles) {
        var suffix = "." + this.view.domId;
        var content = [];
        if (styles.treeIndentGuidesStroke) {
            content.push(".monaco-list" + suffix + ":hover .monaco-tl-indent > .indent-guide, .monaco-list" + suffix + ".always .monaco-tl-indent > .indent-guide  { border-color: " + styles.treeIndentGuidesStroke.transparent(0.4) + "; }");
            content.push(".monaco-list" + suffix + " .monaco-tl-indent > .indent-guide.active { border-color: " + styles.treeIndentGuidesStroke + "; }");
        }
        var newStyles = content.join('\n');
        if (newStyles !== this.styleElement.innerHTML) {
            this.styleElement.innerHTML = newStyles;
        }
        this.view.style(styles);
    };
    // Tree
    AbstractTree.prototype.getNode = function (location) {
        return this.model.getNode(location);
    };
    AbstractTree.prototype.collapse = function (location, recursive) {
        if (recursive === void 0) { recursive = false; }
        return this.model.setCollapsed(location, true, recursive);
    };
    AbstractTree.prototype.expand = function (location, recursive) {
        if (recursive === void 0) { recursive = false; }
        return this.model.setCollapsed(location, false, recursive);
    };
    AbstractTree.prototype.isCollapsed = function (location) {
        return this.model.isCollapsed(location);
    };
    AbstractTree.prototype.refilter = function () {
        this._onWillRefilter.fire(undefined);
        this.model.refilter();
    };
    AbstractTree.prototype.setSelection = function (elements, browserEvent) {
        var _this = this;
        var nodes = elements.map(function (e) { return _this.model.getNode(e); });
        this.selection.set(nodes, browserEvent);
        var indexes = elements.map(function (e) { return _this.model.getListIndex(e); }).filter(function (i) { return i > -1; });
        this.view.setSelection(indexes, browserEvent, true);
    };
    AbstractTree.prototype.getSelection = function () {
        return this.selection.get();
    };
    AbstractTree.prototype.setFocus = function (elements, browserEvent) {
        var _this = this;
        var nodes = elements.map(function (e) { return _this.model.getNode(e); });
        this.focus.set(nodes, browserEvent);
        var indexes = elements.map(function (e) { return _this.model.getListIndex(e); }).filter(function (i) { return i > -1; });
        this.view.setFocus(indexes, browserEvent, true);
    };
    AbstractTree.prototype.focusNext = function (n, loop, browserEvent, filter) {
        if (n === void 0) { n = 1; }
        if (loop === void 0) { loop = false; }
        if (filter === void 0) { filter = this.focusNavigationFilter; }
        this.view.focusNext(n, loop, browserEvent, filter);
    };
    AbstractTree.prototype.getFocus = function () {
        return this.focus.get();
    };
    AbstractTree.prototype.reveal = function (location, relativeTop) {
        this.model.expandTo(location);
        var index = this.model.getListIndex(location);
        if (index === -1) {
            return;
        }
        this.view.reveal(index, relativeTop);
    };
    /**
     * Returns the relative position of an element rendered in the list.
     * Returns `null` if the element isn't *entirely* in the visible viewport.
     */
    AbstractTree.prototype.getRelativeTop = function (location) {
        var index = this.model.getListIndex(location);
        if (index === -1) {
            return null;
        }
        return this.view.getRelativeTop(index);
    };
    // List
    AbstractTree.prototype.onLeftArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        var nodes = this.view.getFocusedElements();
        if (nodes.length === 0) {
            return;
        }
        var node = nodes[0];
        var location = this.model.getNodeLocation(node);
        var didChange = this.model.setCollapsed(location, true);
        if (!didChange) {
            var parentLocation = this.model.getParentNodeLocation(location);
            if (parentLocation === null) {
                return;
            }
            var parentListIndex = this.model.getListIndex(parentLocation);
            this.view.reveal(parentListIndex);
            this.view.setFocus([parentListIndex]);
        }
    };
    AbstractTree.prototype.onRightArrow = function (e) {
        e.preventDefault();
        e.stopPropagation();
        var nodes = this.view.getFocusedElements();
        if (nodes.length === 0) {
            return;
        }
        var node = nodes[0];
        var location = this.model.getNodeLocation(node);
        var didChange = this.model.setCollapsed(location, false);
        if (!didChange) {
            if (!node.children.some(function (child) { return child.visible; })) {
                return;
            }
            var focusedIndex = this.view.getFocus()[0];
            var firstChildIndex = focusedIndex + 1;
            this.view.reveal(firstChildIndex);
            this.view.setFocus([firstChildIndex]);
        }
    };
    AbstractTree.prototype.onSpace = function (e) {
        e.preventDefault();
        e.stopPropagation();
        var nodes = this.view.getFocusedElements();
        if (nodes.length === 0) {
            return;
        }
        var node = nodes[0];
        var location = this.model.getNodeLocation(node);
        var recursive = e.browserEvent.altKey;
        this.model.setCollapsed(location, undefined, recursive);
    };
    AbstractTree.prototype.dispose = function () {
        this.disposables = dispose(this.disposables);
        this.view.dispose();
    };
    return AbstractTree;
}());
export { AbstractTree };
