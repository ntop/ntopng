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
import { AbstractTree } from './abstractTree.js';
import { ObjectTreeModel } from './objectTreeModel.js';
var ObjectTree = /** @class */ (function (_super) {
    __extends(ObjectTree, _super);
    function ObjectTree(container, delegate, renderers, options) {
        if (options === void 0) { options = {}; }
        return _super.call(this, container, delegate, renderers, options) || this;
    }
    Object.defineProperty(ObjectTree.prototype, "onDidChangeCollapseState", {
        get: function () { return this.model.onDidChangeCollapseState; },
        enumerable: true,
        configurable: true
    });
    ObjectTree.prototype.setChildren = function (element, children) {
        return this.model.setChildren(element, children);
    };
    ObjectTree.prototype.rerender = function (element) {
        if (element === undefined) {
            this.view.rerender();
            return;
        }
        this.model.rerender(element);
    };
    ObjectTree.prototype.createModel = function (view, options) {
        return new ObjectTreeModel(view, options);
    };
    return ObjectTree;
}(AbstractTree));
export { ObjectTree };
