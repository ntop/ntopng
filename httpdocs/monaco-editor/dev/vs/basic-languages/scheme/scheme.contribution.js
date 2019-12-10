define(["require", "exports", "../_.contribution"], function (require, exports, __contribution_1) {
    /*---------------------------------------------------------------------------------------------
     *  Copyright (c) Microsoft Corporation. All rights reserved.
     *  Licensed under the MIT License. See License.txt in the project root for license information.
     *--------------------------------------------------------------------------------------------*/
    'use strict';
    Object.defineProperty(exports, "__esModule", { value: true });
    __contribution_1.registerLanguage({
        id: 'scheme',
        extensions: ['.scm', '.ss', '.sch', '.rkt'],
        aliases: ['scheme', 'Scheme'],
        loader: function () { return new Promise(function (resolve_1, reject_1) { require(['./scheme'], resolve_1, reject_1); }); },
    });
});
