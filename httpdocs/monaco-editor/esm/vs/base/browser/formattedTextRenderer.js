/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as DOM from './dom.js';
export function renderText(text, options) {
    if (options === void 0) { options = {}; }
    var element = createElement(options);
    element.textContent = text;
    return element;
}
export function renderFormattedText(formattedText, options) {
    if (options === void 0) { options = {}; }
    var element = createElement(options);
    _renderFormattedText(element, parseFormattedText(formattedText), options.actionHandler);
    return element;
}
export function createElement(options) {
    var tagName = options.inline ? 'span' : 'div';
    var element = document.createElement(tagName);
    if (options.className) {
        element.className = options.className;
    }
    return element;
}
var StringStream = /** @class */ (function () {
    function StringStream(source) {
        this.source = source;
        this.index = 0;
    }
    StringStream.prototype.eos = function () {
        return this.index >= this.source.length;
    };
    StringStream.prototype.next = function () {
        var next = this.peek();
        this.advance();
        return next;
    };
    StringStream.prototype.peek = function () {
        return this.source[this.index];
    };
    StringStream.prototype.advance = function () {
        this.index++;
    };
    return StringStream;
}());
function _renderFormattedText(element, treeNode, actionHandler) {
    var child;
    if (treeNode.type === 2 /* Text */) {
        child = document.createTextNode(treeNode.content || '');
    }
    else if (treeNode.type === 3 /* Bold */) {
        child = document.createElement('b');
    }
    else if (treeNode.type === 4 /* Italics */) {
        child = document.createElement('i');
    }
    else if (treeNode.type === 5 /* Action */ && actionHandler) {
        var a = document.createElement('a');
        a.href = '#';
        actionHandler.disposeables.add(DOM.addStandardDisposableListener(a, 'click', function (event) {
            actionHandler.callback(String(treeNode.index), event);
        }));
        child = a;
    }
    else if (treeNode.type === 7 /* NewLine */) {
        child = document.createElement('br');
    }
    else if (treeNode.type === 1 /* Root */) {
        child = element;
    }
    if (child && element !== child) {
        element.appendChild(child);
    }
    if (child && Array.isArray(treeNode.children)) {
        treeNode.children.forEach(function (nodeChild) {
            _renderFormattedText(child, nodeChild, actionHandler);
        });
    }
}
function parseFormattedText(content) {
    var root = {
        type: 1 /* Root */,
        children: []
    };
    var actionViewItemIndex = 0;
    var current = root;
    var stack = [];
    var stream = new StringStream(content);
    while (!stream.eos()) {
        var next = stream.next();
        var isEscapedFormatType = (next === '\\' && formatTagType(stream.peek()) !== 0 /* Invalid */);
        if (isEscapedFormatType) {
            next = stream.next(); // unread the backslash if it escapes a format tag type
        }
        if (!isEscapedFormatType && isFormatTag(next) && next === stream.peek()) {
            stream.advance();
            if (current.type === 2 /* Text */) {
                current = stack.pop();
            }
            var type = formatTagType(next);
            if (current.type === type || (current.type === 5 /* Action */ && type === 6 /* ActionClose */)) {
                current = stack.pop();
            }
            else {
                var newCurrent = {
                    type: type,
                    children: []
                };
                if (type === 5 /* Action */) {
                    newCurrent.index = actionViewItemIndex;
                    actionViewItemIndex++;
                }
                current.children.push(newCurrent);
                stack.push(current);
                current = newCurrent;
            }
        }
        else if (next === '\n') {
            if (current.type === 2 /* Text */) {
                current = stack.pop();
            }
            current.children.push({
                type: 7 /* NewLine */
            });
        }
        else {
            if (current.type !== 2 /* Text */) {
                var textCurrent = {
                    type: 2 /* Text */,
                    content: next
                };
                current.children.push(textCurrent);
                stack.push(current);
                current = textCurrent;
            }
            else {
                current.content += next;
            }
        }
    }
    if (current.type === 2 /* Text */) {
        current = stack.pop();
    }
    if (stack.length) {
        // incorrectly formatted string literal
    }
    return root;
}
function isFormatTag(char) {
    return formatTagType(char) !== 0 /* Invalid */;
}
function formatTagType(char) {
    switch (char) {
        case '*':
            return 3 /* Bold */;
        case '_':
            return 4 /* Italics */;
        case '[':
            return 5 /* Action */;
        case ']':
            return 6 /* ActionClose */;
        default:
            return 0 /* Invalid */;
    }
}
