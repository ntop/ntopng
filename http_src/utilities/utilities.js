import { datatableInitRefreshRows, datatableForEachRow, datatableIsEmpty, datatableRemoveEmptyRow, datatableAddEmptyRow, datatableGetNumDisplayedItems, datatableGetByForm, datatableUndoAddRow, datatableAddButtonCallback, datatableAddDeleteButtonCallback, datatableAddActionButtonCallback, datatableAddFilterButtonCallback, datatableAddLinkButtonCallback, datatableMakeSelectUnique, datatableIsLastPage, datatableGetColumn, datatableGetColumnIndex } from './datatable/bootstrap-datatable-utils'

window.datatableInitRefreshRows = datatableInitRefreshRows
window.datatableForEachRow = datatableForEachRow
window.datatableIsEmpty = datatableIsEmpty
window.datatableRemoveEmptyRow = datatableRemoveEmptyRow
window.datatableAddEmptyRow = datatableAddEmptyRow
window.datatableGetNumDisplayedItems = datatableGetNumDisplayedItems
window.datatableGetByForm = datatableGetByForm
window.datatableUndoAddRow = datatableUndoAddRow
window.datatableAddButtonCallback = datatableAddButtonCallback
window.datatableAddDeleteButtonCallback = datatableAddDeleteButtonCallback
window.datatableAddActionButtonCallback = datatableAddActionButtonCallback
window.datatableAddFilterButtonCallback = datatableAddFilterButtonCallback
window.datatableAddLinkButtonCallback = datatableAddLinkButtonCallback
window.datatableMakeSelectUnique = datatableMakeSelectUnique
window.datatableIsLastPage = datatableIsLastPage
window.datatableGetColumn = datatableGetColumn
window.datatableGetColumnIndex = datatableGetColumnIndex

import './ebpf-utils'
import './graph/graph-utils'
import modalHandler from './modal/modal-utils'

window.$.fn.modalHandler = modalHandler


/* Must add it here otherwise a package error is going to be release */
import 'jquery.are-you-sure'
import { aysGetDirty, aysHandleForm, aysResetForm, aysUpdateForm, aysRecheckForm } from './are-you-sure-utils'

window.aysGetDirty = aysGetDirty
window.aysHandleForm = aysHandleForm
window.aysResetForm = aysResetForm
window.aysUpdateForm = aysUpdateForm
window.aysRecheckForm = aysRecheckForm

import './sequence_sunburst'
import * as ebpfUtils from './ebpf-utils'

window.ebpfUtils = ebpfUtils
