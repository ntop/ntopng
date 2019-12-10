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
var DataTree = /** @class */ (function (_super) {
    __extends(DataTree, _super);
    function DataTree(container, delegate, renderers, dataSource, options) {
        if (options === void 0) { options = {}; }
        var _this = _super.call(this, container, delegate, renderers, options) || this;
        _this.dataSource = dataSource;
        _this.identityProvider = options.identityProvider;
        return _this;
    }
    DataTree.prototype.createModel = function (view, options) {
        return new ObjectTreeModel(view, options);
    };
    return DataTree;
}(AbstractTree));
export { DataTree };
