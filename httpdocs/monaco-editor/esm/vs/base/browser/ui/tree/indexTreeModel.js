/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { tail2 } from '../../../common/arrays.js';
import { Emitter, EventBufferer } from '../../../common/event.js';
import { Iterator } from '../../../common/iterator.js';
export function isFilterResult(obj) {
    return typeof obj === 'object' && 'visibility' in obj && 'data' in obj;
}
export function getVisibleState(visibility) {
    switch (visibility) {
        case true: return 1 /* Visible */;
        case false: return 0 /* Hidden */;
        default: return visibility;
    }
}
function treeNodeToElement(node) {
    var element = node.element, collapsed = node.collapsed;
    var children = Iterator.map(Iterator.fromArray(node.children), treeNodeToElement);
    return { element: element, children: children, collapsed: collapsed };
}
var IndexTreeModel = /** @class */ (function () {
    function IndexTreeModel(list, rootElement, options) {
        if (options === void 0) { options = {}; }
        this.list = list;
        this.rootRef = [];
        this.eventBufferer = new EventBufferer();
        this._onDidChangeCollapseState = new Emitter();
        this.onDidChangeCollapseState = this.eventBufferer.wrapEvent(this._onDidChangeCollapseState.event);
        this._onDidChangeRenderNodeCount = new Emitter();
        this.onDidChangeRenderNodeCount = this.eventBufferer.wrapEvent(this._onDidChangeRenderNodeCount.event);
        this._onDidSplice = new Emitter();
        this.onDidSplice = this._onDidSplice.event;
        this.collapseByDefault = typeof options.collapseByDefault === 'undefined' ? false : options.collapseByDefault;
        this.filter = options.filter;
        this.autoExpandSingleChildren = typeof options.autoExpandSingleChildren === 'undefined' ? false : options.autoExpandSingleChildren;
        this.root = {
            parent: undefined,
            element: rootElement,
            children: [],
            depth: 0,
            visibleChildrenCount: 0,
            visibleChildIndex: -1,
            collapsible: false,
            collapsed: false,
            renderNodeCount: 0,
            visible: true,
            filterData: undefined
        };
    }
    IndexTreeModel.prototype.splice = function (location, deleteCount, toInsert, onDidCreateNode, onDidDeleteNode) {
        var _a;
        var _this = this;
        if (location.length === 0) {
            throw new Error('Invalid tree location');
        }
        var _b = this.getParentNodeWithListIndex(location), parentNode = _b.parentNode, listIndex = _b.listIndex, revealed = _b.revealed, visible = _b.visible;
        var treeListElementsToInsert = [];
        var nodesToInsertIterator = Iterator.map(Iterator.from(toInsert), function (el) { return _this.createTreeNode(el, parentNode, parentNode.visible ? 1 /* Visible */ : 0 /* Hidden */, revealed, treeListElementsToInsert, onDidCreateNode); });
        var lastIndex = location[location.length - 1];
        // figure out what's the visible child start index right before the
        // splice point
        var visibleChildStartIndex = 0;
        for (var i = lastIndex; i >= 0 && i < parentNode.children.length; i--) {
            var child = parentNode.children[i];
            if (child.visible) {
                visibleChildStartIndex = child.visibleChildIndex;
                break;
            }
        }
        var nodesToInsert = [];
        var insertedVisibleChildrenCount = 0;
        var renderNodeCount = 0;
        Iterator.forEach(nodesToInsertIterator, function (child) {
            nodesToInsert.push(child);
            renderNodeCount += child.renderNodeCount;
            if (child.visible) {
                child.visibleChildIndex = visibleChildStartIndex + insertedVisibleChildrenCount++;
            }
        });
        var deletedNodes = (_a = parentNode.children).splice.apply(_a, [lastIndex, deleteCount].concat(nodesToInsert));
        // figure out what is the count of deleted visible children
        var deletedVisibleChildrenCount = 0;
        for (var _i = 0, deletedNodes_1 = deletedNodes; _i < deletedNodes_1.length; _i++) {
            var child = deletedNodes_1[_i];
            if (child.visible) {
                deletedVisibleChildrenCount++;
            }
        }
        // and adjust for all visible children after the splice point
        if (deletedVisibleChildrenCount !== 0) {
            for (var i = lastIndex + nodesToInsert.length; i < parentNode.children.length; i++) {
                var child = parentNode.children[i];
                if (child.visible) {
                    child.visibleChildIndex -= deletedVisibleChildrenCount;
                }
            }
        }
        // update parent's visible children count
        parentNode.visibleChildrenCount += insertedVisibleChildrenCount - deletedVisibleChildrenCount;
        if (revealed && visible) {
            var visibleDeleteCount = deletedNodes.reduce(function (r, node) { return r + node.renderNodeCount; }, 0);
            this._updateAncestorsRenderNodeCount(parentNode, renderNodeCount - visibleDeleteCount);
            this.list.splice(listIndex, visibleDeleteCount, treeListElementsToInsert);
        }
        if (deletedNodes.length > 0 && onDidDeleteNode) {
            var visit_1 = function (node) {
                onDidDeleteNode(node);
                node.children.forEach(visit_1);
            };
            deletedNodes.forEach(visit_1);
        }
        var result = Iterator.map(Iterator.fromArray(deletedNodes), treeNodeToElement);
        this._onDidSplice.fire({ insertedNodes: nodesToInsert, deletedNodes: deletedNodes });
        return result;
    };
    IndexTreeModel.prototype.rerender = function (location) {
        if (location.length === 0) {
            throw new Error('Invalid tree location');
        }
        var _a = this.getTreeNodeWithListIndex(location), node = _a.node, listIndex = _a.listIndex, revealed = _a.revealed;
        if (revealed) {
            this.list.splice(listIndex, 1, [node]);
        }
    };
    IndexTreeModel.prototype.getListIndex = function (location) {
        var _a = this.getTreeNodeWithListIndex(location), listIndex = _a.listIndex, visible = _a.visible, revealed = _a.revealed;
        return visible && revealed ? listIndex : -1;
    };
    IndexTreeModel.prototype.getListRenderCount = function (location) {
        return this.getTreeNode(location).renderNodeCount;
    };
    IndexTreeModel.prototype.isCollapsed = function (location) {
        return this.getTreeNode(location).collapsed;
    };
    IndexTreeModel.prototype.setCollapsed = function (location, collapsed, recursive) {
        var _this = this;
        var node = this.getTreeNode(location);
        if (typeof collapsed === 'undefined') {
            collapsed = !node.collapsed;
        }
        return this.eventBufferer.bufferEvents(function () { return _this._setCollapsed(location, collapsed, recursive); });
    };
    IndexTreeModel.prototype._setCollapsed = function (location, collapsed, recursive) {
        var _a = this.getTreeNodeWithListIndex(location), node = _a.node, listIndex = _a.listIndex, revealed = _a.revealed;
        var result = this._setListNodeCollapsed(node, listIndex, revealed, collapsed, recursive || false);
        if (node !== this.root && this.autoExpandSingleChildren && !collapsed && !recursive) {
            var onlyVisibleChildIndex = -1;
            for (var i = 0; i < node.children.length; i++) {
                var child = node.children[i];
                if (child.visible) {
                    if (onlyVisibleChildIndex > -1) {
                        onlyVisibleChildIndex = -1;
                        break;
                    }
                    else {
                        onlyVisibleChildIndex = i;
                    }
                }
            }
            if (onlyVisibleChildIndex > -1) {
                this._setCollapsed(location.concat([onlyVisibleChildIndex]), false, false);
            }
        }
        return result;
    };
    IndexTreeModel.prototype._setListNodeCollapsed = function (node, listIndex, revealed, collapsed, recursive) {
        var result = this._setNodeCollapsed(node, collapsed, recursive, false);
        if (!revealed || !node.visible) {
            return result;
        }
        var previousRenderNodeCount = node.renderNodeCount;
        var toInsert = this.updateNodeAfterCollapseChange(node);
        var deleteCount = previousRenderNodeCount - (listIndex === -1 ? 0 : 1);
        this.list.splice(listIndex + 1, deleteCount, toInsert.slice(1));
        return result;
    };
    IndexTreeModel.prototype._setNodeCollapsed = function (node, collapsed, recursive, deep) {
        var result = node.collapsible && node.collapsed !== collapsed;
        if (node.collapsible) {
            node.collapsed = collapsed;
            if (result) {
                this._onDidChangeCollapseState.fire({ node: node, deep: deep });
            }
        }
        if (recursive) {
            for (var _i = 0, _a = node.children; _i < _a.length; _i++) {
                var child = _a[_i];
                result = this._setNodeCollapsed(child, collapsed, true, true) || result;
            }
        }
        return result;
    };
    IndexTreeModel.prototype.expandTo = function (location) {
        var _this = this;
        this.eventBufferer.bufferEvents(function () {
            var node = _this.getTreeNode(location);
            while (node.parent) {
                node = node.parent;
                location = location.slice(0, location.length - 1);
                if (node.collapsed) {
                    _this._setCollapsed(location, false);
                }
            }
        });
    };
    IndexTreeModel.prototype.refilter = function () {
        var previousRenderNodeCount = this.root.renderNodeCount;
        var toInsert = this.updateNodeAfterFilterChange(this.root);
        this.list.splice(0, previousRenderNodeCount, toInsert);
    };
    IndexTreeModel.prototype.createTreeNode = function (treeElement, parent, parentVisibility, revealed, treeListElements, onDidCreateNode) {
        var _this = this;
        var node = {
            parent: parent,
            element: treeElement.element,
            children: [],
            depth: parent.depth + 1,
            visibleChildrenCount: 0,
            visibleChildIndex: -1,
            collapsible: typeof treeElement.collapsible === 'boolean' ? treeElement.collapsible : (typeof treeElement.collapsed !== 'undefined'),
            collapsed: typeof treeElement.collapsed === 'undefined' ? this.collapseByDefault : treeElement.collapsed,
            renderNodeCount: 1,
            visible: true,
            filterData: undefined
        };
        var visibility = this._filterNode(node, parentVisibility);
        if (revealed) {
            treeListElements.push(node);
        }
        var childElements = Iterator.from(treeElement.children);
        var childRevealed = revealed && visibility !== 0 /* Hidden */ && !node.collapsed;
        var childNodes = Iterator.map(childElements, function (el) { return _this.createTreeNode(el, node, visibility, childRevealed, treeListElements, onDidCreateNode); });
        var visibleChildrenCount = 0;
        var renderNodeCount = 1;
        Iterator.forEach(childNodes, function (child) {
            node.children.push(child);
            renderNodeCount += child.renderNodeCount;
            if (child.visible) {
                child.visibleChildIndex = visibleChildrenCount++;
            }
        });
        node.collapsible = node.collapsible || node.children.length > 0;
        node.visibleChildrenCount = visibleChildrenCount;
        node.visible = visibility === 2 /* Recurse */ ? visibleChildrenCount > 0 : (visibility === 1 /* Visible */);
        if (!node.visible) {
            node.renderNodeCount = 0;
            if (revealed) {
                treeListElements.pop();
            }
        }
        else if (!node.collapsed) {
            node.renderNodeCount = renderNodeCount;
        }
        if (onDidCreateNode) {
            onDidCreateNode(node);
        }
        return node;
    };
    IndexTreeModel.prototype.updateNodeAfterCollapseChange = function (node) {
        var previousRenderNodeCount = node.renderNodeCount;
        var result = [];
        this._updateNodeAfterCollapseChange(node, result);
        this._updateAncestorsRenderNodeCount(node.parent, result.length - previousRenderNodeCount);
        return result;
    };
    IndexTreeModel.prototype._updateNodeAfterCollapseChange = function (node, result) {
        if (node.visible === false) {
            return 0;
        }
        result.push(node);
        node.renderNodeCount = 1;
        if (!node.collapsed) {
            for (var _i = 0, _a = node.children; _i < _a.length; _i++) {
                var child = _a[_i];
                node.renderNodeCount += this._updateNodeAfterCollapseChange(child, result);
            }
        }
        this._onDidChangeRenderNodeCount.fire(node);
        return node.renderNodeCount;
    };
    IndexTreeModel.prototype.updateNodeAfterFilterChange = function (node) {
        var previousRenderNodeCount = node.renderNodeCount;
        var result = [];
        this._updateNodeAfterFilterChange(node, node.visible ? 1 /* Visible */ : 0 /* Hidden */, result);
        this._updateAncestorsRenderNodeCount(node.parent, result.length - previousRenderNodeCount);
        return result;
    };
    IndexTreeModel.prototype._updateNodeAfterFilterChange = function (node, parentVisibility, result, revealed) {
        if (revealed === void 0) { revealed = true; }
        var visibility;
        if (node !== this.root) {
            visibility = this._filterNode(node, parentVisibility);
            if (visibility === 0 /* Hidden */) {
                node.visible = false;
                return false;
            }
            if (revealed) {
                result.push(node);
            }
        }
        var resultStartLength = result.length;
        node.renderNodeCount = node === this.root ? 0 : 1;
        var hasVisibleDescendants = false;
        if (!node.collapsed || visibility !== 0 /* Hidden */) {
            var visibleChildIndex = 0;
            for (var _i = 0, _a = node.children; _i < _a.length; _i++) {
                var child = _a[_i];
                hasVisibleDescendants = this._updateNodeAfterFilterChange(child, visibility, result, revealed && !node.collapsed) || hasVisibleDescendants;
                if (child.visible) {
                    child.visibleChildIndex = visibleChildIndex++;
                }
            }
            node.visibleChildrenCount = visibleChildIndex;
        }
        else {
            node.visibleChildrenCount = 0;
        }
        if (node !== this.root) {
            node.visible = visibility === 2 /* Recurse */ ? hasVisibleDescendants : (visibility === 1 /* Visible */);
        }
        if (!node.visible) {
            node.renderNodeCount = 0;
            if (revealed) {
                result.pop();
            }
        }
        else if (!node.collapsed) {
            node.renderNodeCount += result.length - resultStartLength;
        }
        this._onDidChangeRenderNodeCount.fire(node);
        return node.visible;
    };
    IndexTreeModel.prototype._updateAncestorsRenderNodeCount = function (node, diff) {
        if (diff === 0) {
            return;
        }
        while (node) {
            node.renderNodeCount += diff;
            this._onDidChangeRenderNodeCount.fire(node);
            node = node.parent;
        }
    };
    IndexTreeModel.prototype._filterNode = function (node, parentVisibility) {
        var result = this.filter ? this.filter.filter(node.element, parentVisibility) : 1 /* Visible */;
        if (typeof result === 'boolean') {
            node.filterData = undefined;
            return result ? 1 /* Visible */ : 0 /* Hidden */;
        }
        else if (isFilterResult(result)) {
            node.filterData = result.data;
            return getVisibleState(result.visibility);
        }
        else {
            node.filterData = undefined;
            return getVisibleState(result);
        }
    };
    // cheap
    IndexTreeModel.prototype.getTreeNode = function (location, node) {
        if (node === void 0) { node = this.root; }
        if (!location || location.length === 0) {
            return node;
        }
        var index = location[0], rest = location.slice(1);
        if (index < 0 || index > node.children.length) {
            throw new Error('Invalid tree location');
        }
        return this.getTreeNode(rest, node.children[index]);
    };
    // expensive
    IndexTreeModel.prototype.getTreeNodeWithListIndex = function (location) {
        if (location.length === 0) {
            return { node: this.root, listIndex: -1, revealed: true, visible: false };
        }
        var _a = this.getParentNodeWithListIndex(location), parentNode = _a.parentNode, listIndex = _a.listIndex, revealed = _a.revealed, visible = _a.visible;
        var index = location[location.length - 1];
        if (index < 0 || index > parentNode.children.length) {
            throw new Error('Invalid tree location');
        }
        var node = parentNode.children[index];
        return { node: node, listIndex: listIndex, revealed: revealed, visible: visible && node.visible };
    };
    IndexTreeModel.prototype.getParentNodeWithListIndex = function (location, node, listIndex, revealed, visible) {
        if (node === void 0) { node = this.root; }
        if (listIndex === void 0) { listIndex = 0; }
        if (revealed === void 0) { revealed = true; }
        if (visible === void 0) { visible = true; }
        var index = location[0], rest = location.slice(1);
        if (index < 0 || index > node.children.length) {
            throw new Error('Invalid tree location');
        }
        // TODO@joao perf!
        for (var i = 0; i < index; i++) {
            listIndex += node.children[i].renderNodeCount;
        }
        revealed = revealed && !node.collapsed;
        visible = visible && node.visible;
        if (rest.length === 0) {
            return { parentNode: node, listIndex: listIndex, revealed: revealed, visible: visible };
        }
        return this.getParentNodeWithListIndex(rest, node.children[index], listIndex + 1, revealed, visible);
    };
    IndexTreeModel.prototype.getNode = function (location) {
        if (location === void 0) { location = []; }
        return this.getTreeNode(location);
    };
    // TODO@joao perf!
    IndexTreeModel.prototype.getNodeLocation = function (node) {
        var location = [];
        while (node.parent) {
            location.push(node.parent.children.indexOf(node));
            node = node.parent;
        }
        return location.reverse();
    };
    IndexTreeModel.prototype.getParentNodeLocation = function (location) {
        if (location.length <= 1) {
            return [];
        }
        return tail2(location)[0];
    };
    return IndexTreeModel;
}());
export { IndexTreeModel };
