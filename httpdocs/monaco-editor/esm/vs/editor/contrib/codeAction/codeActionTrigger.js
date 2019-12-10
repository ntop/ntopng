/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { startsWith } from '../../../base/common/strings.js';
var CodeActionKind = /** @class */ (function () {
    function CodeActionKind(value) {
        this.value = value;
    }
    CodeActionKind.prototype.equals = function (other) {
        return this.value === other.value;
    };
    CodeActionKind.prototype.contains = function (other) {
        return this.equals(other) || startsWith(other.value, this.value + CodeActionKind.sep);
    };
    CodeActionKind.prototype.intersects = function (other) {
        return this.contains(other) || other.contains(this);
    };
    CodeActionKind.sep = '.';
    CodeActionKind.Empty = new CodeActionKind('');
    CodeActionKind.QuickFix = new CodeActionKind('quickfix');
    CodeActionKind.Refactor = new CodeActionKind('refactor');
    CodeActionKind.Source = new CodeActionKind('source');
    CodeActionKind.SourceOrganizeImports = new CodeActionKind('source.organizeImports');
    CodeActionKind.SourceFixAll = new CodeActionKind('source.fixAll');
    return CodeActionKind;
}());
export { CodeActionKind };
export function mayIncludeActionsOfKind(filter, providedKind) {
    // A provided kind may be a subset or superset of our filtered kind.
    if (filter.kind && !filter.kind.intersects(providedKind)) {
        return false;
    }
    // Don't return source actions unless they are explicitly requested
    if (CodeActionKind.Source.contains(providedKind) && !filter.includeSourceActions) {
        return false;
    }
    return true;
}
export function filtersAction(filter, action) {
    var actionKind = action.kind ? new CodeActionKind(action.kind) : undefined;
    // Filter out actions by kind
    if (filter.kind) {
        if (!actionKind || !filter.kind.contains(actionKind)) {
            return false;
        }
    }
    // Don't return source actions unless they are explicitly requested
    if (!filter.includeSourceActions) {
        if (actionKind && CodeActionKind.Source.contains(actionKind)) {
            return false;
        }
    }
    if (filter.onlyIncludePreferredActions) {
        if (!action.isPreferred) {
            return false;
        }
    }
    return true;
}
