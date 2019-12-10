import { Range, TextEdit, Color, ColorInformation, ColorPresentation, FoldingRange, FoldingRangeKind, MarkupKind, SelectionRange } from './_deps/vscode-languageserver-types/main.js';
export { Range, TextEdit, Color, ColorInformation, ColorPresentation, FoldingRange, FoldingRangeKind, SelectionRange };
/**
 * Error codes used by diagnostics
 */
export var ErrorCode;
(function (ErrorCode) {
    ErrorCode[ErrorCode["Undefined"] = 0] = "Undefined";
    ErrorCode[ErrorCode["EnumValueMismatch"] = 1] = "EnumValueMismatch";
    ErrorCode[ErrorCode["UnexpectedEndOfComment"] = 257] = "UnexpectedEndOfComment";
    ErrorCode[ErrorCode["UnexpectedEndOfString"] = 258] = "UnexpectedEndOfString";
    ErrorCode[ErrorCode["UnexpectedEndOfNumber"] = 259] = "UnexpectedEndOfNumber";
    ErrorCode[ErrorCode["InvalidUnicode"] = 260] = "InvalidUnicode";
    ErrorCode[ErrorCode["InvalidEscapeCharacter"] = 261] = "InvalidEscapeCharacter";
    ErrorCode[ErrorCode["InvalidCharacter"] = 262] = "InvalidCharacter";
    ErrorCode[ErrorCode["PropertyExpected"] = 513] = "PropertyExpected";
    ErrorCode[ErrorCode["CommaExpected"] = 514] = "CommaExpected";
    ErrorCode[ErrorCode["ColonExpected"] = 515] = "ColonExpected";
    ErrorCode[ErrorCode["ValueExpected"] = 516] = "ValueExpected";
    ErrorCode[ErrorCode["CommaOrCloseBacketExpected"] = 517] = "CommaOrCloseBacketExpected";
    ErrorCode[ErrorCode["CommaOrCloseBraceExpected"] = 518] = "CommaOrCloseBraceExpected";
    ErrorCode[ErrorCode["TrailingComma"] = 519] = "TrailingComma";
    ErrorCode[ErrorCode["DuplicateKey"] = 520] = "DuplicateKey";
    ErrorCode[ErrorCode["CommentNotPermitted"] = 521] = "CommentNotPermitted";
    ErrorCode[ErrorCode["SchemaResolveError"] = 768] = "SchemaResolveError";
})(ErrorCode || (ErrorCode = {}));
export var ClientCapabilities;
(function (ClientCapabilities) {
    ClientCapabilities.LATEST = {
        textDocument: {
            completion: {
                completionItem: {
                    documentationFormat: [MarkupKind.Markdown, MarkupKind.PlainText]
                }
            }
        }
    };
})(ClientCapabilities || (ClientCapabilities = {}));
