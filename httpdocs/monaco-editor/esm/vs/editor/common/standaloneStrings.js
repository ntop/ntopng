/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as nls from '../../nls.js';
export var AccessibilityHelpNLS;
(function (AccessibilityHelpNLS) {
    AccessibilityHelpNLS.noSelection = nls.localize("noSelection", "No selection");
    AccessibilityHelpNLS.singleSelectionRange = nls.localize("singleSelectionRange", "Line {0}, Column {1} ({2} selected)");
    AccessibilityHelpNLS.singleSelection = nls.localize("singleSelection", "Line {0}, Column {1}");
    AccessibilityHelpNLS.multiSelectionRange = nls.localize("multiSelectionRange", "{0} selections ({1} characters selected)");
    AccessibilityHelpNLS.multiSelection = nls.localize("multiSelection", "{0} selections");
    AccessibilityHelpNLS.emergencyConfOn = nls.localize("emergencyConfOn", "Now changing the setting `accessibilitySupport` to 'on'.");
    AccessibilityHelpNLS.openingDocs = nls.localize("openingDocs", "Now opening the Editor Accessibility documentation page.");
    AccessibilityHelpNLS.readonlyDiffEditor = nls.localize("readonlyDiffEditor", " in a read-only pane of a diff editor.");
    AccessibilityHelpNLS.editableDiffEditor = nls.localize("editableDiffEditor", " in a pane of a diff editor.");
    AccessibilityHelpNLS.readonlyEditor = nls.localize("readonlyEditor", " in a read-only code editor");
    AccessibilityHelpNLS.editableEditor = nls.localize("editableEditor", " in a code editor");
    AccessibilityHelpNLS.changeConfigToOnMac = nls.localize("changeConfigToOnMac", "To configure the editor to be optimized for usage with a Screen Reader press Command+E now.");
    AccessibilityHelpNLS.changeConfigToOnWinLinux = nls.localize("changeConfigToOnWinLinux", "To configure the editor to be optimized for usage with a Screen Reader press Control+E now.");
    AccessibilityHelpNLS.auto_on = nls.localize("auto_on", "The editor is configured to be optimized for usage with a Screen Reader.");
    AccessibilityHelpNLS.auto_off = nls.localize("auto_off", "The editor is configured to never be optimized for usage with a Screen Reader, which is not the case at this time.");
    AccessibilityHelpNLS.tabFocusModeOnMsg = nls.localize("tabFocusModeOnMsg", "Pressing Tab in the current editor will move focus to the next focusable element. Toggle this behavior by pressing {0}.");
    AccessibilityHelpNLS.tabFocusModeOnMsgNoKb = nls.localize("tabFocusModeOnMsgNoKb", "Pressing Tab in the current editor will move focus to the next focusable element. The command {0} is currently not triggerable by a keybinding.");
    AccessibilityHelpNLS.tabFocusModeOffMsg = nls.localize("tabFocusModeOffMsg", "Pressing Tab in the current editor will insert the tab character. Toggle this behavior by pressing {0}.");
    AccessibilityHelpNLS.tabFocusModeOffMsgNoKb = nls.localize("tabFocusModeOffMsgNoKb", "Pressing Tab in the current editor will insert the tab character. The command {0} is currently not triggerable by a keybinding.");
    AccessibilityHelpNLS.openDocMac = nls.localize("openDocMac", "Press Command+H now to open a browser window with more information related to editor accessibility.");
    AccessibilityHelpNLS.openDocWinLinux = nls.localize("openDocWinLinux", "Press Control+H now to open a browser window with more information related to editor accessibility.");
    AccessibilityHelpNLS.outroMsg = nls.localize("outroMsg", "You can dismiss this tooltip and return to the editor by pressing Escape or Shift+Escape.");
    AccessibilityHelpNLS.showAccessibilityHelpAction = nls.localize("showAccessibilityHelpAction", "Show Accessibility Help");
})(AccessibilityHelpNLS || (AccessibilityHelpNLS = {}));
export var InspectTokensNLS;
(function (InspectTokensNLS) {
    InspectTokensNLS.inspectTokensAction = nls.localize('inspectTokens', "Developer: Inspect Tokens");
})(InspectTokensNLS || (InspectTokensNLS = {}));
export var GoToLineNLS;
(function (GoToLineNLS) {
    GoToLineNLS.gotoLineLabelValidLineAndColumn = nls.localize('gotoLineLabelValidLineAndColumn', "Go to line {0} and character {1}");
    GoToLineNLS.gotoLineLabelValidLine = nls.localize('gotoLineLabelValidLine', "Go to line {0}");
    GoToLineNLS.gotoLineLabelEmptyWithLineLimit = nls.localize('gotoLineLabelEmptyWithLineLimit', "Type a line number between 1 and {0} to navigate to");
    GoToLineNLS.gotoLineLabelEmptyWithLineAndColumnLimit = nls.localize('gotoLineLabelEmptyWithLineAndColumnLimit', "Type a character between 1 and {0} to navigate to");
    GoToLineNLS.gotoLineAriaLabel = nls.localize('gotoLineAriaLabel', "Current Line: {0}. Go to line {1}.");
    GoToLineNLS.gotoLineActionInput = nls.localize('gotoLineActionInput', "Type a line number, followed by an optional colon and a character number to navigate to");
    GoToLineNLS.gotoLineActionLabel = nls.localize('gotoLineActionLabel', "Go to Line...");
})(GoToLineNLS || (GoToLineNLS = {}));
export var QuickCommandNLS;
(function (QuickCommandNLS) {
    QuickCommandNLS.ariaLabelEntryWithKey = nls.localize('ariaLabelEntryWithKey', "{0}, {1}, commands");
    QuickCommandNLS.ariaLabelEntry = nls.localize('ariaLabelEntry', "{0}, commands");
    QuickCommandNLS.quickCommandActionInput = nls.localize('quickCommandActionInput', "Type the name of an action you want to execute");
    QuickCommandNLS.quickCommandActionLabel = nls.localize('quickCommandActionLabel', "Command Palette");
})(QuickCommandNLS || (QuickCommandNLS = {}));
export var QuickOutlineNLS;
(function (QuickOutlineNLS) {
    QuickOutlineNLS.entryAriaLabel = nls.localize('entryAriaLabel', "{0}, symbols");
    QuickOutlineNLS.quickOutlineActionInput = nls.localize('quickOutlineActionInput', "Type the name of an identifier you wish to navigate to");
    QuickOutlineNLS.quickOutlineActionLabel = nls.localize('quickOutlineActionLabel', "Go to Symbol...");
    QuickOutlineNLS._symbols_ = nls.localize('symbols', "symbols ({0})");
    QuickOutlineNLS._modules_ = nls.localize('modules', "modules ({0})");
    QuickOutlineNLS._class_ = nls.localize('class', "classes ({0})");
    QuickOutlineNLS._interface_ = nls.localize('interface', "interfaces ({0})");
    QuickOutlineNLS._method_ = nls.localize('method', "methods ({0})");
    QuickOutlineNLS._function_ = nls.localize('function', "functions ({0})");
    QuickOutlineNLS._property_ = nls.localize('property', "properties ({0})");
    QuickOutlineNLS._variable_ = nls.localize('variable', "variables ({0})");
    QuickOutlineNLS._variable2_ = nls.localize('variable2', "variables ({0})");
    QuickOutlineNLS._constructor_ = nls.localize('_constructor', "constructors ({0})");
    QuickOutlineNLS._call_ = nls.localize('call', "calls ({0})");
})(QuickOutlineNLS || (QuickOutlineNLS = {}));
export var StandaloneCodeEditorNLS;
(function (StandaloneCodeEditorNLS) {
    StandaloneCodeEditorNLS.editorViewAccessibleLabel = nls.localize('editorViewAccessibleLabel', "Editor content");
    StandaloneCodeEditorNLS.accessibilityHelpMessageIE = nls.localize('accessibilityHelpMessageIE', "Press Ctrl+F1 for Accessibility Options.");
    StandaloneCodeEditorNLS.accessibilityHelpMessage = nls.localize('accessibilityHelpMessage', "Press Alt+F1 for Accessibility Options.");
})(StandaloneCodeEditorNLS || (StandaloneCodeEditorNLS = {}));
export var ToggleHighContrastNLS;
(function (ToggleHighContrastNLS) {
    ToggleHighContrastNLS.toggleHighContrast = nls.localize('toggleHighContrast', "Toggle High Contrast Theme");
})(ToggleHighContrastNLS || (ToggleHighContrastNLS = {}));
export var SimpleServicesNLS;
(function (SimpleServicesNLS) {
    SimpleServicesNLS.bulkEditServiceSummary = nls.localize('bulkEditServiceSummary', "Made {0} edits in {1} files");
})(SimpleServicesNLS || (SimpleServicesNLS = {}));
