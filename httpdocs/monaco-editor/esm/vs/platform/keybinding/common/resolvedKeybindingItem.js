/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var ResolvedKeybindingItem = /** @class */ (function () {
    function ResolvedKeybindingItem(resolvedKeybinding, command, commandArgs, when, isDefault) {
        this.resolvedKeybinding = resolvedKeybinding;
        this.keypressParts = resolvedKeybinding ? removeElementsAfterNulls(resolvedKeybinding.getDispatchParts()) : [];
        this.bubble = (command ? command.charCodeAt(0) === 94 /* Caret */ : false);
        this.command = this.bubble ? command.substr(1) : command;
        this.commandArgs = commandArgs;
        this.when = when;
        this.isDefault = isDefault;
    }
    return ResolvedKeybindingItem;
}());
export { ResolvedKeybindingItem };
export function removeElementsAfterNulls(arr) {
    var result = [];
    for (var i = 0, len = arr.length; i < len; i++) {
        var element = arr[i];
        if (!element) {
            // stop processing at first encountered null
            return result;
        }
        result.push(element);
    }
    return result;
}
