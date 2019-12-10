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
import { ComposedTreeDelegate } from './abstractTree.js';
import { ObjectTree } from './objectTree.js';
import { dispose } from '../../../common/lifecycle.js';
import { Emitter, Event } from '../../../common/event.js';
import { timeout, createCancelablePromise } from '../../../common/async.js';
import { Iterator } from '../../../common/iterator.js';
import { ElementsDragAndDropData } from '../list/listView.js';
import { isPromiseCanceledError, onUnexpectedError } from '../../../common/errors.js';
import { toggleClass } from '../../dom.js';
import { values } from '../../../common/map.js';
function createAsyncDataTreeNode(props) {
    return __assign({}, props, { children: [], loading: false, stale: true, slow: false, collapsedByDefault: undefined });
}
function isAncestor(ancestor, descendant) {
    if (!descendant.parent) {
        return false;
    }
    else if (descendant.parent === ancestor) {
        return true;
    }
    else {
        return isAncestor(ancestor, descendant.parent);
    }
}
function intersects(node, other) {
    return node === other || isAncestor(node, other) || isAncestor(other, node);
}
var AsyncDataTreeNodeWrapper = /** @class */ (function () {
    function AsyncDataTreeNodeWrapper(node) {
        this.node = node;
    }
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "element", {
        get: function () { return this.node.element.element; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "parent", {
        get: function () { return this.node.parent && new AsyncDataTreeNodeWrapper(this.node.parent); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "children", {
        get: function () { return this.node.children.map(function (node) { return new AsyncDataTreeNodeWrapper(node); }); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "depth", {
        get: function () { return this.node.depth; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "visibleChildrenCount", {
        get: function () { return this.node.visibleChildrenCount; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "visibleChildIndex", {
        get: function () { return this.node.visibleChildIndex; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "collapsible", {
        get: function () { return this.node.collapsible; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "collapsed", {
        get: function () { return this.node.collapsed; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "visible", {
        get: function () { return this.node.visible; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTreeNodeWrapper.prototype, "filterData", {
        get: function () { return this.node.filterData; },
        enumerable: true,
        configurable: true
    });
    return AsyncDataTreeNodeWrapper;
}());
var DataTreeRenderer = /** @class */ (function () {
    function DataTreeRenderer(renderer, onDidChangeTwistieState) {
        this.renderer = renderer;
        this.onDidChangeTwistieState = onDidChangeTwistieState;
        this.renderedNodes = new Map();
        this.disposables = [];
        this.templateId = renderer.templateId;
    }
    DataTreeRenderer.prototype.renderTemplate = function (container) {
        var templateData = this.renderer.renderTemplate(container);
        return { templateData: templateData };
    };
    DataTreeRenderer.prototype.renderElement = function (node, index, templateData, height) {
        this.renderer.renderElement(new AsyncDataTreeNodeWrapper(node), index, templateData.templateData, height);
    };
    DataTreeRenderer.prototype.renderTwistie = function (element, twistieElement) {
        toggleClass(twistieElement, 'loading', element.slow);
        return false;
    };
    DataTreeRenderer.prototype.disposeElement = function (node, index, templateData, height) {
        if (this.renderer.disposeElement) {
            this.renderer.disposeElement(new AsyncDataTreeNodeWrapper(node), index, templateData.templateData, height);
        }
    };
    DataTreeRenderer.prototype.disposeTemplate = function (templateData) {
        this.renderer.disposeTemplate(templateData.templateData);
    };
    DataTreeRenderer.prototype.dispose = function () {
        this.renderedNodes.clear();
        this.disposables = dispose(this.disposables);
    };
    return DataTreeRenderer;
}());
function asTreeEvent(e) {
    return {
        browserEvent: e.browserEvent,
        elements: e.elements.map(function (e) { return e.element; })
    };
}
export var ChildrenResolutionReason;
(function (ChildrenResolutionReason) {
    ChildrenResolutionReason[ChildrenResolutionReason["Refresh"] = 0] = "Refresh";
    ChildrenResolutionReason[ChildrenResolutionReason["Expand"] = 1] = "Expand";
})(ChildrenResolutionReason || (ChildrenResolutionReason = {}));
function asAsyncDataTreeDragAndDropData(data) {
    if (data instanceof ElementsDragAndDropData) {
        var nodes = data.elements;
        return new ElementsDragAndDropData(nodes.map(function (node) { return node.element; }));
    }
    return data;
}
var AsyncDataTreeNodeListDragAndDrop = /** @class */ (function () {
    function AsyncDataTreeNodeListDragAndDrop(dnd) {
        this.dnd = dnd;
    }
    AsyncDataTreeNodeListDragAndDrop.prototype.getDragURI = function (node) {
        return this.dnd.getDragURI(node.element);
    };
    AsyncDataTreeNodeListDragAndDrop.prototype.getDragLabel = function (nodes) {
        if (this.dnd.getDragLabel) {
            return this.dnd.getDragLabel(nodes.map(function (node) { return node.element; }));
        }
        return undefined;
    };
    AsyncDataTreeNodeListDragAndDrop.prototype.onDragStart = function (data, originalEvent) {
        if (this.dnd.onDragStart) {
            this.dnd.onDragStart(asAsyncDataTreeDragAndDropData(data), originalEvent);
        }
    };
    AsyncDataTreeNodeListDragAndDrop.prototype.onDragOver = function (data, targetNode, targetIndex, originalEvent, raw) {
        if (raw === void 0) { raw = true; }
        return this.dnd.onDragOver(asAsyncDataTreeDragAndDropData(data), targetNode && targetNode.element, targetIndex, originalEvent);
    };
    AsyncDataTreeNodeListDragAndDrop.prototype.drop = function (data, targetNode, targetIndex, originalEvent) {
        this.dnd.drop(asAsyncDataTreeDragAndDropData(data), targetNode && targetNode.element, targetIndex, originalEvent);
    };
    return AsyncDataTreeNodeListDragAndDrop;
}());
function asObjectTreeOptions(options) {
    return options && __assign({}, options, { collapseByDefault: true, identityProvider: options.identityProvider && {
            getId: function (el) {
                return options.identityProvider.getId(el.element);
            }
        }, dnd: options.dnd && new AsyncDataTreeNodeListDragAndDrop(options.dnd), multipleSelectionController: options.multipleSelectionController && {
            isSelectionSingleChangeEvent: function (e) {
                return options.multipleSelectionController.isSelectionSingleChangeEvent(__assign({}, e, { element: e.element }));
            },
            isSelectionRangeChangeEvent: function (e) {
                return options.multipleSelectionController.isSelectionRangeChangeEvent(__assign({}, e, { element: e.element }));
            }
        }, accessibilityProvider: options.accessibilityProvider && {
            getAriaLabel: function (e) {
                return options.accessibilityProvider.getAriaLabel(e.element);
            }
        }, filter: options.filter && {
            filter: function (e, parentVisibility) {
                return options.filter.filter(e.element, parentVisibility);
            }
        }, keyboardNavigationLabelProvider: options.keyboardNavigationLabelProvider && __assign({}, options.keyboardNavigationLabelProvider, { getKeyboardNavigationLabel: function (e) {
                return options.keyboardNavigationLabelProvider.getKeyboardNavigationLabel(e.element);
            } }), sorter: undefined, expandOnlyOnTwistieClick: typeof options.expandOnlyOnTwistieClick === 'undefined' ? undefined : (typeof options.expandOnlyOnTwistieClick !== 'function' ? options.expandOnlyOnTwistieClick : (function (e) { return options.expandOnlyOnTwistieClick(e.element); })), ariaProvider: undefined, additionalScrollHeight: options.additionalScrollHeight });
}
function asTreeElement(node, viewStateContext) {
    var collapsed;
    if (viewStateContext && viewStateContext.viewState.expanded && node.id && viewStateContext.viewState.expanded.indexOf(node.id) > -1) {
        collapsed = false;
    }
    else {
        collapsed = node.collapsedByDefault;
    }
    node.collapsedByDefault = undefined;
    return {
        element: node,
        children: node.hasChildren ? Iterator.map(Iterator.fromArray(node.children), function (child) { return asTreeElement(child, viewStateContext); }) : [],
        collapsible: node.hasChildren,
        collapsed: collapsed
    };
}
function dfs(node, fn) {
    fn(node);
    node.children.forEach(function (child) { return dfs(child, fn); });
}
var AsyncDataTree = /** @class */ (function () {
    function AsyncDataTree(container, delegate, renderers, dataSource, options) {
        var _this = this;
        if (options === void 0) { options = {}; }
        this.dataSource = dataSource;
        this.nodes = new Map();
        this.subTreeRefreshPromises = new Map();
        this.refreshPromises = new Map();
        this._onDidRender = new Emitter();
        this._onDidChangeNodeSlowState = new Emitter();
        this.disposables = [];
        this.identityProvider = options.identityProvider;
        this.autoExpandSingleChildren = typeof options.autoExpandSingleChildren === 'undefined' ? false : options.autoExpandSingleChildren;
        this.sorter = options.sorter;
        this.collapseByDefault = options.collapseByDefault;
        var objectTreeDelegate = new ComposedTreeDelegate(delegate);
        var objectTreeRenderers = renderers.map(function (r) { return new DataTreeRenderer(r, _this._onDidChangeNodeSlowState.event); });
        var objectTreeOptions = asObjectTreeOptions(options) || {};
        this.tree = new ObjectTree(container, objectTreeDelegate, objectTreeRenderers, objectTreeOptions);
        this.root = createAsyncDataTreeNode({
            element: undefined,
            parent: null,
            hasChildren: true
        });
        if (this.identityProvider) {
            this.root = __assign({}, this.root, { id: null });
        }
        this.nodes.set(null, this.root);
        this.tree.onDidChangeCollapseState(this._onDidChangeCollapseState, this, this.disposables);
    }
    Object.defineProperty(AsyncDataTree.prototype, "onDidChangeFocus", {
        get: function () { return Event.map(this.tree.onDidChangeFocus, asTreeEvent); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTree.prototype, "onDidChangeSelection", {
        get: function () { return Event.map(this.tree.onDidChangeSelection, asTreeEvent); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTree.prototype, "onDidOpen", {
        get: function () { return Event.map(this.tree.onDidOpen, asTreeEvent); },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTree.prototype, "onDidFocus", {
        get: function () { return this.tree.onDidFocus; },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(AsyncDataTree.prototype, "onDidDispose", {
        get: function () { return this.tree.onDidDispose; },
        enumerable: true,
        configurable: true
    });
    AsyncDataTree.prototype.updateOptions = function (options) {
        if (options === void 0) { options = {}; }
        this.tree.updateOptions(options);
    };
    // Widget
    AsyncDataTree.prototype.getHTMLElement = function () {
        return this.tree.getHTMLElement();
    };
    Object.defineProperty(AsyncDataTree.prototype, "scrollTop", {
        get: function () {
            return this.tree.scrollTop;
        },
        set: function (scrollTop) {
            this.tree.scrollTop = scrollTop;
        },
        enumerable: true,
        configurable: true
    });
    AsyncDataTree.prototype.domFocus = function () {
        this.tree.domFocus();
    };
    AsyncDataTree.prototype.layout = function (height, width) {
        this.tree.layout(height, width);
    };
    AsyncDataTree.prototype.style = function (styles) {
        this.tree.style(styles);
    };
    // Model
    AsyncDataTree.prototype.getInput = function () {
        return this.root.element;
    };
    AsyncDataTree.prototype.setInput = function (input, viewState) {
        return __awaiter(this, void 0, void 0, function () {
            var viewStateContext;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        this.refreshPromises.forEach(function (promise) { return promise.cancel(); });
                        this.refreshPromises.clear();
                        this.root.element = input;
                        viewStateContext = viewState && { viewState: viewState, focus: [], selection: [] };
                        return [4 /*yield*/, this.updateChildren(input, true, viewStateContext)];
                    case 1:
                        _a.sent();
                        if (viewStateContext) {
                            this.tree.setFocus(viewStateContext.focus);
                            this.tree.setSelection(viewStateContext.selection);
                        }
                        if (viewState && typeof viewState.scrollTop === 'number') {
                            this.scrollTop = viewState.scrollTop;
                        }
                        return [2 /*return*/];
                }
            });
        });
    };
    AsyncDataTree.prototype.updateChildren = function (element, recursive, viewStateContext) {
        if (element === void 0) { element = this.root.element; }
        if (recursive === void 0) { recursive = true; }
        return __awaiter(this, void 0, void 0, function () {
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (typeof this.root.element === 'undefined') {
                            throw new Error('Tree input not set');
                        }
                        if (!this.root.loading) return [3 /*break*/, 3];
                        return [4 /*yield*/, this.subTreeRefreshPromises.get(this.root)];
                    case 1:
                        _a.sent();
                        return [4 /*yield*/, Event.toPromise(this._onDidRender.event)];
                    case 2:
                        _a.sent();
                        _a.label = 3;
                    case 3: return [4 /*yield*/, this.refreshAndRenderNode(this.getDataNode(element), recursive, ChildrenResolutionReason.Refresh, viewStateContext)];
                    case 4:
                        _a.sent();
                        return [2 /*return*/];
                }
            });
        });
    };
    // View
    AsyncDataTree.prototype.rerender = function (element) {
        if (element === undefined || element === this.root.element) {
            this.tree.rerender();
            return;
        }
        var node = this.getDataNode(element);
        this.tree.rerender(node);
    };
    AsyncDataTree.prototype.collapse = function (element, recursive) {
        if (recursive === void 0) { recursive = false; }
        var node = this.getDataNode(element);
        return this.tree.collapse(node === this.root ? null : node, recursive);
    };
    AsyncDataTree.prototype.expand = function (element, recursive) {
        if (recursive === void 0) { recursive = false; }
        return __awaiter(this, void 0, void 0, function () {
            var node, result;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        if (typeof this.root.element === 'undefined') {
                            throw new Error('Tree input not set');
                        }
                        if (!this.root.loading) return [3 /*break*/, 3];
                        return [4 /*yield*/, this.subTreeRefreshPromises.get(this.root)];
                    case 1:
                        _a.sent();
                        return [4 /*yield*/, Event.toPromise(this._onDidRender.event)];
                    case 2:
                        _a.sent();
                        _a.label = 3;
                    case 3:
                        node = this.getDataNode(element);
                        if (node !== this.root && !node.loading && !this.tree.isCollapsed(node)) {
                            return [2 /*return*/, false];
                        }
                        result = this.tree.expand(node === this.root ? null : node, recursive);
                        if (!node.loading) return [3 /*break*/, 6];
                        return [4 /*yield*/, this.subTreeRefreshPromises.get(node)];
                    case 4:
                        _a.sent();
                        return [4 /*yield*/, Event.toPromise(this._onDidRender.event)];
                    case 5:
                        _a.sent();
                        _a.label = 6;
                    case 6: return [2 /*return*/, result];
                }
            });
        });
    };
    AsyncDataTree.prototype.setSelection = function (elements, browserEvent) {
        var _this = this;
        var nodes = elements.map(function (e) { return _this.getDataNode(e); });
        this.tree.setSelection(nodes, browserEvent);
    };
    AsyncDataTree.prototype.getSelection = function () {
        var nodes = this.tree.getSelection();
        return nodes.map(function (n) { return n.element; });
    };
    AsyncDataTree.prototype.setFocus = function (elements, browserEvent) {
        var _this = this;
        var nodes = elements.map(function (e) { return _this.getDataNode(e); });
        this.tree.setFocus(nodes, browserEvent);
    };
    AsyncDataTree.prototype.getFocus = function () {
        var nodes = this.tree.getFocus();
        return nodes.map(function (n) { return n.element; });
    };
    AsyncDataTree.prototype.reveal = function (element, relativeTop) {
        this.tree.reveal(this.getDataNode(element), relativeTop);
    };
    // Implementation
    AsyncDataTree.prototype.getDataNode = function (element) {
        var node = this.nodes.get((element === this.root.element ? null : element));
        if (!node) {
            throw new Error("Data tree node not found: " + element);
        }
        return node;
    };
    AsyncDataTree.prototype.refreshAndRenderNode = function (node, recursive, reason, viewStateContext) {
        return __awaiter(this, void 0, void 0, function () {
            var treeNode, visibleChildren;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0: return [4 /*yield*/, this.refreshNode(node, recursive, viewStateContext)];
                    case 1:
                        _a.sent();
                        this.render(node, viewStateContext);
                        if (!(node !== this.root && this.autoExpandSingleChildren && reason === ChildrenResolutionReason.Expand)) return [3 /*break*/, 3];
                        treeNode = this.tree.getNode(node);
                        visibleChildren = treeNode.children.filter(function (node) { return node.visible; });
                        if (!(visibleChildren.length === 1)) return [3 /*break*/, 3];
                        return [4 /*yield*/, this.tree.expand(visibleChildren[0].element, false)];
                    case 2:
                        _a.sent();
                        _a.label = 3;
                    case 3: return [2 /*return*/];
                }
            });
        });
    };
    AsyncDataTree.prototype.refreshNode = function (node, recursive, viewStateContext) {
        return __awaiter(this, void 0, void 0, function () {
            var result;
            var _this = this;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        this.subTreeRefreshPromises.forEach(function (refreshPromise, refreshNode) {
                            if (!result && intersects(refreshNode, node)) {
                                result = refreshPromise.then(function () { return _this.refreshNode(node, recursive, viewStateContext); });
                            }
                        });
                        if (result) {
                            return [2 /*return*/, result];
                        }
                        result = this.doRefreshSubTree(node, recursive, viewStateContext);
                        this.subTreeRefreshPromises.set(node, result);
                        _a.label = 1;
                    case 1:
                        _a.trys.push([1, , 3, 4]);
                        return [4 /*yield*/, result];
                    case 2:
                        _a.sent();
                        return [3 /*break*/, 4];
                    case 3:
                        this.subTreeRefreshPromises.delete(node);
                        return [7 /*endfinally*/];
                    case 4: return [2 /*return*/];
                }
            });
        });
    };
    AsyncDataTree.prototype.doRefreshSubTree = function (node, recursive, viewStateContext) {
        return __awaiter(this, void 0, void 0, function () {
            var childrenToRefresh;
            var _this = this;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        node.loading = true;
                        _a.label = 1;
                    case 1:
                        _a.trys.push([1, , 4, 5]);
                        return [4 /*yield*/, this.doRefreshNode(node, recursive, viewStateContext)];
                    case 2:
                        childrenToRefresh = _a.sent();
                        node.stale = false;
                        return [4 /*yield*/, Promise.all(childrenToRefresh.map(function (child) { return _this.doRefreshSubTree(child, recursive, viewStateContext); }))];
                    case 3:
                        _a.sent();
                        return [3 /*break*/, 5];
                    case 4:
                        node.loading = false;
                        return [7 /*endfinally*/];
                    case 5: return [2 /*return*/];
                }
            });
        });
    };
    AsyncDataTree.prototype.doRefreshNode = function (node, recursive, viewStateContext) {
        return __awaiter(this, void 0, void 0, function () {
            var childrenPromise, slowTimeout_1, children, err_1;
            var _this = this;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        node.hasChildren = !!this.dataSource.hasChildren(node.element);
                        if (!node.hasChildren) {
                            childrenPromise = Promise.resolve([]);
                        }
                        else {
                            slowTimeout_1 = timeout(800);
                            slowTimeout_1.then(function () {
                                node.slow = true;
                                _this._onDidChangeNodeSlowState.fire(node);
                            }, function (_) { return null; });
                            childrenPromise = this.doGetChildren(node)
                                .finally(function () { return slowTimeout_1.cancel(); });
                        }
                        _a.label = 1;
                    case 1:
                        _a.trys.push([1, 3, 4, 5]);
                        return [4 /*yield*/, childrenPromise];
                    case 2:
                        children = _a.sent();
                        return [2 /*return*/, this.setChildren(node, children, recursive, viewStateContext)];
                    case 3:
                        err_1 = _a.sent();
                        if (node !== this.root) {
                            this.tree.collapse(node === this.root ? null : node);
                        }
                        if (isPromiseCanceledError(err_1)) {
                            return [2 /*return*/, []];
                        }
                        throw err_1;
                    case 4:
                        if (node.slow) {
                            node.slow = false;
                            this._onDidChangeNodeSlowState.fire(node);
                        }
                        return [7 /*endfinally*/];
                    case 5: return [2 /*return*/];
                }
            });
        });
    };
    AsyncDataTree.prototype.doGetChildren = function (node) {
        var _this = this;
        var result = this.refreshPromises.get(node);
        if (result) {
            return result;
        }
        result = createCancelablePromise(function () { return __awaiter(_this, void 0, void 0, function () {
            var children;
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0: return [4 /*yield*/, this.dataSource.getChildren(node.element)];
                    case 1:
                        children = _a.sent();
                        if (this.sorter) {
                            children.sort(this.sorter.compare.bind(this.sorter));
                        }
                        return [2 /*return*/, children];
                }
            });
        }); });
        this.refreshPromises.set(node, result);
        return result.finally(function () { return _this.refreshPromises.delete(node); });
    };
    AsyncDataTree.prototype._onDidChangeCollapseState = function (_a) {
        var node = _a.node, deep = _a.deep;
        if (!node.collapsed && node.element.stale) {
            if (deep) {
                this.collapse(node.element.element);
            }
            else {
                this.refreshAndRenderNode(node.element, false, ChildrenResolutionReason.Expand)
                    .catch(onUnexpectedError);
            }
        }
    };
    AsyncDataTree.prototype.setChildren = function (node, childrenElements, recursive, viewStateContext) {
        var _a;
        var _this = this;
        // perf: if the node was and still is a leaf, avoid all this hassle
        if (node.children.length === 0 && childrenElements.length === 0) {
            return [];
        }
        var nodesToForget = new Map();
        var childrenTreeNodesById = new Map();
        for (var _i = 0, _b = node.children; _i < _b.length; _i++) {
            var child = _b[_i];
            nodesToForget.set(child.element, child);
            if (this.identityProvider) {
                childrenTreeNodesById.set(child.id, this.tree.getNode(child));
            }
        }
        var childrenToRefresh = [];
        var children = childrenElements.map(function (element) {
            var hasChildren = !!_this.dataSource.hasChildren(element);
            if (!_this.identityProvider) {
                var asyncDataTreeNode = createAsyncDataTreeNode({ element: element, parent: node, hasChildren: hasChildren });
                if (hasChildren && _this.collapseByDefault && !_this.collapseByDefault(element)) {
                    asyncDataTreeNode.collapsedByDefault = false;
                    childrenToRefresh.push(asyncDataTreeNode);
                }
                return asyncDataTreeNode;
            }
            var id = _this.identityProvider.getId(element).toString();
            var childNode = childrenTreeNodesById.get(id);
            if (childNode) {
                var asyncDataTreeNode = childNode.element;
                nodesToForget.delete(asyncDataTreeNode.element);
                _this.nodes.delete(asyncDataTreeNode.element);
                _this.nodes.set(element, asyncDataTreeNode);
                asyncDataTreeNode.element = element;
                asyncDataTreeNode.hasChildren = hasChildren;
                if (recursive) {
                    if (childNode.collapsed) {
                        dfs(asyncDataTreeNode, function (node) { return node.stale = true; });
                    }
                    else {
                        childrenToRefresh.push(asyncDataTreeNode);
                    }
                }
                else if (hasChildren && _this.collapseByDefault && !_this.collapseByDefault(element)) {
                    asyncDataTreeNode.collapsedByDefault = false;
                    childrenToRefresh.push(asyncDataTreeNode);
                }
                return asyncDataTreeNode;
            }
            var childAsyncDataTreeNode = createAsyncDataTreeNode({ element: element, parent: node, id: id, hasChildren: hasChildren });
            if (viewStateContext && viewStateContext.viewState.focus && viewStateContext.viewState.focus.indexOf(id) > -1) {
                viewStateContext.focus.push(childAsyncDataTreeNode);
            }
            if (viewStateContext && viewStateContext.viewState.selection && viewStateContext.viewState.selection.indexOf(id) > -1) {
                viewStateContext.selection.push(childAsyncDataTreeNode);
            }
            if (viewStateContext && viewStateContext.viewState.expanded && viewStateContext.viewState.expanded.indexOf(id) > -1) {
                childrenToRefresh.push(childAsyncDataTreeNode);
            }
            else if (hasChildren && _this.collapseByDefault && !_this.collapseByDefault(element)) {
                childAsyncDataTreeNode.collapsedByDefault = false;
                childrenToRefresh.push(childAsyncDataTreeNode);
            }
            return childAsyncDataTreeNode;
        });
        for (var _c = 0, _d = values(nodesToForget); _c < _d.length; _c++) {
            var node_1 = _d[_c];
            dfs(node_1, function (node) { return _this.nodes.delete(node.element); });
        }
        for (var _e = 0, children_1 = children; _e < children_1.length; _e++) {
            var child = children_1[_e];
            this.nodes.set(child.element, child);
        }
        (_a = node.children).splice.apply(_a, [0, node.children.length].concat(children));
        return childrenToRefresh;
    };
    AsyncDataTree.prototype.render = function (node, viewStateContext) {
        var children = node.children.map(function (c) { return asTreeElement(c, viewStateContext); });
        this.tree.setChildren(node === this.root ? null : node, children);
        this._onDidRender.fire();
    };
    AsyncDataTree.prototype.dispose = function () {
        dispose(this.disposables);
    };
    return AsyncDataTree;
}());
export { AsyncDataTree };
