/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { createKeybinding } from '../../../base/common/keyCodes.js';
import { OS } from '../../../base/common/platform.js';
import { CommandsRegistry } from '../../commands/common/commands.js';
import { Registry } from '../../registry/common/platform.js';
var KeybindingsRegistryImpl = /** @class */ (function () {
    function KeybindingsRegistryImpl() {
        this._coreKeybindings = [];
        this._extensionKeybindings = [];
        this._cachedMergedKeybindings = null;
    }
    /**
     * Take current platform into account and reduce to primary & secondary.
     */
    KeybindingsRegistryImpl.bindToCurrentPlatform = function (kb) {
        if (OS === 1 /* Windows */) {
            if (kb && kb.win) {
                return kb.win;
            }
        }
        else if (OS === 2 /* Macintosh */) {
            if (kb && kb.mac) {
                return kb.mac;
            }
        }
        else {
            if (kb && kb.linux) {
                return kb.linux;
            }
        }
        return kb;
    };
    KeybindingsRegistryImpl.prototype.registerKeybindingRule = function (rule) {
        var actualKb = KeybindingsRegistryImpl.bindToCurrentPlatform(rule);
        if (actualKb && actualKb.primary) {
            var kk = createKeybinding(actualKb.primary, OS);
            if (kk) {
                this._registerDefaultKeybinding(kk, rule.id, undefined, rule.weight, 0, rule.when);
            }
        }
        if (actualKb && Array.isArray(actualKb.secondary)) {
            for (var i = 0, len = actualKb.secondary.length; i < len; i++) {
                var k = actualKb.secondary[i];
                var kk = createKeybinding(k, OS);
                if (kk) {
                    this._registerDefaultKeybinding(kk, rule.id, undefined, rule.weight, -i - 1, rule.when);
                }
            }
        }
    };
    KeybindingsRegistryImpl.prototype.registerCommandAndKeybindingRule = function (desc) {
        this.registerKeybindingRule(desc);
        CommandsRegistry.registerCommand(desc);
    };
    KeybindingsRegistryImpl._mightProduceChar = function (keyCode) {
        if (keyCode >= 21 /* KEY_0 */ && keyCode <= 30 /* KEY_9 */) {
            return true;
        }
        if (keyCode >= 31 /* KEY_A */ && keyCode <= 56 /* KEY_Z */) {
            return true;
        }
        return (keyCode === 80 /* US_SEMICOLON */
            || keyCode === 81 /* US_EQUAL */
            || keyCode === 82 /* US_COMMA */
            || keyCode === 83 /* US_MINUS */
            || keyCode === 84 /* US_DOT */
            || keyCode === 85 /* US_SLASH */
            || keyCode === 86 /* US_BACKTICK */
            || keyCode === 110 /* ABNT_C1 */
            || keyCode === 111 /* ABNT_C2 */
            || keyCode === 87 /* US_OPEN_SQUARE_BRACKET */
            || keyCode === 88 /* US_BACKSLASH */
            || keyCode === 89 /* US_CLOSE_SQUARE_BRACKET */
            || keyCode === 90 /* US_QUOTE */
            || keyCode === 91 /* OEM_8 */
            || keyCode === 92 /* OEM_102 */);
    };
    KeybindingsRegistryImpl.prototype._assertNoCtrlAlt = function (keybinding, commandId) {
        if (keybinding.ctrlKey && keybinding.altKey && !keybinding.metaKey) {
            if (KeybindingsRegistryImpl._mightProduceChar(keybinding.keyCode)) {
                console.warn('Ctrl+Alt+ keybindings should not be used by default under Windows. Offender: ', keybinding, ' for ', commandId);
            }
        }
    };
    KeybindingsRegistryImpl.prototype._registerDefaultKeybinding = function (keybinding, commandId, commandArgs, weight1, weight2, when) {
        if (OS === 1 /* Windows */) {
            this._assertNoCtrlAlt(keybinding.parts[0], commandId);
        }
        this._coreKeybindings.push({
            keybinding: keybinding,
            command: commandId,
            commandArgs: commandArgs,
            when: when,
            weight1: weight1,
            weight2: weight2
        });
        this._cachedMergedKeybindings = null;
    };
    KeybindingsRegistryImpl.prototype.getDefaultKeybindings = function () {
        if (!this._cachedMergedKeybindings) {
            this._cachedMergedKeybindings = [].concat(this._coreKeybindings).concat(this._extensionKeybindings);
            this._cachedMergedKeybindings.sort(sorter);
        }
        return this._cachedMergedKeybindings.slice(0);
    };
    return KeybindingsRegistryImpl;
}());
export var KeybindingsRegistry = new KeybindingsRegistryImpl();
// Define extension point ids
export var Extensions = {
    EditorModes: 'platform.keybindingsRegistry'
};
Registry.add(Extensions.EditorModes, KeybindingsRegistry);
function sorter(a, b) {
    if (a.weight1 !== b.weight1) {
        return a.weight1 - b.weight1;
    }
    if (a.command < b.command) {
        return -1;
    }
    if (a.command > b.command) {
        return 1;
    }
    return a.weight2 - b.weight2;
}
