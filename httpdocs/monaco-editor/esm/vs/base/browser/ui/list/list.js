/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
export var ListAriaRootRole;
(function (ListAriaRootRole) {
    /** default tree structure role */
    ListAriaRootRole["TREE"] = "tree";
    /** role='tree' can interfere with screenreaders reading nested elements inside the tree row. Use FORM in that case. */
    ListAriaRootRole["FORM"] = "form";
})(ListAriaRootRole || (ListAriaRootRole = {}));
