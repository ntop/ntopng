/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import { CoreNavigationCommands } from '../controller/coreCommands.js';
import { Position } from '../../common/core/position.js';
var ViewController = /** @class */ (function () {
    function ViewController(configuration, viewModel, outgoingEvents, commandDelegate) {
        this.configuration = configuration;
        this.viewModel = viewModel;
        this.outgoingEvents = outgoingEvents;
        this.commandDelegate = commandDelegate;
    }
    ViewController.prototype._execMouseCommand = function (editorCommand, args) {
        args.source = 'mouse';
        this.commandDelegate.executeEditorCommand(editorCommand, args);
    };
    ViewController.prototype.paste = function (source, text, pasteOnNewLine, multicursorText) {
        this.commandDelegate.paste(source, text, pasteOnNewLine, multicursorText);
    };
    ViewController.prototype.type = function (source, text) {
        this.commandDelegate.type(source, text);
    };
    ViewController.prototype.replacePreviousChar = function (source, text, replaceCharCnt) {
        this.commandDelegate.replacePreviousChar(source, text, replaceCharCnt);
    };
    ViewController.prototype.compositionStart = function (source) {
        this.commandDelegate.compositionStart(source);
    };
    ViewController.prototype.compositionEnd = function (source) {
        this.commandDelegate.compositionEnd(source);
    };
    ViewController.prototype.cut = function (source) {
        this.commandDelegate.cut(source);
    };
    ViewController.prototype.setSelection = function (source, modelSelection) {
        this.commandDelegate.executeEditorCommand(CoreNavigationCommands.SetSelection, {
            source: source,
            selection: modelSelection
        });
    };
    ViewController.prototype._validateViewColumn = function (viewPosition) {
        var minColumn = this.viewModel.getLineMinColumn(viewPosition.lineNumber);
        if (viewPosition.column < minColumn) {
            return new Position(viewPosition.lineNumber, minColumn);
        }
        return viewPosition;
    };
    ViewController.prototype._hasMulticursorModifier = function (data) {
        switch (this.configuration.editor.multiCursorModifier) {
            case 'altKey':
                return data.altKey;
            case 'ctrlKey':
                return data.ctrlKey;
            case 'metaKey':
                return data.metaKey;
        }
        return false;
    };
    ViewController.prototype._hasNonMulticursorModifier = function (data) {
        switch (this.configuration.editor.multiCursorModifier) {
            case 'altKey':
                return data.ctrlKey || data.metaKey;
            case 'ctrlKey':
                return data.altKey || data.metaKey;
            case 'metaKey':
                return data.ctrlKey || data.altKey;
        }
        return false;
    };
    ViewController.prototype.dispatchMouse = function (data) {
        if (data.middleButton) {
            if (data.inSelectionMode) {
                this._columnSelect(data.position, data.mouseColumn, true);
            }
            else {
                this.moveTo(data.position);
            }
        }
        else if (data.startedOnLineNumbers) {
            // If the dragging started on the gutter, then have operations work on the entire line
            if (this._hasMulticursorModifier(data)) {
                if (data.inSelectionMode) {
                    this._lastCursorLineSelect(data.position);
                }
                else {
                    this._createCursor(data.position, true);
                }
            }
            else {
                if (data.inSelectionMode) {
                    this._lineSelectDrag(data.position);
                }
                else {
                    this._lineSelect(data.position);
                }
            }
        }
        else if (data.mouseDownCount >= 4) {
            this._selectAll();
        }
        else if (data.mouseDownCount === 3) {
            if (this._hasMulticursorModifier(data)) {
                if (data.inSelectionMode) {
                    this._lastCursorLineSelectDrag(data.position);
                }
                else {
                    this._lastCursorLineSelect(data.position);
                }
            }
            else {
                if (data.inSelectionMode) {
                    this._lineSelectDrag(data.position);
                }
                else {
                    this._lineSelect(data.position);
                }
            }
        }
        else if (data.mouseDownCount === 2) {
            if (this._hasMulticursorModifier(data)) {
                this._lastCursorWordSelect(data.position);
            }
            else {
                if (data.inSelectionMode) {
                    this._wordSelectDrag(data.position);
                }
                else {
                    this._wordSelect(data.position);
                }
            }
        }
        else {
            if (this._hasMulticursorModifier(data)) {
                if (!this._hasNonMulticursorModifier(data)) {
                    if (data.shiftKey) {
                        this._columnSelect(data.position, data.mouseColumn, false);
                    }
                    else {
                        // Do multi-cursor operations only when purely alt is pressed
                        if (data.inSelectionMode) {
                            this._lastCursorMoveToSelect(data.position);
                        }
                        else {
                            this._createCursor(data.position, false);
                        }
                    }
                }
            }
            else {
                if (data.inSelectionMode) {
                    if (data.altKey) {
                        this._columnSelect(data.position, data.mouseColumn, true);
                    }
                    else {
                        this._moveToSelect(data.position);
                    }
                }
                else {
                    this.moveTo(data.position);
                }
            }
        }
    };
    ViewController.prototype._usualArgs = function (viewPosition) {
        viewPosition = this._validateViewColumn(viewPosition);
        return {
            position: this._convertViewToModelPosition(viewPosition),
            viewPosition: viewPosition
        };
    };
    ViewController.prototype.moveTo = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.MoveTo, this._usualArgs(viewPosition));
    };
    ViewController.prototype._moveToSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.MoveToSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._columnSelect = function (viewPosition, mouseColumn, setAnchorIfNotSet) {
        viewPosition = this._validateViewColumn(viewPosition);
        this._execMouseCommand(CoreNavigationCommands.ColumnSelect, {
            position: this._convertViewToModelPosition(viewPosition),
            viewPosition: viewPosition,
            mouseColumn: mouseColumn,
            setAnchorIfNotSet: setAnchorIfNotSet
        });
    };
    ViewController.prototype._createCursor = function (viewPosition, wholeLine) {
        viewPosition = this._validateViewColumn(viewPosition);
        this._execMouseCommand(CoreNavigationCommands.CreateCursor, {
            position: this._convertViewToModelPosition(viewPosition),
            viewPosition: viewPosition,
            wholeLine: wholeLine
        });
    };
    ViewController.prototype._lastCursorMoveToSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LastCursorMoveToSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._wordSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.WordSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._wordSelectDrag = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.WordSelectDrag, this._usualArgs(viewPosition));
    };
    ViewController.prototype._lastCursorWordSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LastCursorWordSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._lineSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LineSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._lineSelectDrag = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LineSelectDrag, this._usualArgs(viewPosition));
    };
    ViewController.prototype._lastCursorLineSelect = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LastCursorLineSelect, this._usualArgs(viewPosition));
    };
    ViewController.prototype._lastCursorLineSelectDrag = function (viewPosition) {
        this._execMouseCommand(CoreNavigationCommands.LastCursorLineSelectDrag, this._usualArgs(viewPosition));
    };
    ViewController.prototype._selectAll = function () {
        this._execMouseCommand(CoreNavigationCommands.SelectAll, {});
    };
    // ----------------------
    ViewController.prototype._convertViewToModelPosition = function (viewPosition) {
        return this.viewModel.coordinatesConverter.convertViewPositionToModelPosition(viewPosition);
    };
    ViewController.prototype.emitKeyDown = function (e) {
        this.outgoingEvents.emitKeyDown(e);
    };
    ViewController.prototype.emitKeyUp = function (e) {
        this.outgoingEvents.emitKeyUp(e);
    };
    ViewController.prototype.emitContextMenu = function (e) {
        this.outgoingEvents.emitContextMenu(e);
    };
    ViewController.prototype.emitMouseMove = function (e) {
        this.outgoingEvents.emitMouseMove(e);
    };
    ViewController.prototype.emitMouseLeave = function (e) {
        this.outgoingEvents.emitMouseLeave(e);
    };
    ViewController.prototype.emitMouseUp = function (e) {
        this.outgoingEvents.emitMouseUp(e);
    };
    ViewController.prototype.emitMouseDown = function (e) {
        this.outgoingEvents.emitMouseDown(e);
    };
    ViewController.prototype.emitMouseDrag = function (e) {
        this.outgoingEvents.emitMouseDrag(e);
    };
    ViewController.prototype.emitMouseDrop = function (e) {
        this.outgoingEvents.emitMouseDrop(e);
    };
    ViewController.prototype.emitMouseWheel = function (e) {
        this.outgoingEvents.emitMouseWheel(e);
    };
    return ViewController;
}());
export { ViewController };
