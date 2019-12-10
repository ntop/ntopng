import { ContextKeyOrExpr } from '../../contextkey/common/contextkey.js';
var KeybindingResolver = /** @class */ (function () {
    function KeybindingResolver(defaultKeybindings, overrides) {
        this._defaultKeybindings = defaultKeybindings;
        this._defaultBoundCommands = new Map();
        for (var i = 0, len = defaultKeybindings.length; i < len; i++) {
            var command = defaultKeybindings[i].command;
            if (command) {
                this._defaultBoundCommands.set(command, true);
            }
        }
        this._map = new Map();
        this._lookupMap = new Map();
        this._keybindings = KeybindingResolver.combine(defaultKeybindings, overrides);
        for (var i = 0, len = this._keybindings.length; i < len; i++) {
            var k = this._keybindings[i];
            if (k.keypressParts.length === 0) {
                // unbound
                continue;
            }
            // TODO@chords
            this._addKeyPress(k.keypressParts[0], k);
        }
    }
    KeybindingResolver._isTargetedForRemoval = function (defaultKb, keypressFirstPart, keypressChordPart, command, when) {
        if (defaultKb.command !== command) {
            return false;
        }
        // TODO@chords
        if (keypressFirstPart && defaultKb.keypressParts[0] !== keypressFirstPart) {
            return false;
        }
        // TODO@chords
        if (keypressChordPart && defaultKb.keypressParts[1] !== keypressChordPart) {
            return false;
        }
        if (when) {
            if (!defaultKb.when) {
                return false;
            }
            if (!when.equals(defaultKb.when)) {
                return false;
            }
        }
        return true;
    };
    /**
     * Looks for rules containing -command in `overrides` and removes them directly from `defaults`.
     */
    KeybindingResolver.combine = function (defaults, rawOverrides) {
        defaults = defaults.slice(0);
        var overrides = [];
        for (var _i = 0, rawOverrides_1 = rawOverrides; _i < rawOverrides_1.length; _i++) {
            var override = rawOverrides_1[_i];
            if (!override.command || override.command.length === 0 || override.command.charAt(0) !== '-') {
                overrides.push(override);
                continue;
            }
            var command = override.command.substr(1);
            // TODO@chords
            var keypressFirstPart = override.keypressParts[0];
            var keypressChordPart = override.keypressParts[1];
            var when = override.when;
            for (var j = defaults.length - 1; j >= 0; j--) {
                if (this._isTargetedForRemoval(defaults[j], keypressFirstPart, keypressChordPart, command, when)) {
                    defaults.splice(j, 1);
                }
            }
        }
        return defaults.concat(overrides);
    };
    KeybindingResolver.prototype._addKeyPress = function (keypress, item) {
        var conflicts = this._map.get(keypress);
        if (typeof conflicts === 'undefined') {
            // There is no conflict so far
            this._map.set(keypress, [item]);
            this._addToLookupMap(item);
            return;
        }
        for (var i = conflicts.length - 1; i >= 0; i--) {
            var conflict = conflicts[i];
            if (conflict.command === item.command) {
                continue;
            }
            var conflictIsChord = (conflict.keypressParts.length > 1);
            var itemIsChord = (item.keypressParts.length > 1);
            // TODO@chords
            if (conflictIsChord && itemIsChord && conflict.keypressParts[1] !== item.keypressParts[1]) {
                // The conflict only shares the chord start with this command
                continue;
            }
            if (KeybindingResolver.whenIsEntirelyIncluded(conflict.when, item.when)) {
                // `item` completely overwrites `conflict`
                // Remove conflict from the lookupMap
                this._removeFromLookupMap(conflict);
            }
        }
        conflicts.push(item);
        this._addToLookupMap(item);
    };
    KeybindingResolver.prototype._addToLookupMap = function (item) {
        if (!item.command) {
            return;
        }
        var arr = this._lookupMap.get(item.command);
        if (typeof arr === 'undefined') {
            arr = [item];
            this._lookupMap.set(item.command, arr);
        }
        else {
            arr.push(item);
        }
    };
    KeybindingResolver.prototype._removeFromLookupMap = function (item) {
        if (!item.command) {
            return;
        }
        var arr = this._lookupMap.get(item.command);
        if (typeof arr === 'undefined') {
            return;
        }
        for (var i = 0, len = arr.length; i < len; i++) {
            if (arr[i] === item) {
                arr.splice(i, 1);
                return;
            }
        }
    };
    /**
     * Returns true if it is provable `a` implies `b`.
     */
    KeybindingResolver.whenIsEntirelyIncluded = function (a, b) {
        if (!b) {
            return true;
        }
        if (!a) {
            return false;
        }
        return this._implies(a, b);
    };
    /**
     * Returns true if it is provable `p` implies `q`.
     */
    KeybindingResolver._implies = function (p, q) {
        var notP = p.negate();
        var terminals = function (node) {
            if (node instanceof ContextKeyOrExpr) {
                return node.expr;
            }
            return [node];
        };
        var expr = terminals(notP).concat(terminals(q));
        for (var i = 0; i < expr.length; i++) {
            var a = expr[i];
            var notA = a.negate();
            for (var j = i + 1; j < expr.length; j++) {
                var b = expr[j];
                if (notA.equals(b)) {
                    return true;
                }
            }
        }
        return false;
    };
    KeybindingResolver.prototype.lookupPrimaryKeybinding = function (commandId) {
        var items = this._lookupMap.get(commandId);
        if (typeof items === 'undefined' || items.length === 0) {
            return null;
        }
        return items[items.length - 1];
    };
    KeybindingResolver.prototype.resolve = function (context, currentChord, keypress) {
        var lookupMap = null;
        if (currentChord !== null) {
            // Fetch all chord bindings for `currentChord`
            var candidates = this._map.get(currentChord);
            if (typeof candidates === 'undefined') {
                // No chords starting with `currentChord`
                return null;
            }
            lookupMap = [];
            for (var i = 0, len = candidates.length; i < len; i++) {
                var candidate = candidates[i];
                // TODO@chords
                if (candidate.keypressParts[1] === keypress) {
                    lookupMap.push(candidate);
                }
            }
        }
        else {
            var candidates = this._map.get(keypress);
            if (typeof candidates === 'undefined') {
                // No bindings with `keypress`
                return null;
            }
            lookupMap = candidates;
        }
        var result = this._findCommand(context, lookupMap);
        if (!result) {
            return null;
        }
        // TODO@chords
        if (currentChord === null && result.keypressParts.length > 1 && result.keypressParts[1] !== null) {
            return {
                enterChord: true,
                commandId: null,
                commandArgs: null,
                bubble: false
            };
        }
        return {
            enterChord: false,
            commandId: result.command,
            commandArgs: result.commandArgs,
            bubble: result.bubble
        };
    };
    KeybindingResolver.prototype._findCommand = function (context, matches) {
        for (var i = matches.length - 1; i >= 0; i--) {
            var k = matches[i];
            if (!KeybindingResolver.contextMatchesRules(context, k.when)) {
                continue;
            }
            return k;
        }
        return null;
    };
    KeybindingResolver.contextMatchesRules = function (context, rules) {
        if (!rules) {
            return true;
        }
        return rules.evaluate(context);
    };
    return KeybindingResolver;
}());
export { KeybindingResolver };
