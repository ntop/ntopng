/**
 * jquery-resizable-columns - Resizable table columns for jQuery
 * @date Wed Apr 13 2022 15:41:44 GMT+0800 (中国标准时间)
 * @version v0.2.3
 * @link http://dobtco.github.io/jquery-resizable-columns/
 * @license MIT
 */
(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
'use strict';

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

var _class = require('./class');

var _class2 = _interopRequireDefault(_class);

var _constants = require('./constants');

$.fn.resizableColumns = function (optionsOrMethod) {
	for (var _len = arguments.length, args = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
		args[_key - 1] = arguments[_key];
	}

	return this.each(function () {
		var $table = $(this);

		var api = $table.data(_constants.DATA_API);
		if (!api) {
			api = new _class2['default']($table, optionsOrMethod);
			$table.data(_constants.DATA_API, api);
		} else if (typeof optionsOrMethod === 'string') {
			var _api;

			return (_api = api)[optionsOrMethod].apply(_api, args);
		}
	});
};

$.resizableColumns = _class2['default'];

},{"./class":2,"./constants":3}],2:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
	value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

var _constants = require('./constants');

/**
Takes a <table /> element and makes it's columns resizable across both
mobile and desktop clients.

@class ResizableColumns
@param $table {jQuery} jQuery-wrapped <table> element to make resizable
@param options {Object} Configuration object
**/

var ResizableColumns = (function () {
	function ResizableColumns($table, options) {
		_classCallCheck(this, ResizableColumns);

		this.ns = '.rc' + this.count++;
		this.originalTableLayout = $table.css('table-layout');
		this.options = $.extend({}, ResizableColumns.defaults, options);

		this.$window = $(window);
		this.$ownerDocument = $($table[0].ownerDocument);
		this.$table = $table;

		this.refreshHeaders();
		this.restoreColumnWidths();
		this.syncHandleWidths();

		this.bindEvents(this.$window, 'resize', this.syncHandleWidths.bind(this));

		if (this.options.start) {
			this.bindEvents(this.$table, _constants.EVENT_RESIZE_START, this.options.start);
		}
		if (this.options.resize) {
			this.bindEvents(this.$table, _constants.EVENT_RESIZE, this.options.resize);
		}
		if (this.options.stop) {
			this.bindEvents(this.$table, _constants.EVENT_RESIZE_STOP, this.options.stop);
		}
	}

	/**
 Refreshes the headers associated with this instances <table/> element and
 generates handles for them. Also assigns percentage widths.
 	@method refreshHeaders
 **/

	_createClass(ResizableColumns, [{
		key: 'refreshHeaders',
		value: function refreshHeaders() {
			// Allow the selector to be both a regular selctor string as well as
			// a dynamic callback
			var selector = this.options.selector;
			if (typeof selector === 'function') {
				selector = selector.call(this, this.$table);
			}

			// Select all table headers
			this.$tableHeaders = this.$table.find(selector);

			// Assign percentage widths first, then create drag handles
			this.assignPercentageWidths();
			this.createHandles();

			//fixed table
			this.$table.css("table-layout", "fixed");
		}

		/**
  Creates dummy handle elements for all table header columns
  	@method createHandles
  **/
	}, {
		key: 'createHandles',
		value: function createHandles() {
			var _this = this;

			var ref = this.$handleContainer;
			if (ref != null) {
				ref.remove();
			}

			this.$handleContainer = $('<div class=\'' + _constants.CLASS_HANDLE_CONTAINER + '\' />');
			this.options.handleContainer ? this.options.handleContainer.before(this.$handleContainer) : this.$table.before(this.$handleContainer);

			this.$tableHeaders.each(function (i, el) {
				var $current = _this.$tableHeaders.eq(i);
				var $next = _this.$tableHeaders.eq(i + 1);

				if ($next.length === 0 || $current.is(_constants.SELECTOR_UNRESIZABLE) || $next.is(_constants.SELECTOR_UNRESIZABLE)) {
					return;
				}

				var $handle = $('<div class=\'' + _constants.CLASS_HANDLE + '\' />').data(_constants.DATA_TH, $(el)).appendTo(_this.$handleContainer);
			});

			this.bindEvents(this.$handleContainer, ['mousedown', 'touchstart'], '.' + _constants.CLASS_HANDLE, this.onPointerDown.bind(this));
		}

		/**
  Assigns a percentage width to all columns based on their current pixel width(s)
  	@method assignPercentageWidths
  **/
	}, {
		key: 'assignPercentageWidths',
		value: function assignPercentageWidths() {
			var _this2 = this;

			this.$tableHeaders.each(function (_, el) {
				var $el = $(el);
				_this2.setWidth($el[0], $el.outerWidth() + _this2.options.padding);
			});
		}

		/**
  
  @method syncHandleWidths
  **/
	}, {
		key: 'syncHandleWidths',
		value: function syncHandleWidths() {
			var _this3 = this;

			var $container = this.$handleContainer;

			$container.width(this.$table.width());

			$container.find('.' + _constants.CLASS_HANDLE).each(function (_, el) {
				var $el = $(el);

				var height = _this3.options.resizeFromBody ? _this3.$table.height() : _this3.$table.find('thead').height();

				var left = $el.data(_constants.DATA_TH).outerWidth() + ($el.data(_constants.DATA_TH).offset().left - _this3.$handleContainer.offset().left);

				$el.css({ left: left, height: height });
			});
		}

		/**
  Persists the column widths in localStorage
  	@method saveColumnWidths
  **/
	}, {
		key: 'saveColumnWidths',
		value: function saveColumnWidths() {
			var _this4 = this;

			this.$tableHeaders.each(function (_, el) {
				var $el = $(el);

				if (_this4.options.store && !$el.is(_constants.SELECTOR_UNRESIZABLE)) {
					_this4.options.store.set(_this4.generateColumnId($el), _this4.parseWidth(el));
				}
			});
		}

		/**
  Retrieves and sets the column widths from localStorage
  	@method restoreColumnWidths
  **/
	}, {
		key: 'restoreColumnWidths',
		value: function restoreColumnWidths() {
			var _this5 = this;

			this.$tableHeaders.each(function (_, el) {
				var $el = $(el);

				if (_this5.options.store && !$el.is(_constants.SELECTOR_UNRESIZABLE)) {
					var width = _this5.options.store.get(_this5.generateColumnId($el));

					if (width != null) {
						_this5.setWidth(el, width);
					}
				}
			});
		}

		/**
  Pointer/mouse down handler
  	@method onPointerDown
  @param event {Object} Event object associated with the interaction
  **/
	}, {
		key: 'onPointerDown',
		value: function onPointerDown(event) {
			// Only applies to left-click dragging
			if (event.which !== 1) {
				return;
			}

			// If a previous operation is defined, we missed the last mouseup.
			// Probably gobbled up by user mousing out the window then releasing.
			// We'll simulate a pointerup here prior to it
			if (this.operation) {
				this.onPointerUp(event);
			}

			// Ignore non-resizable columns
			var $currentGrip = $(event.currentTarget);
			if ($currentGrip.is(_constants.SELECTOR_UNRESIZABLE)) {
				return;
			}

			var gripIndex = $currentGrip.index();
			var $leftColumn = this.$tableHeaders.eq(gripIndex).not(_constants.SELECTOR_UNRESIZABLE);
			var $rightColumn = this.$tableHeaders.eq(gripIndex + 1).not(_constants.SELECTOR_UNRESIZABLE);

			var leftWidth = this.parseWidth($leftColumn[0]);
			var rightWidth = this.parseWidth($rightColumn[0]);

			this.operation = {
				$leftColumn: $leftColumn, $rightColumn: $rightColumn, $currentGrip: $currentGrip,

				startX: this.getPointerX(event),

				widths: {
					left: leftWidth,
					right: rightWidth
				},
				newWidths: {
					left: leftWidth,
					right: rightWidth
				}
			};

			this.bindEvents(this.$ownerDocument, ['mousemove', 'touchmove'], this.onPointerMove.bind(this));
			this.bindEvents(this.$ownerDocument, ['mouseup', 'touchend'], this.onPointerUp.bind(this));

			this.$handleContainer.add(this.$table).addClass(_constants.CLASS_TABLE_RESIZING);

			$leftColumn.add($rightColumn).add($currentGrip).addClass(_constants.CLASS_COLUMN_RESIZING);

			this.triggerEvent(_constants.EVENT_RESIZE_START, [$leftColumn, $rightColumn, leftWidth, rightWidth], event);

			event.preventDefault();
		}

		/**
  Pointer/mouse movement handler
  	@method onPointerMove
  @param event {Object} Event object associated with the interaction
  **/
	}, {
		key: 'onPointerMove',
		value: function onPointerMove(event) {
			var op = this.operation;
			if (!this.operation) {
				return;
			}

			// Determine the delta change between start and new mouse position, as a percentage of the table width
			var difference = this.getPointerX(event) - op.startX;
			if (difference === 0) {
				return;
			}

			var leftColumn = op.$leftColumn[0];
			var rightColumn = op.$rightColumn[0];
			var widthLeft = undefined,
			    widthRight = undefined;

			widthLeft = this.constrainWidth(op.widths.left + difference);
			widthRight = this.constrainWidth(op.widths.right);

			if (leftColumn) {
				this.setWidth(leftColumn, widthLeft);
			}
			if (rightColumn) {
				this.setWidth(rightColumn, widthRight);
			}

			op.newWidths.left = widthLeft;
			op.newWidths.right = widthRight;

			return this.triggerEvent(_constants.EVENT_RESIZE, [op.$leftColumn, op.$rightColumn, widthLeft, widthRight], event);
		}

		/**
  Pointer/mouse release handler
  	@method onPointerUp
  @param event {Object} Event object associated with the interaction
  **/
	}, {
		key: 'onPointerUp',
		value: function onPointerUp(event) {
			var op = this.operation;
			if (!this.operation) {
				return;
			}

			this.unbindEvents(this.$ownerDocument, ['mouseup', 'touchend', 'mousemove', 'touchmove']);

			this.$handleContainer.add(this.$table).removeClass(_constants.CLASS_TABLE_RESIZING);

			op.$leftColumn.add(op.$rightColumn).add(op.$currentGrip).removeClass(_constants.CLASS_COLUMN_RESIZING);

			this.syncHandleWidths();
			this.saveColumnWidths();

			this.operation = null;

			return this.triggerEvent(_constants.EVENT_RESIZE_STOP, [op.$leftColumn, op.$rightColumn, op.newWidths.left, op.newWidths.right], event);
		}

		/**
  Removes all event listeners, data, and added DOM elements. Takes
  the <table/> element back to how it was, and returns it
  	@method destroy
  @return {jQuery} Original jQuery-wrapped <table> element
  **/
	}, {
		key: 'destroy',
		value: function destroy() {
			var $table = this.$table;
			var $handles = this.$handleContainer.find('.' + _constants.CLASS_HANDLE);

			this.unbindEvents(this.$window.add(this.$ownerDocument).add(this.$table).add($handles));

			$handles.removeData(_constants.DATA_TH);
			$table.removeData(_constants.DATA_API);

			this.$handleContainer.remove();
			this.$handleContainer = null;
			this.$tableHeaders = null;
			this.$table = null;

			return $table;
		}

		/**
  Binds given events for this instance to the given target DOMElement
  	@private
  @method bindEvents
  @param target {jQuery} jQuery-wrapped DOMElement to bind events to
  @param events {String|Array} Event name (or array of) to bind
  @param selectorOrCallback {String|Function} Selector string or callback
  @param [callback] {Function} Callback method
  **/
	}, {
		key: 'bindEvents',
		value: function bindEvents($target, events, selectorOrCallback, callback) {
			if (typeof events === 'string') {
				events = events + this.ns;
			} else {
				events = events.join(this.ns + ' ') + this.ns;
			}

			if (arguments.length > 3) {
				$target.on(events, selectorOrCallback, callback);
			} else {
				$target.on(events, selectorOrCallback);
			}
		}

		/**
  Unbinds events specific to this instance from the given target DOMElement
  	@private
  @method unbindEvents
  @param target {jQuery} jQuery-wrapped DOMElement to unbind events from
  @param events {String|Array} Event name (or array of) to unbind
  **/
	}, {
		key: 'unbindEvents',
		value: function unbindEvents($target, events) {
			if (typeof events === 'string') {
				events = events + this.ns;
			} else if (events != null) {
				events = events.join(this.ns + ' ') + this.ns;
			} else {
				events = this.ns;
			}

			$target.off(events);
		}

		/**
  Triggers an event on the <table/> element for a given type with given
  arguments, also setting and allowing access to the originalEvent if
  given. Returns the result of the triggered event.
  	@private
  @method triggerEvent
  @param type {String} Event name
  @param args {Array} Array of arguments to pass through
  @param [originalEvent] If given, is set on the event object
  @return {Mixed} Result of the event trigger action
  **/
	}, {
		key: 'triggerEvent',
		value: function triggerEvent(type, args, originalEvent) {
			var event = $.Event(type);
			if (event.originalEvent) {
				event.originalEvent = $.extend({}, originalEvent);
			}

			return this.$table.trigger(event, [this].concat(args || []));
		}

		/**
  Calculates a unique column ID for a given column DOMElement
  	@private
  @method generateColumnId
  @param $el {jQuery} jQuery-wrapped column element
  @return {String} Column ID
  **/
	}, {
		key: 'generateColumnId',
		value: function generateColumnId($el) {
			return this.$table.data(_constants.DATA_COLUMNS_ID) + '-' + $el.data(_constants.DATA_COLUMN_ID);
		}

		/**
  Parses a given DOMElement's width into a float
  	@private
  @method parseWidth
  @param element {DOMElement} Element to get width of
  @return {Number} Element's width as a float
  **/
	}, {
		key: 'parseWidth',
		value: function parseWidth(element) {
			return element ? parseFloat(element.style.width) : 0;
		}

		/**
  Sets the percentage width of a given DOMElement
  	@private
  @method setWidth
  @param element {DOMElement} Element to set width on
  @param width {Number} Width, as a percentage, to set
  **/
	}, {
		key: 'setWidth',
		value: function setWidth(element, width) {
			width = width.toFixed(2);
			width = width > 0 ? width : 0;
			$(element).width(width);
		}

		/**
  Constrains a given width to the minimum and maximum ranges defined in
  the `minWidth` and `maxWidth` configuration options, respectively.
  	@private
  @method constrainWidth
  @param width {Number} Width to constrain
  @return {Number} Constrained width
  **/
	}, {
		key: 'constrainWidth',
		value: function constrainWidth(width) {
			if (this.options.minWidth != undefined) {
				width = Math.max(this.options.minWidth, width);
			}

			if (this.options.maxWidth != undefined) {
				width = Math.min(this.options.maxWidth, width);
			}

			return width;
		}

		/**
  Given a particular Event object, retrieves the current pointer offset along
  the horizontal direction. Accounts for both regular mouse clicks as well as
  pointer-like systems (mobiles, tablets etc.)
  	@private
  @method getPointerX
  @param event {Object} Event object associated with the interaction
  @return {Number} Horizontal pointer offset
  **/
	}, {
		key: 'getPointerX',
		value: function getPointerX(event) {
			if (event.type.indexOf('touch') === 0) {
				return (event.originalEvent.touches[0] || event.originalEvent.changedTouches[0]).pageX;
			}
			return event.pageX;
		}
	}]);

	return ResizableColumns;
})();

exports['default'] = ResizableColumns;

ResizableColumns.defaults = {
	selector: function selector($table) {
		if ($table.find('thead').length) {
			return _constants.SELECTOR_TH;
		}

		return _constants.SELECTOR_TD;
	},
	//jquery element of the handleContainer position,handleContainer will before the element, default will be this table
	handleContainer: null,
	padding: 0,
	store: window.store,
	syncHandlers: true,
	resizeFromBody: true,
	maxWidth: null,
	minWidth: 0.01
};

ResizableColumns.count = 0;
module.exports = exports['default'];

},{"./constants":3}],3:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});
var DATA_API = 'resizableColumns';
exports.DATA_API = DATA_API;
var DATA_COLUMNS_ID = 'resizable-columns-id';
exports.DATA_COLUMNS_ID = DATA_COLUMNS_ID;
var DATA_COLUMN_ID = 'resizable-column-id';
exports.DATA_COLUMN_ID = DATA_COLUMN_ID;
var DATA_TH = 'th';

exports.DATA_TH = DATA_TH;
var CLASS_TABLE_RESIZING = 'rc-table-resizing';
exports.CLASS_TABLE_RESIZING = CLASS_TABLE_RESIZING;
var CLASS_COLUMN_RESIZING = 'rc-column-resizing';
exports.CLASS_COLUMN_RESIZING = CLASS_COLUMN_RESIZING;
var CLASS_HANDLE = 'rc-handle';
exports.CLASS_HANDLE = CLASS_HANDLE;
var CLASS_HANDLE_CONTAINER = 'rc-handle-container';

exports.CLASS_HANDLE_CONTAINER = CLASS_HANDLE_CONTAINER;
var EVENT_RESIZE_START = 'column:resize:start';
exports.EVENT_RESIZE_START = EVENT_RESIZE_START;
var EVENT_RESIZE = 'column:resize';
exports.EVENT_RESIZE = EVENT_RESIZE;
var EVENT_RESIZE_STOP = 'column:resize:stop';

exports.EVENT_RESIZE_STOP = EVENT_RESIZE_STOP;
var SELECTOR_TH = 'tr:first > th:visible';
exports.SELECTOR_TH = SELECTOR_TH;
var SELECTOR_TD = 'tr:first > td:visible';
exports.SELECTOR_TD = SELECTOR_TD;
var SELECTOR_UNRESIZABLE = '[data-noresize]';
exports.SELECTOR_UNRESIZABLE = SELECTOR_UNRESIZABLE;

},{}],4:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

var _class = require('./class');

var _class2 = _interopRequireDefault(_class);

var _adapter = require('./adapter');

var _adapter2 = _interopRequireDefault(_adapter);

exports['default'] = _class2['default'];
module.exports = exports['default'];

},{"./adapter":1,"./class":2}]},{},[4])

//# sourceMappingURL=data:application/json;charset=utf8;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIm5vZGVfbW9kdWxlcy9icm93c2VyLXBhY2svX3ByZWx1ZGUuanMiLCJzcmMvYWRhcHRlci5qcyIsInNyYy9jbGFzcy5qcyIsInNyYy9jb25zdGFudHMuanMiLCJzcmMvaW5kZXguanMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUE7Ozs7O3FCQ0E2QixTQUFTOzs7O3lCQUNmLGFBQWE7O0FBRXBDLENBQUMsQ0FBQyxFQUFFLENBQUMsZ0JBQWdCLEdBQUcsVUFBUyxlQUFlLEVBQVc7bUNBQU4sSUFBSTtBQUFKLE1BQUk7OztBQUN4RCxRQUFPLElBQUksQ0FBQyxJQUFJLENBQUMsWUFBVztBQUMzQixNQUFJLE1BQU0sR0FBRyxDQUFDLENBQUMsSUFBSSxDQUFDLENBQUM7O0FBRXJCLE1BQUksR0FBRyxHQUFHLE1BQU0sQ0FBQyxJQUFJLHFCQUFVLENBQUM7QUFDaEMsTUFBSSxDQUFDLEdBQUcsRUFBRTtBQUNULE1BQUcsR0FBRyx1QkFBcUIsTUFBTSxFQUFFLGVBQWUsQ0FBQyxDQUFDO0FBQ3BELFNBQU0sQ0FBQyxJQUFJLHNCQUFXLEdBQUcsQ0FBQyxDQUFDO0dBQzNCLE1BRUksSUFBSSxPQUFPLGVBQWUsS0FBSyxRQUFRLEVBQUU7OztBQUM3QyxVQUFPLFFBQUEsR0FBRyxFQUFDLGVBQWUsT0FBQyxPQUFJLElBQUksQ0FBQyxDQUFDO0dBQ3JDO0VBQ0QsQ0FBQyxDQUFDO0NBQ0gsQ0FBQzs7QUFFRixDQUFDLENBQUMsZ0JBQWdCLHFCQUFtQixDQUFDOzs7Ozs7Ozs7Ozs7O3lCQ0hqQyxhQUFhOzs7Ozs7Ozs7OztJQVVHLGdCQUFnQjtBQUN6QixVQURTLGdCQUFnQixDQUN4QixNQUFNLEVBQUUsT0FBTyxFQUFFO3dCQURULGdCQUFnQjs7QUFFbkMsTUFBSSxDQUFDLEVBQUUsR0FBRyxLQUFLLEdBQUcsSUFBSSxDQUFDLEtBQUssRUFBRSxDQUFDO0FBQy9CLE1BQUksQ0FBQyxtQkFBbUIsR0FBRyxNQUFNLENBQUMsR0FBRyxDQUFDLGNBQWMsQ0FBQyxD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QUFFLElBQUk7QUFDcEIsU0FBUSxFQUFFLElBQUk7QUFDZCxTQUFRLEVBQUUsSUFBSTtDQUNkLENBQUM7O0FBRUYsZ0JBQWdCLENBQUMsS0FBSyxHQUFHLENBQUMsQ0FBQzs7Ozs7Ozs7O0FDcGdCcEIsSUFBTSxRQUFRLEdBQUcsa0JBQWtCLENBQUM7O0FBQ3BDLElBQU0sZUFBZSxHQUFHLHNCQUFzQixDQUFDOztBQUMvQyxJQUFNLGNBQWMsR0FBRyxxQkFBcUIsQ0FBQzs7QUFDN0MsSUFBTSxPQUFPLEdBQUcsSUFBSSxDQUFDOzs7QUFFckIsSUFBTSxvQkFBb0IsR0FBRyxtQkFBbUIsQ0FBQzs7QUFDakQsSUFBTSxxQkFBcUIsR0FBRyxvQkFBb0IsQ0FBQzs7QUFDbkQsSUFBTSxZQUFZLEdBQUcsV0FBVyxDQUFDOztBQUNqQyxJQUFNLHNCQUFzQixHQUFHLHFCQUFxQixDQUFDOzs7QUFFckQsSUFBTSxrQkFBa0IsR0FBRyxxQkFBcUIsQ0FBQzs7QUFDakQsSUFBTSxZQUFZLEdBQUcsZUFBZSxDQUFDOztBQUNyQyxJQUFNLGlCQUFpQixHQUFHLG9CQUFvQixDQUFDOzs7QUFFL0MsSUFBTSxXQUFXLEdBQUcsdUJBQXVCLENBQUM7O0FBQzVDLElBQU0sV0FBVyxHQUFHLHVCQUF1QixDQUFDOztBQUM1QyxJQUFNLG9CQUFvQixvQkFBb0IsQ0FBQzs7Ozs7Ozs7Ozs7O3FCQ2hCekIsU0FBUzs7Ozt1QkFDbEIsV0FBVyIsImZpbGUiOiJqcXVlcnkucmVzaXphYmxlQ29sdW1ucy5qcyIsInNvdXJjZXNDb250ZW50IjpbIihmdW5jdGlvbiBlKHQsbixyKXtmdW5jdGlvbiBzKG8sdSl7aWYoIW5bb10pe2lmKCF0W29dKXt2YXIgYT10eXBlb2YgcmVxdWlyZT09XCJmdW5jdGlvblwiJiZyZXF1aXJlO2lmKCF1JiZhKXJldHVybiBhKG8sITApO2lmKGkpcmV0dXJuIGkobywhMCk7dmFyIGY9bmV3IEVycm9yKFwiQ2Fubm90IGZpbmQgbW9kdWxlICdcIitvK1wiJ1wiKTt0aHJvdyBmLmNvZGU9XCJNT0RVTEVfTk9UX0ZPVU5EXCIsZn12YXIgbD1uW29dPXtleHBvcnRzOnt9fTt0W29dWzBdLmNhbGwobC5leHBvcnRzLGZ1bmN0aW9uKGUpe3ZhciBuPXRbb11bMV1bZV07cmV0dXJuIHMobj9uOmUpfSxsLGwuZXhwb3J0cyxlLHQsbixyKX1yZXR1cm4gbltvXS5leHBvcnRzfXZhciBpPXR5cGVvZiByZXF1aXJlPT1cImZ1bmN0aW9uXCImJnJlcXVpcmU7Zm9yKHZhciBvPTA7bzxyLmxlbmd0aDtvKyspcyhyW29dKTtyZXR1cm4gc30pIiwiaW1wb3J0IFJlc2l6YWJsZUNvbHVtbnMgZnJvbSAnLi9jbGFzcyc7XG5pbXBvcnQge0RBVEFfQVBJfSBmcm9tICcuL2NvbnN0YW50cyc7XG5cbiQuZm4ucmVzaXphYmxlQ29sdW1ucyA9IGZ1bmN0aW9uKG9wdGlvbnNPck1ldGhvZCwgLi4uYXJncykge1xuXHRyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9uKCkge1xuXHRcdGxldCAkdGFibGUgPSAkKHRoaXMpO1xuXG5cdFx0bGV0IGFwaSA9ICR0YWJsZS5kYXRhKERBVEFfQVBJKTtcblx0XHRpZiAoIWFwaSkge1xuXHRcdFx0YXBpID0gbmV3IFJlc2l6YWJsZUNvbHVtbnMoJHRhYmxlLCBvcHRpb25zT3JNZXRob2QpO1xuXHRcdFx0JHRhYmxlLmRhdGEoREFUQV9BUEksIGFwaSk7XG5cdFx0fVxuXG5cdFx0ZWxzZSBpZiAodHlwZW9mIG9wdGlvbnNPck1ldGhvZCA9PT0gJ3N0cmluZycpIHtcblx0XHRcdHJldHVybiBhcGlbb3B0aW9uc09yTWV0aG9kXSguLi5hcmdzKTtcblx0XHR9XG5cdH0pO1xufTtcblxuJC5yZXNpemFibGVDb2x1bW5zID0gUmVzaXphYmxlQ29sdW1ucztcbiIsImltcG9ydCB7XG5cdERBVEFfQVBJLFxuXHREQVRBX0NPTFVNTlNfSUQsXG5cdERBVEFfQ09MVU1OX0lELFxuXHREQVRBX1RILFxuXHRDTEFTU19UQUJMRV9SRVNJWklORyxcblx0Q0xBU1NfQ09MVU1OX1JFU0laSU5HLFxuXHRDTEFTU19IQU5ETEUsXG5cdENMQVNTX0hBTkRMRV9DT05UQUlORVIsXG5cdEVWRU5UX1JFU0laRV9TVEFSVCxcblx0RVZFTlRfUkVTSVpFLFxuXHRFVkVOVF9SRVNJWkVfU1RPUCxcblx0U0VMRUNUT1JfVEgsXG5cdFNFTEVDVE9SX1RELFxuXHRTRUxFQ1RPUl9VTlJFU0laQUJMRVxufVxuZnJvbSAnLi9jb25zdGFudHMnO1xuXG4vKipcblRha2VzIGEgPHRhYmxlIC8+IGVsZW1lbnQgYW5kIG1ha2VzIGl0J3MgY29sdW1ucyByZXNpemFibGUgYWNyb3NzIGJvdGhcbm1vYmlsZSBhbmQgZGVza3RvcCBjbGllbnRzLlxuXG5AY2xhc3MgUmVzaXphYmxlQ29sdW1uc1xuQHBhcmFtICR0YWJsZSB7alF1ZXJ5fSBqUXVlcnktd3JhcHBlZCA8dGFibGU+IGVsZW1lbnQgdG8gbWFrZSByZXNpemFibGVcbkBwYXJhbSBvcHRpb25zIHtPYmplY3R9IENvbmZpZ3VyYXRpb24gb2JqZWN0XG4qKi9cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFJlc2l6YWJsZUNvbHVtbnMge1xuXHRjb25zdHJ1Y3RvcigkdGFibGUsIG9wdGlvbnMpIHtcblx0XHR0aGlzLm5zID0gJy5yYycgKyB0aGlzLmNvdW50Kys7XG5cdFx0dGhpcy5vcmlnaW5hbFRhYmxlTGF5b3V0ID0gJHRhYmxlLmNzcygndGFibGUtbGF5b3V0Jylcblx0XHR0aGlzLm9wdGlvbnMgPSAkLmV4dGVuZCh7fSwgUmVzaXphYmxlQ29sdW1ucy5kZWZhdWx0cywgb3B0aW9ucyk7XG5cblx0XHR0aGlzLiR3aW5kb3cgPSAkKHdpbmRvdyk7XG5cdFx0dGhpcy4kb3duZXJEb2N1bWVudCA9ICQoJHRhYmxlWzBdLm93bmVyRG9jdW1lbnQpO1xuXHRcdHRoaXMuJHRhYmxlID0gJHRhYmxlO1xuXG5cdFx0dGhpcy5yZWZyZXNoSGVhZGVycygpO1xuXHRcdHRoaXMucmVzdG9yZUNvbHVtbldpZHRocygpO1xuXHRcdHRoaXMuc3luY0hhbmRsZVdpZHRocygpO1xuXG5cdFx0dGhpcy5iaW5kRXZlbnRzKHRoaXMuJHdpbmRvdywgJ3Jlc2l6ZScsIHRoaXMuc3luY0hhbmRsZVdpZHRocy5iaW5kKHRoaXMpKTtcblxuXHRcdGlmICh0aGlzLm9wdGlvbnMuc3RhcnQpIHtcblx0XHRcdHRoaXMuYmluZEV2ZW50cyh0aGlzLiR0YWJsZSwgRVZFTlRfUkVTSVpFX1NUQVJULCB0aGlzLm9wdGlvbnMuc3RhcnQpO1xuXHRcdH1cblx0XHRpZiAodGhpcy5vcHRpb25zLnJlc2l6ZSkge1xuXHRcdFx0dGhpcy5iaW5kRXZlbnRzKHRoaXMuJHRhYmxlLCBFVkVOVF9SRVNJWkUsIHRoaXMub3B0aW9ucy5yZXNpemUpO1xuXHRcdH1cblx0XHRpZiAodGhpcy5vcHRpb25zLnN0b3ApIHtcblx0XHRcdHRoaXMuYmluZEV2ZW50cyh0aGlzLiR0YWJsZSwgRVZFTlRfUkVTSVpFX1NUT1AsIHRoaXMub3B0aW9ucy5zdG9wKTtcblx0XHR9XG5cdH1cblxuXHQvKipcblx0UmVmcmVzaGVzIHRoZSBoZWFkZXJzIGFzc29jaWF0ZWQgd2l0aCB0aGlzIGluc3RhbmNlcyA8dGFibGUvPiBlbGVtZW50IGFuZFxuXHRnZW5lcmF0ZXMgaGFuZGxlcyBmb3IgdGhlbS4gQWxzbyBhc3NpZ25zIHBlcmNlbnRhZ2Ugd2lkdGhzLlxuXG5cdEBtZXRob2QgcmVmcmVzaEhlYWRlcnNcblx0KiovXG5cdHJlZnJlc2hIZWFkZXJzKCkge1xuXHRcdC8vIEFsbG93IHRoZSBzZWxlY3RvciB0byBiZSBib3RoIGEgcmVndWxhciBzZWxjdG9yIHN0cmluZyBhcyB3ZWxsIGFzXG5cdFx0Ly8gYSBkeW5hbWljIGNhbGxiYWNrXG5cdFx0bGV0IHNlbGVjdG9yID0gdGhpcy5vcHRpb25zLnNlbGVjdG9yO1xuXHRcdGlmKHR5cGVvZiBzZWxlY3RvciA9PT0gJ2Z1bmN0aW9uJykge1xuXHRcdFx0c2VsZWN0b3IgPSBzZWxlY3Rvci5jYWxsKHRoaXMsIHRoaXMuJHRhYmxlKTtcblx0XHR9XG5cblx0XHQvLyBTZWxlY3QgYWxsIHRhYmxlIGhlYWRlcnNcblx0XHR0aGlzLiR0YWJsZUhlYWRlcnMgPSB0aGlzLiR0YWJsZS5maW5kKHNlbGVjdG9yKTtcblxuXHRcdC8vIEFzc2lnbiBwZXJjZW50YWdlIHdpZHRocyBmaXJzdCwgdGhlbiBjcmVhdGUgZHJhZyBoYW5kbGVzXG5cdFx0dGhpcy5hc3NpZ25QZXJjZW50YWdlV2lkdGhzKCk7XG5cdFx0dGhpcy5jcmVhdGVIYW5kbGVzKCk7XG5cblx0XHQvL2ZpeGVkIHRhYmxlXG5cdFx0dGhpcy4kdGFibGUuY3NzKFwidGFibGUtbGF5b3V0XCIsXCJmaXhlZFwiKVxuXHR9XG5cblx0LyoqXG5cdENyZWF0ZXMgZHVtbXkgaGFuZGxlIGVsZW1lbnRzIGZvciBhbGwgdGFibGUgaGVhZGVyIGNvbHVtbnNcblxuXHRAbWV0aG9kIGNyZWF0ZUhhbmRsZXNcblx0KiovXG5cdGNyZWF0ZUhhbmRsZXMoKSB7XG5cdFx0bGV0IHJlZiA9IHRoaXMuJGhhbmRsZUNvbnRhaW5lcjtcblx0XHRpZiAocmVmICE9IG51bGwpIHtcblx0XHRcdHJlZi5yZW1vdmUoKTtcblx0XHR9XG5cblx0XHR0aGlzLiRoYW5kbGVDb250YWluZXIgPSAkKGA8ZGl2IGNsYXNzPScke0NMQVNTX0hBTkRMRV9DT05UQUlORVJ9JyAvPmApXG5cdFx0dGhpcy5vcHRpb25zLmhhbmRsZUNvbnRhaW5lciA/IHRoaXMub3B0aW9ucy5oYW5kbGVDb250YWluZXIuYmVmb3JlKHRoaXMuJGhhbmRsZUNvbnRhaW5lcikgOiB0aGlzLiR0YWJsZS5iZWZvcmUodGhpcy4kaGFuZGxlQ29udGFpbmVyKTtcblxuXHRcdHRoaXMuJHRhYmxlSGVhZGVycy5lYWNoKChpLCBlbCkgPT4ge1xuXHRcdFx0bGV0ICRjdXJyZW50ID0gdGhpcy4kdGFibGVIZWFkZXJzLmVxKGkpO1xuXHRcdFx0bGV0ICRuZXh0ID0gdGhpcy4kdGFibGVIZWFkZXJzLmVxKGkgKyAxKTtcblxuXHRcdFx0aWYgKCRuZXh0Lmxlbmd0aCA9PT0gMCB8fCAkY3VycmVudC5pcyhTRUxFQ1RPUl9VTlJFU0laQUJMRSkgfHwgJG5leHQuaXMoU0VMRUNUT1JfVU5SRVNJWkFCTEUpKSB7XG5cdFx0XHRcdHJldHVybjtcblx0XHRcdH1cblxuXHRcdFx0bGV0ICRoYW5kbGUgPSAkKGA8ZGl2IGNsYXNzPScke0NMQVNTX0hBTkRMRX0nIC8+YClcblx0XHRcdFx0LmRhdGEoREFUQV9USCwgJChlbCkpXG5cdFx0XHRcdC5hcHBlbmRUbyh0aGlzLiRoYW5kbGVDb250YWluZXIpO1xuXHRcdH0pO1xuXG5cdFx0dGhpcy5iaW5kRXZlbnRzKHRoaXMuJGhhbmRsZUNvbnRhaW5lciwgWydtb3VzZWRvd24nLCAndG91Y2hzdGFydCddLCAnLicrQ0xBU1NfSEFORExFLCB0aGlzLm9uUG9pbnRlckRvd24uYmluZCh0aGlzKSk7XG5cdH1cblxuXHQvKipcblx0QXNzaWducyBhIHBlcmNlbnRhZ2Ugd2lkdGggdG8gYWxsIGNvbHVtbnMgYmFzZWQgb24gdGhlaXIgY3VycmVudCBwaXhlbCB3aWR0aChzKVxuXG5cdEBtZXRob2QgYXNzaWduUGVyY2VudGFnZVdpZHRoc1xuXHQqKi9cblx0YXNzaWduUGVyY2VudGFnZVdpZHRocygpIHtcblx0XHR0aGlzLiR0YWJsZUhlYWRlcnMuZWFjaCgoXywgZWwpID0+IHtcblx0XHRcdGxldCAkZWwgPSAkKGVsKTtcblx0XHRcdHRoaXMuc2V0V2lkdGgoJGVsWzBdLCAkZWwub3V0ZXJXaWR0aCgpKyB0aGlzLm9wdGlvbnMucGFkZGluZyk7XG5cdFx0fSk7XG5cdH1cblxuXHQvKipcblxuXG5cdEBtZXRob2Qgc3luY0hhbmRsZVdpZHRoc1xuXHQqKi9cblx0c3luY0hhbmRsZVdpZHRocygpIHtcblx0XHRsZXQgJGNvbnRhaW5lciA9IHRoaXMuJGhhbmRsZUNvbnRhaW5lclxuXG5cdFx0JGNvbnRhaW5lci53aWR0aCh0aGlzLiR0YWJsZS53aWR0aCgpKTtcblxuXHRcdCRjb250YWluZXIuZmluZCgnLicrQ0xBU1NfSEFORExFKS5lYWNoKChfLCBlbCkgPT4ge1xuXHRcdFx0bGV0ICRlbCA9ICQoZWwpO1xuXG5cdFx0XHRsZXQgaGVpZ2h0ID0gdGhpcy5vcHRpb25zLnJlc2l6ZUZyb21Cb2R5ID9cblx0XHRcdFx0dGhpcy4kdGFibGUuaGVpZ2h0KCkgOlxuXHRcdFx0XHR0aGlzLiR0YWJsZS5maW5kKCd0aGVhZCcpLmhlaWdodCgpO1xuXG5cdFx0XHRsZXQgbGVmdCA9ICRlbC5kYXRhKERBVEFfVEgpLm91dGVyV2lkdGgoKSArIChcblx0XHRcdFx0JGVsLmRhdGEoREFUQV9USCkub2Zmc2V0KCkubGVmdCAtIHRoaXMuJGhhbmRsZUNvbnRhaW5lci5vZmZzZXQoKS5sZWZ0XG5cdFx0XHQpO1xuXG5cdFx0XHQkZWwuY3NzKHsgbGVmdCwgaGVpZ2h0IH0pO1xuXHRcdH0pO1xuXHR9XG5cblx0LyoqXG5cdFBlcnNpc3RzIHRoZSBjb2x1bW4gd2lkdGhzIGluIGxvY2FsU3RvcmFnZVxuXG5cdEBtZXRob2Qgc2F2ZUNvbHVtbldpZHRoc1xuXHQqKi9cblx0c2F2ZUNvbHVtbldpZHRocygpIHtcblx0XHR0aGlzLiR0YWJsZUhlYWRlcnMuZWFjaCgoXywgZWwpID0+IHtcblx0XHRcdGxldCAkZWwgPSAkKGVsKTtcblxuXHRcdFx0aWYgKHRoaXMub3B0aW9ucy5zdG9yZSAmJiAhJGVsLmlzKFNFTEVDVE9SX1VOUkVTSVpBQkxFKSkge1xuXHRcdFx0XHR0aGlzLm9wdGlvbnMuc3RvcmUuc2V0KFxuXHRcdFx0XHRcdHRoaXMuZ2VuZXJhdGVDb2x1bW5JZCgkZWwpLFxuXHRcdFx0XHRcdHRoaXMucGFyc2VXaWR0aChlbClcblx0XHRcdFx0KTtcblx0XHRcdH1cblx0XHR9KTtcblx0fVxuXG5cdC8qKlxuXHRSZXRyaWV2ZXMgYW5kIHNldHMgdGhlIGNvbHVtbiB3aWR0aHMgZnJvbSBsb2NhbFN0b3JhZ2VcblxuXHRAbWV0aG9kIHJlc3RvcmVDb2x1bW5XaWR0aHNcblx0KiovXG5cdHJlc3RvcmVDb2x1bW5XaWR0aHMoKSB7XG5cdFx0dGhpcy4kdGFibGVIZWFkZXJzLmVhY2goKF8sIGVsKSA9PiB7XG5cdFx0XHRsZXQgJGVsID0gJChlbCk7XG5cblx0XHRcdGlmKHRoaXMub3B0aW9ucy5zdG9yZSAmJiAhJGVsLmlzKFNFTEVDVE9SX1VOUkVTSVpBQkxFKSkge1xuXHRcdFx0XHRsZXQgd2lkdGggPSB0aGlzLm9wdGlvbnMuc3RvcmUuZ2V0KFxuXHRcdFx0XHRcdHRoaXMuZ2VuZXJhdGVDb2x1bW5JZCgkZWwpXG5cdFx0XHRcdCk7XG5cblx0XHRcdFx0aWYod2lkdGggIT0gbnVsbCkge1xuXHRcdFx0XHRcdHRoaXMuc2V0V2lkdGgoZWwsIHdpZHRoKTtcblx0XHRcdFx0fVxuXHRcdFx0fVxuXHRcdH0pO1xuXHR9XG5cblx0LyoqXG5cdFBvaW50ZXIvbW91c2UgZG93biBoYW5kbGVyXG5cblx0QG1ldGhvZCBvblBvaW50ZXJEb3duXG5cdEBwYXJhbSBldmVudCB7T2JqZWN0fSBFdmVudCBvYmplY3QgYXNzb2NpYXRlZCB3aXRoIHRoZSBpbnRlcmFjdGlvblxuXHQqKi9cblx0b25Qb2ludGVyRG93bihldmVudCkge1xuXHRcdC8vIE9ubHkgYXBwbGllcyB0byBsZWZ0LWNsaWNrIGRyYWdnaW5nXG5cdFx0aWYoZXZlbnQud2hpY2ggIT09IDEpIHsgcmV0dXJuOyB9XG5cblx0XHQvLyBJZiBhIHByZXZpb3VzIG9wZXJhdGlvbiBpcyBkZWZpbmVkLCB3ZSBtaXNzZWQgdGhlIGxhc3QgbW91c2V1cC5cblx0XHQvLyBQcm9iYWJseSBnb2JibGVkIHVwIGJ5IHVzZXIgbW91c2luZyBvdXQgdGhlIHdpbmRvdyB0aGVuIHJlbGVhc2luZy5cblx0XHQvLyBXZSdsbCBzaW11bGF0ZSBhIHBvaW50ZXJ1cCBoZXJlIHByaW9yIHRvIGl0XG5cdFx0aWYodGhpcy5vcGVyYXRpb24pIHtcblx0XHRcdHRoaXMub25Qb2ludGVyVXAoZXZlbnQpO1xuXHRcdH1cblxuXHRcdC8vIElnbm9yZSBub24tcmVzaXphYmxlIGNvbHVtbnNcblx0XHRsZXQgJGN1cnJlbnRHcmlwID0gJChldmVudC5jdXJyZW50VGFyZ2V0KTtcblx0XHRpZigkY3VycmVudEdyaXAuaXMoU0VMRUNUT1JfVU5SRVNJWkFCTEUpKSB7XG5cdFx0XHRyZXR1cm47XG5cdFx0fVxuXG5cdFx0bGV0IGdyaXBJbmRleCA9ICRjdXJyZW50R3JpcC5pbmRleCgpO1xuXHRcdGxldCAkbGVmdENvbHVtbiA9IHRoaXMuJHRhYmxlSGVhZGVycy5lcShncmlwSW5kZXgpLm5vdChTRUxFQ1RPUl9VTlJFU0laQUJMRSk7XG5cdFx0bGV0ICRyaWdodENvbHVtbiA9IHRoaXMuJHRhYmxlSGVhZGVycy5lcShncmlwSW5kZXggKyAxKS5ub3QoU0VMRUNUT1JfVU5SRVNJWkFCTEUpO1xuXG5cdFx0bGV0IGxlZnRXaWR0aCA9IHRoaXMucGFyc2VXaWR0aCgkbGVmdENvbHVtblswXSk7XG5cdFx0bGV0IHJpZ2h0V2lkdGggPSB0aGlzLnBhcnNlV2lkdGgoJHJpZ2h0Q29sdW1uWzBdKTtcblxuXHRcdHRoaXMub3BlcmF0aW9uID0ge1xuXHRcdFx0JGxlZnRDb2x1bW4sICRyaWdodENvbHVtbiwgJGN1cnJlbnRHcmlwLFxuXG5cdFx0XHRzdGFydFg6IHRoaXMuZ2V0UG9pbnRlclgoZXZlbnQpLFxuXG5cdFx0XHR3aWR0aHM6IHtcblx0XHRcdFx0bGVmdDogbGVmdFdpZHRoLFxuXHRcdFx0XHRyaWdodDogcmlnaHRXaWR0aFxuXHRcdFx0fSxcblx0XHRcdG5ld1dpZHRoczoge1xuXHRcdFx0XHRsZWZ0OiBsZWZ0V2lkdGgsXG5cdFx0XHRcdHJpZ2h0OiByaWdodFdpZHRoXG5cdFx0XHR9XG5cdFx0fTtcblxuXHRcdHRoaXMuYmluZEV2ZW50cyh0aGlzLiRvd25lckRvY3VtZW50LCBbJ21vdXNlbW92ZScsICd0b3VjaG1vdmUnXSwgdGhpcy5vblBvaW50ZXJNb3ZlLmJpbmQodGhpcykpO1xuXHRcdHRoaXMuYmluZEV2ZW50cyh0aGlzLiRvd25lckRvY3VtZW50LCBbJ21vdXNldXAnLCAndG91Y2hlbmQnXSwgdGhpcy5vblBvaW50ZXJVcC5iaW5kKHRoaXMpKTtcblxuXHRcdHRoaXMuJGhhbmRsZUNvbnRhaW5lclxuXHRcdFx0LmFkZCh0aGlzLiR0YWJsZSlcblx0XHRcdC5hZGRDbGFzcyhDTEFTU19UQUJMRV9SRVNJWklORyk7XG5cblx0XHQkbGVmdENvbHVtblxuXHRcdFx0LmFkZCgkcmlnaHRDb2x1bW4pXG5cdFx0XHQuYWRkKCRjdXJyZW50R3JpcClcblx0XHRcdC5hZGRDbGFzcyhDTEFTU19DT0xVTU5fUkVTSVpJTkcpO1xuXG5cdFx0dGhpcy50cmlnZ2VyRXZlbnQoRVZFTlRfUkVTSVpFX1NUQVJULCBbXG5cdFx0XHQkbGVmdENvbHVtbiwgJHJpZ2h0Q29sdW1uLFxuXHRcdFx0bGVmdFdpZHRoLCByaWdodFdpZHRoXG5cdFx0XSxcblx0XHRldmVudCk7XG5cblx0XHRldmVudC5wcmV2ZW50RGVmYXVsdCgpO1xuXHR9XG5cblx0LyoqXG5cdFBvaW50ZXIvbW91c2UgbW92ZW1lbnQgaGFuZGxlclxuXG5cdEBtZXRob2Qgb25Qb2ludGVyTW92ZVxuXHRAcGFyYW0gZXZlbnQge09iamVjdH0gRXZlbnQgb2JqZWN0IGFzc29jaWF0ZWQgd2l0aCB0aGUgaW50ZXJhY3Rpb25cblx0KiovXG5cdG9uUG9pbnRlck1vdmUoZXZlbnQpIHtcblx0XHRsZXQgb3AgPSB0aGlzLm9wZXJhdGlvbjtcblx0XHRpZighdGhpcy5vcGVyYXRpb24pIHsgcmV0dXJuOyB9XG5cblx0XHQvLyBEZXRlcm1pbmUgdGhlIGRlbHRhIGNoYW5nZSBiZXR3ZWVuIHN0YXJ0IGFuZCBuZXcgbW91c2UgcG9zaXRpb24sIGFzIGEgcGVyY2VudGFnZSBvZiB0aGUgdGFibGUgd2lkdGhcblx0XHRsZXQgZGlmZmVyZW5jZSA9IHRoaXMuZ2V0UG9pbnRlclgoZXZlbnQpIC0gb3Auc3RhcnRYO1xuXHRcdGlmKGRpZmZlcmVuY2UgPT09IDApIHtcblx0XHRcdHJldHVybjtcblx0XHR9XG5cblx0XHRsZXQgbGVmdENvbHVtbiA9IG9wLiRsZWZ0Q29sdW1uWzBdO1xuXHRcdGxldCByaWdodENvbHVtbiA9IG9wLiRyaWdodENvbHVtblswXTtcblx0XHRsZXQgd2lkdGhMZWZ0LCB3aWR0aFJpZ2h0O1xuXG5cdFx0d2lkdGhMZWZ0ID0gdGhpcy5jb25zdHJhaW5XaWR0aChvcC53aWR0aHMubGVmdCArIGRpZmZlcmVuY2UpO1xuXHRcdHdpZHRoUmlnaHQgPSB0aGlzLmNvbnN0cmFpbldpZHRoKG9wLndpZHRocy5yaWdodCk7XG5cblx0XHRpZihsZWZ0Q29sdW1uKSB7XG5cdFx0XHR0aGlzLnNldFdpZHRoKGxlZnRDb2x1bW4sIHdpZHRoTGVmdCk7XG5cdFx0fVxuXHRcdGlmKHJpZ2h0Q29sdW1uKSB7XG5cdFx0XHR0aGlzLnNldFdpZHRoKHJpZ2h0Q29sdW1uLCB3aWR0aFJpZ2h0KTtcblx0XHR9XG5cblx0XHRvcC5uZXdXaWR0aHMubGVmdCA9IHdpZHRoTGVmdDtcblx0XHRvcC5uZXdXaWR0aHMucmlnaHQgPSB3aWR0aFJpZ2h0O1xuXG5cdFx0cmV0dXJuIHRoaXMudHJpZ2dlckV2ZW50KEVWRU5UX1JFU0laRSwgW1xuXHRcdFx0b3AuJGxlZnRDb2x1bW4sIG9wLiRyaWdodENvbHVtbixcblx0XHRcdHdpZHRoTGVmdCwgd2lkdGhSaWdodFxuXHRcdF0sXG5cdFx0ZXZlbnQpO1xuXHR9XG5cblx0LyoqXG5cdFBvaW50ZXIvbW91c2UgcmVsZWFzZSBoYW5kbGVyXG5cblx0QG1ldGhvZCBvblBvaW50ZXJVcFxuXHRAcGFyYW0gZXZlbnQge09iamVjdH0gRXZlbnQgb2JqZWN0IGFzc29jaWF0ZWQgd2l0aCB0aGUgaW50ZXJhY3Rpb25cblx0KiovXG5cdG9uUG9pbnRlclVwKGV2ZW50KSB7XG5cdFx0bGV0IG9wID0gdGhpcy5vcGVyYXRpb247XG5cdFx0aWYoIXRoaXMub3BlcmF0aW9uKSB7IHJldHVybjsgfVxuXG5cdFx0dGhpcy51bmJpbmRFdmVudHModGhpcy4kb3duZXJEb2N1bWVudCwgWydtb3VzZXVwJywgJ3RvdWNoZW5kJywgJ21vdXNlbW92ZScsICd0b3VjaG1vdmUnXSk7XG5cblx0XHR0aGlzLiRoYW5kbGVDb250YWluZXJcblx0XHRcdC5hZGQodGhpcy4kdGFibGUpXG5cdFx0XHQucmVtb3ZlQ2xhc3MoQ0xBU1NfVEFCTEVfUkVTSVpJTkcpO1xuXG5cdFx0b3AuJGxlZnRDb2x1bW5cblx0XHRcdC5hZGQob3AuJHJpZ2h0Q29sdW1uKVxuXHRcdFx0LmFkZChvcC4kY3VycmVudEdyaXApXG5cdFx0XHQucmVtb3ZlQ2xhc3MoQ0xBU1NfQ09MVU1OX1JFU0laSU5HKTtcblxuXHRcdHRoaXMuc3luY0hhbmRsZVdpZHRocygpO1xuXHRcdHRoaXMuc2F2ZUNvbHVtbldpZHRocygpO1xuXG5cdFx0dGhpcy5vcGVyYXRpb24gPSBudWxsO1xuXG5cdFx0cmV0dXJuIHRoaXMudHJpZ2dlckV2ZW50KEVWRU5UX1JFU0laRV9TVE9QLCBbXG5cdFx0XHRvcC4kbGVmdENvbHVtbiwgb3AuJHJpZ2h0Q29sdW1uLFxuXHRcdFx0b3AubmV3V2lkdGhzLmxlZnQsIG9wLm5ld1dpZHRocy5yaWdodFxuXHRcdF0sXG5cdFx0ZXZlbnQpO1xuXHR9XG5cblx0LyoqXG5cdFJlbW92ZXMgYWxsIGV2ZW50IGxpc3RlbmVycywgZGF0YSwgYW5kIGFkZGVkIERPTSBlbGVtZW50cy4gVGFrZXNcblx0dGhlIDx0YWJsZS8+IGVsZW1lbnQgYmFjayB0byBob3cgaXQgd2FzLCBhbmQgcmV0dXJucyBpdFxuXG5cdEBtZXRob2QgZGVzdHJveVxuXHRAcmV0dXJuIHtqUXVlcnl9IE9yaWdpbmFsIGpRdWVyeS13cmFwcGVkIDx0YWJsZT4gZWxlbWVudFxuXHQqKi9cblx0ZGVzdHJveSgpIHtcblx0XHRsZXQgJHRhYmxlID0gdGhpcy4kdGFibGU7XG5cdFx0bGV0ICRoYW5kbGVzID0gdGhpcy4kaGFuZGxlQ29udGFpbmVyLmZpbmQoJy4nK0NMQVNTX0hBTkRMRSk7XG5cblx0XHR0aGlzLnVuYmluZEV2ZW50cyhcblx0XHRcdHRoaXMuJHdpbmRvd1xuXHRcdFx0XHQuYWRkKHRoaXMuJG93bmVyRG9jdW1lbnQpXG5cdFx0XHRcdC5hZGQodGhpcy4kdGFibGUpXG5cdFx0XHRcdC5hZGQoJGhhbmRsZXMpXG5cdFx0KTtcblxuXHRcdCRoYW5kbGVzLnJlbW92ZURhdGEoREFUQV9USCk7XG5cdFx0JHRhYmxlLnJlbW92ZURhdGEoREFUQV9BUEkpO1xuXG5cdFx0dGhpcy4kaGFuZGxlQ29udGFpbmVyLnJlbW92ZSgpO1xuXHRcdHRoaXMuJGhhbmRsZUNvbnRhaW5lciA9IG51bGw7XG5cdFx0dGhpcy4kdGFibGVIZWFkZXJzID0gbnVsbDtcblx0XHR0aGlzLiR0YWJsZSA9IG51bGw7XG5cblx0XHRyZXR1cm4gJHRhYmxlO1xuXHR9XG5cblx0LyoqXG5cdEJpbmRzIGdpdmVuIGV2ZW50cyBmb3IgdGhpcyBpbnN0YW5jZSB0byB0aGUgZ2l2ZW4gdGFyZ2V0IERPTUVsZW1lbnRcblxuXHRAcHJpdmF0ZVxuXHRAbWV0aG9kIGJpbmRFdmVudHNcblx0QHBhcmFtIHRhcmdldCB7alF1ZXJ5fSBqUXVlcnktd3JhcHBlZCBET01FbGVtZW50IHRvIGJpbmQgZXZlbnRzIHRvXG5cdEBwYXJhbSBldmVudHMge1N0cmluZ3xBcnJheX0gRXZlbnQgbmFtZSAob3IgYXJyYXkgb2YpIHRvIGJpbmRcblx0QHBhcmFtIHNlbGVjdG9yT3JDYWxsYmFjayB7U3RyaW5nfEZ1bmN0aW9ufSBTZWxlY3RvciBzdHJpbmcgb3IgY2FsbGJhY2tcblx0QHBhcmFtIFtjYWxsYmFja10ge0Z1bmN0aW9ufSBDYWxsYmFjayBtZXRob2Rcblx0KiovXG5cdGJpbmRFdmVudHMoJHRhcmdldCwgZXZlbnRzLCBzZWxlY3Rvck9yQ2FsbGJhY2ssIGNhbGxiYWNrKSB7XG5cdFx0aWYodHlwZW9mIGV2ZW50cyA9PT0gJ3N0cmluZycpIHtcblx0XHRcdGV2ZW50cyA9IGV2ZW50cyArIHRoaXMubnM7XG5cdFx0fVxuXHRcdGVsc2Uge1xuXHRcdFx0ZXZlbnRzID0gZXZlbnRzLmpvaW4odGhpcy5ucyArICcgJykgKyB0aGlzLm5zO1xuXHRcdH1cblxuXHRcdGlmKGFyZ3VtZW50cy5sZW5ndGggPiAzKSB7XG5cdFx0XHQkdGFyZ2V0Lm9uKGV2ZW50cywgc2VsZWN0b3JPckNhbGxiYWNrLCBjYWxsYmFjayk7XG5cdFx0fVxuXHRcdGVsc2Uge1xuXHRcdFx0JHRhcmdldC5vbihldmVudHMsIHNlbGVjdG9yT3JDYWxsYmFjayk7XG5cdFx0fVxuXHR9XG5cblx0LyoqXG5cdFVuYmluZHMgZXZlbnRzIHNwZWNpZmljIHRvIHRoaXMgaW5zdGFuY2UgZnJvbSB0aGUgZ2l2ZW4gdGFyZ2V0IERPTUVsZW1lbnRcblxuXHRAcHJpdmF0ZVxuXHRAbWV0aG9kIHVuYmluZEV2ZW50c1xuXHRAcGFyYW0gdGFyZ2V0IHtqUXVlcnl9IGpRdWVyeS13cmFwcGVkIERPTUVsZW1lbnQgdG8gdW5iaW5kIGV2ZW50cyBmcm9tXG5cdEBwYXJhbSBldmVudHMge1N0cmluZ3xBcnJheX0gRXZlbnQgbmFtZSAob3IgYXJyYXkgb2YpIHRvIHVuYmluZFxuXHQqKi9cblx0dW5iaW5kRXZlbnRzKCR0YXJnZXQsIGV2ZW50cykge1xuXHRcdGlmKHR5cGVvZiBldmVudHMgPT09ICdzdHJpbmcnKSB7XG5cdFx0XHRldmVudHMgPSBldmVudHMgKyB0aGlzLm5zO1xuXHRcdH1cblx0XHRlbHNlIGlmKGV2ZW50cyAhPSBudWxsKSB7XG5cdFx0XHRldmVudHMgPSBldmVudHMuam9pbih0aGlzLm5zICsgJyAnKSArIHRoaXMubnM7XG5cdFx0fVxuXHRcdGVsc2Uge1xuXHRcdFx0ZXZlbnRzID0gdGhpcy5ucztcblx0XHR9XG5cblx0XHQkdGFyZ2V0Lm9mZihldmVudHMpO1xuXHR9XG5cblx0LyoqXG5cdFRyaWdnZXJzIGFuIGV2ZW50IG9uIHRoZSA8dGFibGUvPiBlbGVtZW50IGZvciBhIGdpdmVuIHR5cGUgd2l0aCBnaXZlblxuXHRhcmd1bWVudHMsIGFsc28gc2V0dGluZyBhbmQgYWxsb3dpbmcgYWNjZXNzIHRvIHRoZSBvcmlnaW5hbEV2ZW50IGlmXG5cdGdpdmVuLiBSZXR1cm5zIHRoZSByZXN1bHQgb2YgdGhlIHRyaWdnZXJlZCBldmVudC5cblxuXHRAcHJpdmF0ZVxuXHRAbWV0aG9kIHRyaWdnZXJFdmVudFxuXHRAcGFyYW0gdHlwZSB7U3RyaW5nfSBFdmVudCBuYW1lXG5cdEBwYXJhbSBhcmdzIHtBcnJheX0gQXJyYXkgb2YgYXJndW1lbnRzIHRvIHBhc3MgdGhyb3VnaFxuXHRAcGFyYW0gW29yaWdpbmFsRXZlbnRdIElmIGdpdmVuLCBpcyBzZXQgb24gdGhlIGV2ZW50IG9iamVjdFxuXHRAcmV0dXJuIHtNaXhlZH0gUmVzdWx0IG9mIHRoZSBldmVudCB0cmlnZ2VyIGFjdGlvblxuXHQqKi9cblx0dHJpZ2dlckV2ZW50KHR5cGUsIGFyZ3MsIG9yaWdpbmFsRXZlbnQpIHtcblx0XHRsZXQgZXZlbnQgPSAkLkV2ZW50KHR5cGUpO1xuXHRcdGlmKGV2ZW50Lm9yaWdpbmFsRXZlbnQpIHtcblx0XHRcdGV2ZW50Lm9yaWdpbmFsRXZlbnQgPSAkLmV4dGVuZCh7fSwgb3JpZ2luYWxFdmVudCk7XG5cdFx0fVxuXG5cdFx0cmV0dXJuIHRoaXMuJHRhYmxlLnRyaWdnZXIoZXZlbnQsIFt0aGlzXS5jb25jYXQoYXJncyB8fCBbXSkpO1xuXHR9XG5cblx0LyoqXG5cdENhbGN1bGF0ZXMgYSB1bmlxdWUgY29sdW1uIElEIGZvciBhIGdpdmVuIGNvbHVtbiBET01FbGVtZW50XG5cblx0QHByaXZhdGVcblx0QG1ldGhvZCBnZW5lcmF0ZUNvbHVtbklkXG5cdEBwYXJhbSAkZWwge2pRdWVyeX0galF1ZXJ5LXdyYXBwZWQgY29sdW1uIGVsZW1lbnRcblx0QHJldHVybiB7U3RyaW5nfSBDb2x1bW4gSURcblx0KiovXG5cdGdlbmVyYXRlQ29sdW1uSWQoJGVsKSB7XG5cdFx0cmV0dXJuIHRoaXMuJHRhYmxlLmRhdGEoREFUQV9DT0xVTU5TX0lEKSArICctJyArICRlbC5kYXRhKERBVEFfQ09MVU1OX0lEKTtcblx0fVxuXG5cdC8qKlxuXHRQYXJzZXMgYSBnaXZlbiBET01FbGVtZW50J3Mgd2lkdGggaW50byBhIGZsb2F0XG5cblx0QHByaXZhdGVcblx0QG1ldGhvZCBwYXJzZVdpZHRoXG5cdEBwYXJhbSBlbGVtZW50IHtET01FbGVtZW50fSBFbGVtZW50IHRvIGdldCB3aWR0aCBvZlxuXHRAcmV0dXJuIHtOdW1iZXJ9IEVsZW1lbnQncyB3aWR0aCBhcyBhIGZsb2F0XG5cdCoqL1xuXHRwYXJzZVdpZHRoKGVsZW1lbnQpIHtcblx0XHRyZXR1cm4gZWxlbWVudCA/IHBhcnNlRmxvYXQoZWxlbWVudC5zdHlsZS53aWR0aCkgOiAwO1xuXHR9XG5cblx0LyoqXG5cdFNldHMgdGhlIHBlcmNlbnRhZ2Ugd2lkdGggb2YgYSBnaXZlbiBET01FbGVtZW50XG5cblx0QHByaXZhdGVcblx0QG1ldGhvZCBzZXRXaWR0aFxuXHRAcGFyYW0gZWxlbWVudCB7RE9NRWxlbWVudH0gRWxlbWVudCB0byBzZXQgd2lkdGggb25cblx0QHBhcmFtIHdpZHRoIHtOdW1iZXJ9IFdpZHRoLCBhcyBhIHBlcmNlbnRhZ2UsIHRvIHNldFxuXHQqKi9cblx0c2V0V2lkdGgoZWxlbWVudCwgd2lkdGgpIHtcblx0XHR3aWR0aCA9IHdpZHRoLnRvRml4ZWQoMik7XG5cdFx0d2lkdGggPSB3aWR0aCA+IDAgPyB3aWR0aCA6IDA7XG5cdFx0JChlbGVtZW50KS53aWR0aCh3aWR0aClcblx0fVxuXG5cdC8qKlxuXHRDb25zdHJhaW5zIGEgZ2l2ZW4gd2lkdGggdG8gdGhlIG1pbmltdW0gYW5kIG1heGltdW0gcmFuZ2VzIGRlZmluZWQgaW5cblx0dGhlIGBtaW5XaWR0aGAgYW5kIGBtYXhXaWR0aGAgY29uZmlndXJhdGlvbiBvcHRpb25zLCByZXNwZWN0aXZlbHkuXG5cblx0QHByaXZhdGVcblx0QG1ldGhvZCBjb25zdHJhaW5XaWR0aFxuXHRAcGFyYW0gd2lkdGgge051bWJlcn0gV2lkdGggdG8gY29uc3RyYWluXG5cdEByZXR1cm4ge051bWJlcn0gQ29uc3RyYWluZWQgd2lkdGhcblx0KiovXG5cdGNvbnN0cmFpbldpZHRoKHdpZHRoKSB7XG5cdFx0aWYgKHRoaXMub3B0aW9ucy5taW5XaWR0aCAhPSB1bmRlZmluZWQpIHtcblx0XHRcdHdpZHRoID0gTWF0aC5tYXgodGhpcy5vcHRpb25zLm1pbldpZHRoLCB3aWR0aCk7XG5cdFx0fVxuXG5cdFx0aWYgKHRoaXMub3B0aW9ucy5tYXhXaWR0aCAhPSB1bmRlZmluZWQpIHtcblx0XHRcdHdpZHRoID0gTWF0aC5taW4odGhpcy5vcHRpb25zLm1heFdpZHRoLCB3aWR0aCk7XG5cdFx0fVxuXG5cdFx0cmV0dXJuIHdpZHRoO1xuXHR9XG5cblx0LyoqXG5cdEdpdmVuIGEgcGFydGljdWxhciBFdmVudCBvYmplY3QsIHJldHJpZXZlcyB0aGUgY3VycmVudCBwb2ludGVyIG9mZnNldCBhbG9uZ1xuXHR0aGUgaG9yaXpvbnRhbCBkaXJlY3Rpb24uIEFjY291bnRzIGZvciBib3RoIHJlZ3VsYXIgbW91c2UgY2xpY2tzIGFzIHdlbGwgYXNcblx0cG9pbnRlci1saWtlIHN5c3RlbXMgKG1vYmlsZXMsIHRhYmxldHMgZXRjLilcblxuXHRAcHJpdmF0ZVxuXHRAbWV0aG9kIGdldFBvaW50ZXJYXG5cdEBwYXJhbSBldmVudCB7T2JqZWN0fSBFdmVudCBvYmplY3QgYXNzb2NpYXRlZCB3aXRoIHRoZSBpbnRlcmFjdGlvblxuXHRAcmV0dXJuIHtOdW1iZXJ9IEhvcml6b250YWwgcG9pbnRlciBvZmZzZXRcblx0KiovXG5cdGdldFBvaW50ZXJYKGV2ZW50KSB7XG5cdFx0aWYgKGV2ZW50LnR5cGUuaW5kZXhPZigndG91Y2gnKSA9PT0gMCkge1xuXHRcdFx0cmV0dXJuIChldmVudC5vcmlnaW5hbEV2ZW50LnRvdWNoZXNbMF0gfHwgZXZlbnQub3JpZ2luYWxFdmVudC5jaGFuZ2VkVG91Y2hlc1swXSkucGFnZVg7XG5cdFx0fVxuXHRcdHJldHVybiBldmVudC5wYWdlWDtcblx0fVxufVxuXG5SZXNpemFibGVDb2x1bW5zLmRlZmF1bHRzID0ge1xuXHRzZWxlY3RvcjogZnVuY3Rpb24oJHRhYmxlKSB7XG5cdFx0aWYoJHRhYmxlLmZpbmQoJ3RoZWFkJykubGVuZ3RoKSB7XG5cdFx0XHRyZXR1cm4gU0VMRUNUT1JfVEg7XG5cdFx0fVxuXG5cdFx0cmV0dXJuIFNFTEVDVE9SX1REO1xuXHR9LFxuXHQvL2pxdWVyeSBlbGVtZW50IG9mIHRoZSBoYW5kbGVDb250YWluZXIgcG9zaXRpb24saGFuZGxlQ29udGFpbmVyIHdpbGwgYmVmb3JlIHRoZSBlbGVtZW50LCBkZWZhdWx0IHdpbGwgYmUgdGhpcyB0YWJsZVxuXHRoYW5kbGVDb250YWluZXI6bnVsbCxcblx0cGFkZGluZzowLFxuXHRzdG9yZTogd2luZG93LnN0b3JlLFxuXHRzeW5jSGFuZGxlcnM6IHRydWUsXG5cdHJlc2l6ZUZyb21Cb2R5OiB0cnVlLFxuXHRtYXhXaWR0aDogbnVsbCxcblx0bWluV2lkdGg6IDAuMDFcbn07XG5cblJlc2l6YWJsZUNvbHVtbnMuY291bnQgPSAwO1xuIiwiZXhwb3J0IGNvbnN0IERBVEFfQVBJID0gJ3Jlc2l6YWJsZUNvbHVtbnMnO1xuZXhwb3J0IGNvbnN0IERBVEFfQ09MVU1OU19JRCA9ICdyZXNpemFibGUtY29sdW1ucy1pZCc7XG5leHBvcnQgY29uc3QgREFUQV9DT0xVTU5fSUQgPSAncmVzaXphYmxlLWNvbHVtbi1pZCc7XG5leHBvcnQgY29uc3QgREFUQV9USCA9ICd0aCc7XG5cbmV4cG9ydCBjb25zdCBDTEFTU19UQUJMRV9SRVNJWklORyA9ICdyYy10YWJsZS1yZXNpemluZyc7XG5leHBvcnQgY29uc3QgQ0xBU1NfQ09MVU1OX1JFU0laSU5HID0gJ3JjLWNvbHVtbi1yZXNpemluZyc7XG5leHBvcnQgY29uc3QgQ0xBU1NfSEFORExFID0gJ3JjLWhhbmRsZSc7XG5leHBvcnQgY29uc3QgQ0xBU1NfSEFORExFX0NPTlRBSU5FUiA9ICdyYy1oYW5kbGUtY29udGFpbmVyJztcblxuZXhwb3J0IGNvbnN0IEVWRU5UX1JFU0laRV9TVEFSVCA9ICdjb2x1bW46cmVzaXplOnN0YXJ0JztcbmV4cG9ydCBjb25zdCBFVkVOVF9SRVNJWkUgPSAnY29sdW1uOnJlc2l6ZSc7XG5leHBvcnQgY29uc3QgRVZFTlRfUkVTSVpFX1NUT1AgPSAnY29sdW1uOnJlc2l6ZTpzdG9wJztcblxuZXhwb3J0IGNvbnN0IFNFTEVDVE9SX1RIID0gJ3RyOmZpcnN0ID4gdGg6dmlzaWJsZSc7XG5leHBvcnQgY29uc3QgU0VMRUNUT1JfVEQgPSAndHI6Zmlyc3QgPiB0ZDp2aXNpYmxlJztcbmV4cG9ydCBjb25zdCBTRUxFQ1RPUl9VTlJFU0laQUJMRSA9IGBbZGF0YS1ub3Jlc2l6ZV1gO1xuIiwiaW1wb3J0IFJlc2l6YWJsZUNvbHVtbnMgZnJvbSAnLi9jbGFzcyc7XG5pbXBvcnQgYWRhcHRlciBmcm9tICcuL2FkYXB0ZXInO1xuXG5leHBvcnQgZGVmYXVsdCBSZXNpemFibGVDb2x1bW5zOyJdLCJwcmVFeGlzdGluZ0NvbW1lbnQiOiIvLyMgc291cmNlTWFwcGluZ1VSTD1kYXRhOmFwcGxpY2F0aW9uL2pzb247Y2hhcnNldDp1dGYtODtiYXNlNjQsZXlKMlpYSnphVzl1SWpvekxDSnpiM1Z5WTJWeklqcGJJbTV2WkdWZmJXOWtkV3hsY3k5aWNtOTNjMlZ5TFhCaFkyc3ZYM0J5Wld4MVpHVXVhbk1pTENKRU9pOXpiM1Z5WTJVdmFuRjFaWEo1TFhKbGMybDZZV0pzWlMxamIyeDFiVzV6TDNOeVl5OWhaR0Z3ZEdWeUxtcHpJaXdpUkRvdmMyOTFjbU5sTDJweGRXVnllUzF5WlhOcGVtRmliR1V0WTI5c2RXMXVjeTl6Y21NdlkyeGhjM011YW5NaUxDSkVPaTl6YjNWeVkyVXZhbkYxWlhKNUxYSmxjMmw2WVdKc1pTMWpiMngxYlc1ekwzTnlZeTlqYjI1emRHRnVkSE11YW5NaUxDSkVPaTl6YjNWeVkyVXZhbkYxWlhKNUxYSmxjMmw2WVdKc1pTMWpiMngxYlc1ekwzTnlZeTlwYm1SbGVDNXFjeUpkTENKdVlXMWxjeUk2VzEwc0ltMWhjSEJwYm1keklqb2lRVUZCUVRzN096czdjVUpEUVRaQ0xGTkJRVk03T3pzN2VVSkJRMllzWVVGQllUczdRVUZGY0VNc1EwRkJReXhEUVVGRExFVkJRVVVzUTBGQlF5eG5Ra0ZCWjBJc1IwRkJSeXhWUVVGVExHVkJRV1VzUlVGQlZ6dHRRMEZCVGl4SlFVRkpPMEZCUVVvc1RVRkJTVHM3TzBGQlEzaEVMRkZCUVU4c1NVRkJTU3hEUVVGRExFbEJRVWtzUTBGQlF5eFpRVUZYTzBGQlF6TkNMRTFCUVVrc1RVRkJUU3hIUVVGSExFTkJRVU1zUTBGQlF5eEpRVUZKTEVOQlFVTXNRMEZCUXpzN1FVRkZja0lzVFVGQlNTeEhRVUZITEVkQlFVY3NUVUZCVFN4RFFVRkRMRWxCUVVrc2NVSkJRVlVzUTBGQlF6dEJRVU5vUXl4TlFVRkpMRU5CUVVNc1IwRkJSeXhGUVVGRk8wRkJRMVFzVFVGQlJ5eEhRVUZITEhWQ1FVRnhRaXhOUVVGTkxFVkJRVVVzWlVGQlpTeERRVUZETEVOQlFVTTdRVUZEY0VRc1UwRkJUU3hEUVVGRExFbEJRVWtzYzBKQlFWY3NSMEZCUnl4RFFVRkRMRU5CUVVNN1IwRkRNMElzVFVGRlNTeEpRVUZKTEU5QlFVOHNaVUZCWlN4TFFVRkxMRkZCUVZFc1JVRkJSVHM3TzBGQlF6ZERMRlZCUVU4c1VVRkJRU3hIUVVGSExFVkJRVU1zWlVGQlpTeFBRVUZETEU5QlFVa3NTVUZCU1N4RFFVRkRMRU5CUVVNN1IwRkRja003UlVGRFJDeERRVUZETEVOQlFVTTdRMEZEU0N4RFFVRkRPenRCUVVWR0xFTkJRVU1zUTBGQlF5eG5Ra0ZCWjBJc2NVSkJRVzFDTEVOQlFVTTdPenM3T3pzN096czdPenM3ZVVKRFNHcERMR0ZCUVdFN096czdPenM3T3pzN08wbEJWVWNzWjBKQlFXZENPMEZCUTNwQ0xGVkJSRk1zWjBKQlFXZENMRU5CUTNoQ0xFMUJRVTBzUlVGQlJTeFBRVUZQTEVWQlFVVTdkMEpCUkZRc1owSkJRV2RDT3p0QlFVVnVReXhOUVVGSkxFTkJRVU1zUlVGQlJTeEhRVUZITEV0QlFVc3NSMEZCUnl4SlFVRkpMRU5CUVVNc1MwRkJTeXhGUVVGRkxFTkJRVU03UVVGREwwSXNUVUZCU1N4RFFVRkRMRzFDUVVGdFFpeEhRVUZITEUxQlFVMHNRMEZCUXl4SFFVRkhMRU5CUVVNc1kwRkJZeXhEUVVGRExFTkJRVUU3UVVGRGNrUXNUVUZCU1N4RFFVRkRMRTlCUVU4c1IwRkJSeXhEUVVGRExFTkJRVU1zVFVGQlRTeERRVUZETEVWQlFVVXNSVUZCUlN4blFrRkJaMElzUTBGQlF5eFJRVUZSTEVWQlFVVXNUMEZCVHl4RFFVRkRMRU5CUVVNN08wRkJSV2hGTEUxQlFVa3NRMEZCUXl4UFFVRlBMRWRCUVVjc1EwRkJReXhEUVVGRExFMUJRVTBzUTBGQlF5eERRVUZETzBGQlEzcENMRTFCUVVrc1EwRkJReXhqUVVGakxFZEJRVWNzUTBGQlF5eERRVUZETEUxQlFVMHNRMEZCUXl4RFFVRkRMRU5CUVVNc1EwRkJReXhoUVVGaExFTkJRVU1zUTBGQlF6dEJRVU5xUkN4TlFVRkpMRU5CUVVNc1RVRkJUU3hIUVVGSExFMUJRVTBzUTBGQlF6czdRVUZGY2tJc1RVRkJTU3hEUVVGRExHTkJRV01zUlVGQlJTeERRVUZETzBGQlEzUkNMRTFCUVVrc1EwRkJReXh0UWtGQmJVSXNSVUZCUlN4RFFVRkRPMEZCUXpOQ0xFMUJRVWtzUTBGQlF5eG5Ra0ZCWjBJc1JVRkJSU3hEUVVGRE96dEJRVVY0UWl4TlFVRkpMRU5CUVVNc1ZVRkJWU3hEUVVGRExFbEJRVWtzUTBGQlF5eFBRVUZQTEVWQlFVVXNVVUZCVVN4RlFVRkZMRWxCUVVrc1EwRkJReXhuUWtGQlowSXNRMEZCUXl4SlFVRkpMRU5CUVVNc1NVRkJTU3hEUVVGRExFTkJRVU1zUTBGQlF6czdRVUZGTVVVc1RVRkJTU3hKUVVGSkxFTkJRVU1zVDBGQlR5eERRVUZETEV0QlFVc3NSVUZCUlR0QlFVTjJRaXhQUVVGSkxFTkJRVU1zVlVGQlZTeERRVUZETEVsQlFVa3NRMEZCUXl4TlFVRk5MR2xEUVVGelFpeEpRVUZKTEVOQlFVTXNUMEZCVHl4RFFVRkRMRXRCUVVzc1EwRkJReXhEUVVGRE8wZEJRM0pGTzBGQlEwUXNUVUZCU1N4SlFVRkpMRU5CUVVNc1QwRkJUeXhEUVVGRExFMUJRVTBzUlVGQlJUdEJRVU40UWl4UFFVRkpMRU5CUVVNc1ZVRkJWU3hEUVVGRExFbEJRVWtzUTBGQlF5eE5RVUZOTERKQ1FVRm5RaXhKUVVGSkxFTkJRVU1zVDBGQlR5eERRVUZETEUxQlFVMHNRMEZCUXl4RFFVRkRPMGRCUTJoRk8wRkJRMFFzVFVGQlNTeEpRVUZKTEVOQlFVTXNUMEZCVHl4RFFVRkRMRWxCUVVrc1JVRkJSVHRCUVVOMFFpeFBRVUZKTEVOQlFVTXNWVUZCVlN4RFFVRkRMRWxCUVVrc1EwRkJReXhOUVVGTkxHZERRVUZ4UWl4SlFVRkpMRU5CUVVNc1QwRkJUeXhEUVVGRExFbEJRVWtzUTBGQlF5eERRVUZETzBkQlEyNUZPMFZCUTBRN096czdPenM3TzJOQmVrSnRRaXhuUWtGQlowSTdPMU5CYVVOMFFpd3dRa0ZCUnpzN08wRkJSMmhDTEU5QlFVa3NVVUZCVVN4SFFVRkhMRWxCUVVrc1EwRkJReXhQUVVGUExFTkJRVU1zVVVGQlVTeERRVUZETzBGQlEzSkRMRTlCUVVjc1QwRkJUeXhSUVVGUkxFdEJRVXNzVlVGQlZTeEZRVUZGTzBGQlEyeERMRmxCUVZFc1IwRkJSeXhSUVVGUkxFTkJRVU1zU1VGQlNTeERRVUZETEVsQlFVa3NSVUZCUlN4SlFVRkpMRU5CUVVNc1RVRkJUU3hEUVVGRExFTkJRVU03U1VGRE5VTTdPenRCUVVkRUxFOUJRVWtzUTBGQlF5eGhRVUZoTEVkQlFVY3NTVUZCU1N4RFFVRkRMRTFCUVUwc1EwRkJReXhKUVVGSkxFTkJRVU1zVVVGQlVTeERRVUZETEVOQlFVTTdPenRCUVVkb1JDeFBRVUZKTEVOQlFVTXNjMEpCUVhOQ0xFVkJRVVVzUTBGQlF6dEJRVU01UWl4UFFVRkpMRU5CUVVNc1lVRkJZU3hGUVVGRkxFTkJRVU03T3p0QlFVZHlRaXhQUVVGSkxFTkJRVU1zVFVGQlRTeERRVUZETEVkQlFVY3NRMEZCUXl4alFVRmpMRVZCUVVNc1QwRkJUeXhEUVVGRExFTkJRVUU3UjBGRGRrTTdPenM3T3pzN08xTkJUMWtzZVVKQlFVYzdPenRCUVVObUxFOUJRVWtzUjBGQlJ5eEhRVUZITEVsQlFVa3NRMEZCUXl4blFrRkJaMElzUTBGQlF6dEJRVU5vUXl4UFFVRkpMRWRCUVVjc1NVRkJTU3hKUVVGSkxFVkJRVVU3UVVGRGFFSXNUMEZCUnl4RFFVRkRMRTFCUVUwc1JVRkJSU3hEUVVGRE8wbEJRMkk3TzBGQlJVUXNUMEZCU1N4RFFVRkRMR2RDUVVGblFpeEhRVUZITEVOQlFVTXNLMFJCUVRaRExFTkJRVUU3UVVGRGRFVXNUMEZCU1N4RFFVRkRMRTlCUVU4c1EwRkJReXhsUVVGbExFZEJRVWNzU1VGQlNTeERRVUZETEU5QlFVOHNRMEZCUXl4bFFVRmxMRU5CUVVNc1RVRkJUU3hEUVVGRExFbEJRVWtzUTBGQlF5eG5Ra0ZCWjBJc1EwRkJReXhIUVVGSExFbEJRVWtzUTBGQlF5eE5RVUZOTEVOQlFVTXNUVUZCVFN4RFFVRkRMRWxCUVVrc1EwRkJReXhuUWtGQlowSXNRMEZCUXl4RFFVRkRPenRCUVVWMFNTeFBRVUZKTEVOQlFVTXNZVUZCWVN4RFFVRkRMRWxCUVVrc1EwRkJReXhWUVVGRExFTkJRVU1zUlVGQlJTeEZRVUZGTEVWQlFVczdRVUZEYkVNc1VVRkJTU3hSUVVGUkxFZEJRVWNzVFVGQlN5eGhRVUZoTEVOQlFVTXNSVUZCUlN4RFFVRkRMRU5CUVVNc1EwRkJReXhEUVVGRE8wRkJRM2hETEZGQlFVa3NTMEZCU3l4SFFVRkhMRTFCUVVzc1lVRkJZU3hEUVVGRExFVkJRVVVzUTBGQlF5eERRVUZETEVkQlFVY3NRMEZCUXl4RFFVRkRMRU5CUVVNN08wRkJSWHBETEZGQlFVa3NTMEZCU3l4RFFVRkRMRTFCUVUwc1MwRkJTeXhEUVVGRExFbEJRVWtzVVVGQlVTeERRVUZETEVWQlFVVXNhVU5CUVhOQ0xFbEJRVWtzUzBGQlN5eERRVUZETEVWQlFVVXNhVU5CUVhOQ0xFVkJRVVU3UVVGRE9VWXNXVUZCVHp0TFFVTlFPenRCUVVWRUxGRkJRVWtzVDBGQlR5eEhRVUZITEVOQlFVTXNjVVJCUVcxRExFTkJRMmhFTEVsQlFVa3NjVUpCUVZVc1EwRkJReXhEUVVGRExFVkJRVVVzUTBGQlF5eERRVUZETEVOQlEzQkNMRkZCUVZFc1EwRkJReXhOUVVGTExHZENRVUZuUWl4RFFVRkRMRU5CUVVNN1NVRkRiRU1zUTBGQlF5eERRVUZET3p0QlFVVklMRTlCUVVrc1EwRkJReXhWUVVGVkxFTkJRVU1zU1VGQlNTeERRVUZETEdkQ1FVRm5RaXhGUVVGRkxFTkJRVU1zVjBGQlZ5eEZRVUZGTEZsQlFWa3NRMEZCUXl4RlFVRkZMRWRCUVVjc01FSkJRV0VzUlVGQlJTeEpRVUZKTEVOQlFVTXNZVUZCWVN4RFFVRkRMRWxCUVVrc1EwRkJReXhKUVVGSkxFTkJRVU1zUTBGQlF5eERRVUZETzBkQlEzSklPenM3T3pzN096dFRRVTl4UWl4clEwRkJSenM3TzBGQlEzaENMRTlCUVVrc1EwRkJReXhoUVVGaExFTkJRVU1zU1VGQlNTeERRVUZETEZWQlFVTXNRMEZCUXl4RlFVRkZMRVZCUVVVc1JVRkJTenRCUVVOc1F5eFJRVUZKTEVkQlFVY3NSMEZCUnl4RFFVRkRMRU5CUVVNc1JVRkJSU3hEUVVGRExFTkJRVU03UVVGRGFFSXNWMEZCU3l4UlFVRlJMRU5CUVVNc1IwRkJSeXhEUVVGRExFTkJRVU1zUTBGQlF5eEZRVUZGTEVkQlFVY3NRMEZCUXl4VlFVRlZMRVZCUVVVc1IwRkJSU3hQUVVGTExFOUJRVThzUTBGQlF5eFBRVUZQTEVOQlFVTXNRMEZCUXp0SlFVTTVSQ3hEUVVGRExFTkJRVU03UjBGRFNEczdPenM3T3pzN1UwRlBaU3cwUWtGQlJ6czdPMEZCUTJ4Q0xFOUJRVWtzVlVGQlZTeEhRVUZITEVsQlFVa3NRMEZCUXl4blFrRkJaMElzUTBGQlFUczdRVUZGZEVNc1lVRkJWU3hEUVVGRExFdEJRVXNzUTBGQlF5eEpRVUZKTEVOQlFVTXNUVUZCVFN4RFFVRkRMRXRCUVVzc1JVRkJSU3hEUVVGRExFTkJRVU03TzBGQlJYUkRMR0ZCUVZVc1EwRkJReXhKUVVGSkxFTkJRVU1zUjBGQlJ5d3dRa0ZCWVN4RFFVRkRMRU5CUVVNc1NVRkJTU3hEUVVGRExGVkJRVU1zUTBGQlF5eEZRVUZGTEVWQlFVVXNSVUZCU3p0QlFVTnFSQ3hSUVVGSkxFZEJRVWNzUjBGQlJ5eERRVUZETEVOQlFVTXNSVUZCUlN4RFFVRkRMRU5CUVVNN08wRkJSV2hDTEZGQlFVa3NUVUZCVFN4SFFVRkhMRTlCUVVzc1QwRkJUeXhEUVVGRExHTkJRV01zUjBGRGRrTXNUMEZCU3l4TlFVRk5MRU5CUVVNc1RVRkJUU3hGUVVGRkxFZEJRM0JDTEU5QlFVc3NUVUZCVFN4RFFVRkRMRWxCUVVrc1EwRkJReXhQUVVGUExFTkJRVU1zUTBGQlF5eE5RVUZOTEVWQlFVVXNRMEZCUXpzN1FVRkZjRU1zVVVGQlNTeEpRVUZKTEVkQlFVY3NSMEZCUnl4RFFVRkRMRWxCUVVrc2IwSkJRVk1zUTBGQlF5eFZRVUZWTEVWQlFVVXNTVUZEZUVNc1IwRkJSeXhEUVVGRExFbEJRVWtzYjBKQlFWTXNRMEZCUXl4TlFVRk5MRVZCUVVVc1EwRkJReXhKUVVGSkxFZEJRVWNzVDBGQlN5eG5Ra0ZCWjBJc1EwRkJReXhOUVVGTkxFVkJRVVVzUTBGQlF5eEpRVUZKTEVOQlFVRXNRVUZEY2tVc1EwRkJRenM3UVVGRlJpeFBRVUZITEVOQlFVTXNSMEZCUnl4RFFVRkRMRVZCUVVVc1NVRkJTU3hGUVVGS0xFbEJRVWtzUlVGQlJTeE5RVUZOTEVWQlFVNHNUVUZCVFN4RlFVRkZMRU5CUVVNc1EwRkJRenRKUVVNeFFpeERRVUZETEVOQlFVTTdSMEZEU0RzN096czdPenM3VTBGUFpTdzBRa0ZCUnpzN08wRkJRMnhDTEU5QlFVa3NRMEZCUXl4aFFVRmhMRU5CUVVNc1NVRkJTU3hEUVVGRExGVkJRVU1zUTBGQlF5eEZRVUZGTEVWQlFVVXNSVUZCU3p0QlFVTnNReXhSUVVGSkxFZEJRVWNzUjBGQlJ5eERRVUZETEVOQlFVTXNSVUZCUlN4RFFVRkRMRU5CUVVNN08wRkJSV2hDTEZGQlFVa3NUMEZCU3l4UFFVRlBMRU5CUVVNc1MwRkJTeXhKUVVGSkxFTkJRVU1zUjBGQlJ5eERRVUZETEVWQlFVVXNhVU5CUVhOQ0xFVkJRVVU3UVVGRGVFUXNXVUZCU3l4UFFVRlBMRU5CUVVNc1MwRkJTeXhEUVVGRExFZEJRVWNzUTBGRGNrSXNUMEZCU3l4blFrRkJaMElzUTBGQlF5eEhRVUZITEVOQlFVTXNSVUZETVVJc1QwRkJTeXhWUVVGVkxFTkJRVU1zUlVGQlJTeERRVUZETEVOQlEyNUNMRU5CUVVNN1MwRkRSanRKUVVORUxFTkJRVU1zUTBGQlF6dEhRVU5JT3pzN096czdPenRUUVU5clFpd3JRa0ZCUnpzN08wRkJRM0pDTEU5QlFVa3NRMEZCUXl4aFFVRmhMRU5CUVVNc1NVRkJTU3hEUVVGRExGVkJRVU1zUTBGQlF5eEZRVUZGTEVWQlFVVXNSVUZCU3p0QlFVTnNReXhSUVVGSkxFZEJRVWNzUjBGQlJ5eERRVUZETEVOQlFVTXNSVUZCUlN4RFFVRkRMRU5CUVVNN08wRkJSV2hDTEZGQlFVY3NUMEZCU3l4UFFVRlBMRU5CUVVNc1MwRkJTeXhKUVVGSkxFTkJRVU1zUjBGQlJ5eERRVUZETEVWQlFVVXNhVU5CUVhOQ0xFVkJRVVU3UVVGRGRrUXNVMEZCU1N4TFFVRkxMRWRCUVVjc1QwRkJTeXhQUVVGUExFTkJRVU1zUzBGQlN5eERRVUZETEVkQlFVY3NRMEZEYWtNc1QwRkJTeXhuUWtGQlowSXNRMEZCUXl4SFFVRkhMRU5CUVVNc1EwRkRNVUlzUTBGQlF6czdRVUZGUml4VFFVRkhMRXRCUVVzc1NVRkJTU3hKUVVGSkxFVkJRVVU3UVVGRGFrSXNZVUZCU3l4UlFVRlJMRU5CUVVNc1JVRkJSU3hGUVVGRkxFdEJRVXNzUTBGQlF5eERRVUZETzAxQlEzcENPMHRCUTBRN1NVRkRSQ3hEUVVGRExFTkJRVU03UjBGRFNEczdPenM3T3pzN08xTkJVVmtzZFVKQlFVTXNTMEZCU3l4RlFVRkZPenRCUVVWd1FpeFBRVUZITEV0QlFVc3NRMEZCUXl4TFFVRkxMRXRCUVVzc1EwRkJReXhGUVVGRk8wRkJRVVVzVjBGQlR6dEpRVUZGT3pzN096dEJRVXRxUXl4UFFVRkhMRWxCUVVrc1EwRkJReXhUUVVGVExFVkJRVVU3UVVGRGJFSXNVVUZCU1N4RFFVRkRMRmRCUVZjc1EwRkJReXhMUVVGTExFTkJRVU1zUTBGQlF6dEpRVU40UWpzN08wRkJSMFFzVDBGQlNTeFpRVUZaTEVkQlFVY3NRMEZCUXl4RFFVRkRMRXRCUVVzc1EwRkJReXhoUVVGaExFTkJRVU1zUTBGQlF6dEJRVU14UXl4UFFVRkhMRmxCUVZrc1EwRkJReXhGUVVGRkxHbERRVUZ6UWl4RlFVRkZPMEZCUTNwRExGZEJRVTg3U1VGRFVEczdRVUZGUkN4UFFVRkpMRk5CUVZNc1IwRkJSeXhaUVVGWkxFTkJRVU1zUzBGQlN5eEZRVUZGTEVOQlFVTTdRVUZEY2tNc1QwRkJTU3hYUVVGWExFZEJRVWNzU1VGQlNTeERRVUZETEdGQlFXRXNRMEZCUXl4RlFVRkZMRU5CUVVNc1UwRkJVeXhEUVVGRExFTkJRVU1zUjBGQlJ5eHBRMEZCYzBJc1EwRkJRenRCUVVNM1JTeFBRVUZKTEZsQlFWa3NSMEZCUnl4SlFVRkpMRU5CUVVNc1lVRkJZU3hEUVVGRExFVkJRVVVzUTBGQlF5eFRRVUZUTEVkQlFVY3NRMEZCUXl4RFFVRkRMRU5CUVVNc1IwRkJSeXhwUTBGQmMwSXNRMEZCUXpzN1FVRkZiRVlzVDBGQlNTeFRRVUZUTEVkQlFVY3NTVUZCU1N4RFFVRkRMRlZCUVZVc1EwRkJReXhYUVVGWExFTkJRVU1zUTBGQlF5eERRVUZETEVOQlFVTXNRMEZCUXp0QlFVTm9SQ3hQUVVGSkxGVkJRVlVzUjBGQlJ5eEpRVUZKTEVOQlFVTXNWVUZCVlN4RFFVRkRMRmxCUVZrc1EwRkJReXhEUVVGRExFTkJRVU1zUTBGQlF5eERRVUZET3p0QlFVVnNSQ3hQUVVGSkxFTkJRVU1zVTBGQlV5eEhRVUZITzBGQlEyaENMR1ZCUVZjc1JVRkJXQ3hYUVVGWExFVkJRVVVzV1VGQldTeEZRVUZhTEZsQlFWa3NSVUZCUlN4WlFVRlpMRVZCUVZvc1dVRkJXVHM3UVVGRmRrTXNWVUZCVFN4RlFVRkZMRWxCUVVrc1EwRkJReXhYUVVGWExFTkJRVU1zUzBGQlN5eERRVUZET3p0QlFVVXZRaXhWUVVGTkxFVkJRVVU3UVVGRFVDeFRRVUZKTEVWQlFVVXNVMEZCVXp0QlFVTm1MRlZCUVVzc1JVRkJSU3hWUVVGVk8wdEJRMnBDTzBGQlEwUXNZVUZCVXl4RlFVRkZPMEZCUTFZc1UwRkJTU3hGUVVGRkxGTkJRVk03UVVGRFppeFZRVUZMTEVWQlFVVXNWVUZCVlR0TFFVTnFRanRKUVVORUxFTkJRVU03TzBGQlJVWXNUMEZCU1N4RFFVRkRMRlZCUVZVc1EwRkJReXhKUVVGSkxFTkJRVU1zWTBGQll5eEZRVUZGTEVOQlFVTXNWMEZCVnl4RlFVRkZMRmRCUVZjc1EwRkJReXhGUVVGRkxFbEJRVWtzUTBGQlF5eGhRVUZoTEVOQlFVTXNTVUZCU1N4RFFVRkRMRWxCUVVrc1EwRkJReXhEUVVGRExFTkJRVU03UVVGRGFFY3NUMEZCU1N4RFFVRkRMRlZCUVZVc1EwRkJReXhKUVVGSkxFTkJRVU1zWTBGQll5eEZRVUZGTEVOQlFVTXNVMEZCVXl4RlFVRkZMRlZCUVZVc1EwRkJReXhGUVVGRkxFbEJRVWtzUTBGQlF5eFhRVUZYTEVOQlFVTXNTVUZCU1N4RFFVRkRMRWxCUVVrc1EwRkJReXhEUVVGRExFTkJRVU03TzBGQlJUTkdMRTlCUVVrc1EwRkJReXhuUWtGQlowSXNRMEZEYmtJc1IwRkJSeXhEUVVGRExFbEJRVWtzUTBGQlF5eE5RVUZOTEVOQlFVTXNRMEZEYUVJc1VVRkJVU3hwUTBGQmMwSXNRMEZCUXpzN1FVRkZha01zWTBGQlZ5eERRVU5VTEVkQlFVY3NRMEZCUXl4WlFVRlpMRU5CUVVNc1EwRkRha0lzUjBGQlJ5eERRVUZETEZsQlFWa3NRMEZCUXl4RFFVTnFRaXhSUVVGUkxHdERRVUYxUWl4RFFVRkRPenRCUVVWc1F5eFBRVUZKTEVOQlFVTXNXVUZCV1N4blEwRkJjVUlzUTBGRGNrTXNWMEZCVnl4RlFVRkZMRmxCUVZrc1JVRkRla0lzVTBGQlV5eEZRVUZGTEZWQlFWVXNRMEZEY2tJc1JVRkRSQ3hMUVVGTExFTkJRVU1zUTBGQlF6czdRVUZGVUN4UlFVRkxMRU5CUVVNc1kwRkJZeXhGUVVGRkxFTkJRVU03UjBGRGRrSTdPenM3T3pzN096dFRRVkZaTEhWQ1FVRkRMRXRCUVVzc1JVRkJSVHRCUVVOd1FpeFBRVUZKTEVWQlFVVXNSMEZCUnl4SlFVRkpMRU5CUVVNc1UwRkJVeXhEUVVGRE8wRkJRM2hDTEU5QlFVY3NRMEZCUXl4SlFVRkpMRU5CUVVNc1UwRkJVeXhGUVVGRk8wRkJRVVVzVjBGQlR6dEpRVUZGT3pzN1FVRkhMMElzVDBGQlNTeFZRVUZWTEVkQlFVY3NTVUZCU1N4RFFVRkRMRmRCUVZjc1EwRkJReXhMUVVGTExFTkJRVU1zUjBGQlJ5eEZRVUZGTEVOQlFVTXNUVUZCVFN4RFFVRkRPMEZCUTNKRUxFOUJRVWNzVlVGQlZTeExRVUZMTEVOQlFVTXNSVUZCUlR0QlFVTndRaXhYUVVGUE8wbEJRMUE3TzBGQlJVUXNUMEZCU1N4VlFVRlZMRWRCUVVjc1JVRkJSU3hEUVVGRExGZEJRVmNzUTBGQlF5eERRVUZETEVOQlFVTXNRMEZCUXp0QlFVTnVReXhQUVVGSkxGZEJRVmNzUjBGQlJ5eEZRVUZGTEVOQlFVTXNXVUZCV1N4RFFVRkRMRU5CUVVNc1EwRkJReXhEUVVGRE8wRkJRM0pETEU5QlFVa3NVMEZCVXl4WlFVRkJPMDlCUVVVc1ZVRkJWU3haUVVGQkxFTkJRVU03TzBGQlJURkNMRmxCUVZNc1IwRkJSeXhKUVVGSkxFTkJRVU1zWTBGQll5eERRVUZETEVWQlFVVXNRMEZCUXl4TlFVRk5MRU5CUVVNc1NVRkJTU3hIUVVGSExGVkJRVlVzUTBGQlF5eERRVUZETzBGQlF6ZEVMR0ZCUVZVc1IwRkJSeXhKUVVGSkxFTkJRVU1zWTBGQll5eERRVUZETEVWQlFVVXNRMEZCUXl4TlFVRk5MRU5CUVVNc1MwRkJTeXhEUVVGRExFTkJRVU03TzBGQlJXeEVMRTlCUVVjc1ZVRkJWU3hGUVVGRk8wRkJRMlFzVVVGQlNTeERRVUZETEZGQlFWRXNRMEZCUXl4VlFVRlZMRVZCUVVVc1UwRkJVeXhEUVVGRExFTkJRVU03U1VGRGNrTTdRVUZEUkN4UFFVRkhMRmRCUVZjc1JVRkJSVHRCUVVObUxGRkJRVWtzUTBGQlF5eFJRVUZSTEVOQlFVTXNWMEZCVnl4RlFVRkZMRlZCUVZVc1EwRkJReXhEUVVGRE8wbEJRM1pET3p0QlFVVkVMRXRCUVVVc1EwRkJReXhUUVVGVExFTkJRVU1zU1VGQlNTeEhRVUZITEZOQlFWTXNRMEZCUXp0QlFVTTVRaXhMUVVGRkxFTkJRVU1zVTBGQlV5eERRVUZETEV0QlFVc3NSMEZCUnl4VlFVRlZMRU5CUVVNN08wRkJSV2hETEZWQlFVOHNTVUZCU1N4RFFVRkRMRmxCUVZrc01FSkJRV1VzUTBGRGRFTXNSVUZCUlN4RFFVRkRMRmRCUVZjc1JVRkJSU3hGUVVGRkxFTkJRVU1zV1VGQldTeEZRVU12UWl4VFFVRlRMRVZCUVVVc1ZVRkJWU3hEUVVOeVFpeEZRVU5FTEV0QlFVc3NRMEZCUXl4RFFVRkRPMGRCUTFBN096czdPenM3T3p0VFFWRlZMSEZDUVVGRExFdEJRVXNzUlVGQlJUdEJRVU5zUWl4UFFVRkpMRVZCUVVVc1IwRkJSeXhKUVVGSkxFTkJRVU1zVTBGQlV5eERRVUZETzBGQlEzaENMRTlCUVVjc1EwRkJReXhKUVVGSkxFTkJRVU1zVTBGQlV5eEZRVUZGTzBGQlFVVXNWMEZCVHp0SlFVRkZPenRCUVVVdlFpeFBRVUZKTEVOQlFVTXNXVUZCV1N4RFFVRkRMRWxCUVVrc1EwRkJReXhqUVVGakxFVkJRVVVzUTBGQlF5eFRRVUZUTEVWQlFVVXNWVUZCVlN4RlFVRkZMRmRCUVZjc1JVRkJSU3hYUVVGWExFTkJRVU1zUTBGQlF5eERRVUZET3p0QlFVVXhSaXhQUVVGSkxFTkJRVU1zWjBKQlFXZENMRU5CUTI1Q0xFZEJRVWNzUTBGQlF5eEpRVUZKTEVOQlFVTXNUVUZCVFN4RFFVRkRMRU5CUTJoQ0xGZEJRVmNzYVVOQlFYTkNMRU5CUVVNN08wRkJSWEJETEV0QlFVVXNRMEZCUXl4WFFVRlhMRU5CUTFvc1IwRkJSeXhEUVVGRExFVkJRVVVzUTBGQlF5eFpRVUZaTEVOQlFVTXNRMEZEY0VJc1IwRkJSeXhEUVVGRExFVkJRVVVzUTBGQlF5eFpRVUZaTEVOQlFVTXNRMEZEY0VJc1YwRkJWeXhyUTBGQmRVSXNRMEZCUXpzN1FVRkZja01zVDBGQlNTeERRVUZETEdkQ1FVRm5RaXhGUVVGRkxFTkJRVU03UVVGRGVFSXNUMEZCU1N4RFFVRkRMR2RDUVVGblFpeEZRVUZGTEVOQlFVTTdPMEZCUlhoQ0xFOUJRVWtzUTBGQlF5eFRRVUZUTEVkQlFVY3NTVUZCU1N4RFFVRkRPenRCUVVWMFFpeFZRVUZQTEVsQlFVa3NRMEZCUXl4WlFVRlpMQ3RDUVVGdlFpeERRVU16UXl4RlFVRkZMRU5CUVVNc1YwRkJWeXhGUVVGRkxFVkJRVVVzUTBGQlF5eFpRVUZaTEVWQlF5OUNMRVZCUVVVc1EwRkJReXhUUVVGVExFTkJRVU1zU1VGQlNTeEZRVUZGTEVWQlFVVXNRMEZCUXl4VFFVRlRMRU5CUVVNc1MwRkJTeXhEUVVOeVF5eEZRVU5FTEV0QlFVc3NRMEZCUXl4RFFVRkRPMGRCUTFBN096czdPenM3T3pzN1UwRlRUU3h0UWtGQlJ6dEJRVU5VTEU5QlFVa3NUVUZCVFN4SFFVRkhMRWxCUVVrc1EwRkJReXhOUVVGTkxFTkJRVU03UVVGRGVrSXNUMEZCU1N4UlFVRlJMRWRCUVVjc1NVRkJTU3hEUVVGRExHZENRVUZuUWl4RFFVRkRMRWxCUVVrc1EwRkJReXhIUVVGSExEQkNRVUZoTEVOQlFVTXNRMEZCUXpzN1FVRkZOVVFzVDBGQlNTeERRVUZETEZsQlFWa3NRMEZEYUVJc1NVRkJTU3hEUVVGRExFOUJRVThzUTBGRFZpeEhRVUZITEVOQlFVTXNTVUZCU1N4RFFVRkRMR05CUVdNc1EwRkJReXhEUVVONFFpeEhRVUZITEVOQlFVTXNTVUZCU1N4RFFVRkRMRTFCUVUwc1EwRkJReXhEUVVOb1FpeEhRVUZITEVOQlFVTXNVVUZCVVN4RFFVRkRMRU5CUTJZc1EwRkJRenM3UVVGRlJpeFhRVUZSTEVOQlFVTXNWVUZCVlN4dlFrRkJVeXhEUVVGRE8wRkJRemRDTEZOQlFVMHNRMEZCUXl4VlFVRlZMSEZDUVVGVkxFTkJRVU03TzBGQlJUVkNMRTlCUVVrc1EwRkJReXhuUWtGQlowSXNRMEZCUXl4TlFVRk5MRVZCUVVVc1EwRkJRenRCUVVNdlFpeFBRVUZKTEVOQlFVTXNaMEpCUVdkQ0xFZEJRVWNzU1VGQlNTeERRVUZETzBGQlF6ZENMRTlCUVVrc1EwRkJReXhoUVVGaExFZEJRVWNzU1VGQlNTeERRVUZETzBGQlF6RkNMRTlCUVVrc1EwRkJReXhOUVVGTkxFZEJRVWNzU1VGQlNTeERRVUZET3p0QlFVVnVRaXhWUVVGUExFMUJRVTBzUTBGQlF6dEhRVU5rT3pzN096czdPenM3T3pzN08xTkJXVk1zYjBKQlFVTXNUMEZCVHl4RlFVRkZMRTFCUVUwc1JVRkJSU3hyUWtGQmEwSXNSVUZCUlN4UlFVRlJMRVZCUVVVN1FVRkRla1FzVDBGQlJ5eFBRVUZQTEUxQlFVMHNTMEZCU3l4UlFVRlJMRVZCUVVVN1FVRkRPVUlzVlVGQlRTeEhRVUZITEUxQlFVMHNSMEZCUnl4SlFVRkpMRU5CUVVNc1JVRkJSU3hEUVVGRE8wbEJRekZDTEUxQlEwazdRVUZEU2l4VlFVRk5MRWRCUVVjc1RVRkJUU3hEUVVGRExFbEJRVWtzUTBGQlF5eEpRVUZKTEVOQlFVTXNSVUZCUlN4SFFVRkhMRWRCUVVjc1EwRkJReXhIUVVGSExFbEJRVWtzUTBGQlF5eEZRVUZGTEVOQlFVTTdTVUZET1VNN08wRkJSVVFzVDBGQlJ5eFRRVUZUTEVOQlFVTXNUVUZCVFN4SFFVRkhMRU5CUVVNc1JVRkJSVHRCUVVONFFpeFhRVUZQTEVOQlFVTXNSVUZCUlN4RFFVRkRMRTFCUVUwc1JVRkJSU3hyUWtGQmEwSXNSVUZCUlN4UlFVRlJMRU5CUVVNc1EwRkJRenRKUVVOcVJDeE5RVU5KTzBGQlEwb3NWMEZCVHl4RFFVRkRMRVZCUVVVc1EwRkJReXhOUVVGTkxFVkJRVVVzYTBKQlFXdENMRU5CUVVNc1EwRkJRenRKUVVOMlF6dEhRVU5FT3pzN096czdPenM3T3p0VFFWVlhMSE5DUVVGRExFOUJRVThzUlVGQlJTeE5RVUZOTEVWQlFVVTdRVUZETjBJc1QwRkJSeXhQUVVGUExFMUJRVTBzUzBGQlN5eFJRVUZSTEVWQlFVVTdRVUZET1VJc1ZVRkJUU3hIUVVGSExFMUJRVTBzUjBGQlJ5eEpRVUZKTEVOQlFVTXNSVUZCUlN4RFFVRkRPMGxCUXpGQ0xFMUJRMGtzU1VGQlJ5eE5RVUZOTEVsQlFVa3NTVUZCU1N4RlFVRkZPMEZCUTNaQ0xGVkJRVTBzUjBGQlJ5eE5RVUZOTEVOQlFVTXNTVUZCU1N4RFFVRkRMRWxCUVVrc1EwRkJReXhGUVVGRkxFZEJRVWNzUjBGQlJ5eERRVUZETEVkQlFVY3NTVUZCU1N4RFFVRkRMRVZCUVVVc1EwRkJRenRKUVVNNVF5eE5RVU5KTzBGQlEwb3NWVUZCVFN4SFFVRkhMRWxCUVVrc1EwRkJReXhGUVVGRkxFTkJRVU03U1VGRGFrSTdPMEZCUlVRc1ZVRkJUeXhEUVVGRExFZEJRVWNzUTBGQlF5eE5RVUZOTEVOQlFVTXNRMEZCUXp0SFFVTndRanM3T3pzN096czdPenM3T3pzN08xTkJZMWNzYzBKQlFVTXNTVUZCU1N4RlFVRkZMRWxCUVVrc1JVRkJSU3hoUVVGaExFVkJRVVU3UVVGRGRrTXNUMEZCU1N4TFFVRkxMRWRCUVVjc1EwRkJReXhEUVVGRExFdEJRVXNzUTBGQlF5eEpRVUZKTEVOQlFVTXNRMEZCUXp0QlFVTXhRaXhQUVVGSExFdEJRVXNzUTBGQlF5eGhRVUZoTEVWQlFVVTdRVUZEZGtJc1UwRkJTeXhEUVVGRExHRkJRV0VzUjBGQlJ5eERRVUZETEVOQlFVTXNUVUZCVFN4RFFVRkRMRVZCUVVVc1JVRkJSU3hoUVVGaExFTkJRVU1zUTBGQlF6dEpRVU5zUkRzN1FVRkZSQ3hWUVVGUExFbEJRVWtzUTBGQlF5eE5RVUZOTEVOQlFVTXNUMEZCVHl4RFFVRkRMRXRCUVVzc1JVRkJSU3hEUVVGRExFbEJRVWtzUTBGQlF5eERRVUZETEUxQlFVMHNRMEZCUXl4SlFVRkpMRWxCUVVrc1JVRkJSU3hEUVVGRExFTkJRVU1zUTBGQlF6dEhRVU0zUkRzN096czdPenM3T3pzN1UwRlZaU3d3UWtGQlF5eEhRVUZITEVWQlFVVTdRVUZEY2tJc1ZVRkJUeXhKUVVGSkxFTkJRVU1zVFVGQlRTeERRVUZETEVsQlFVa3NORUpCUVdsQ0xFZEJRVWNzUjBGQlJ5eEhRVUZITEVkQlFVY3NRMEZCUXl4SlFVRkpMREpDUVVGblFpeERRVUZETzBkQlF6RkZPenM3T3pzN096czdPenRUUVZWVExHOUNRVUZETEU5QlFVOHNSVUZCUlR0QlFVTnVRaXhWUVVGUExFOUJRVThzUjBGQlJ5eFZRVUZWTEVOQlFVTXNUMEZCVHl4RFFVRkRMRXRCUVVzc1EwRkJReXhMUVVGTExFTkJRVU1zUjBGQlJ5eERRVUZETEVOQlFVTTdSMEZEY2tRN096czdPenM3T3pzN08xTkJWVThzYTBKQlFVTXNUMEZCVHl4RlFVRkZMRXRCUVVzc1JVRkJSVHRCUVVONFFpeFJRVUZMTEVkQlFVY3NTMEZCU3l4RFFVRkRMRTlCUVU4c1EwRkJReXhEUVVGRExFTkJRVU1zUTBGQlF6dEJRVU42UWl4UlFVRkxMRWRCUVVjc1MwRkJTeXhIUVVGSExFTkJRVU1zUjBGQlJ5eExRVUZMTEVkQlFVY3NRMEZCUXl4RFFVRkRPMEZCUXpsQ0xFbEJRVU1zUTBGQlF5eFBRVUZQTEVOQlFVTXNRMEZCUXl4TFFVRkxMRU5CUVVNc1MwRkJTeXhEUVVGRExFTkJRVUU3UjBGRGRrSTdPenM3T3pzN096czdPenRUUVZkaExIZENRVUZETEV0QlFVc3NSVUZCUlR0QlFVTnlRaXhQUVVGSkxFbEJRVWtzUTBGQlF5eFBRVUZQTEVOQlFVTXNVVUZCVVN4SlFVRkpMRk5CUVZNc1JVRkJSVHRCUVVOMlF5eFRRVUZMTEVkQlFVY3NTVUZCU1N4RFFVRkRMRWRCUVVjc1EwRkJReXhKUVVGSkxFTkJRVU1zVDBGQlR5eERRVUZETEZGQlFWRXNSVUZCUlN4TFFVRkxMRU5CUVVNc1EwRkJRenRKUVVNdlF6czdRVUZGUkN4UFFVRkpMRWxCUVVrc1EwRkJReXhQUVVGUExFTkJRVU1zVVVGQlVTeEpRVUZKTEZOQlFWTXNSVUZCUlR0QlFVTjJReXhUUVVGTExFZEJRVWNzU1VGQlNTeERRVUZETEVkQlFVY3NRMEZCUXl4SlFVRkpMRU5CUVVNc1QwRkJUeXhEUVVGRExGRkJRVkVzUlVGQlJTeExRVUZMTEVOQlFVTXNRMEZCUXp0SlFVTXZRenM3UVVGRlJDeFZRVUZQTEV0QlFVc3NRMEZCUXp0SFFVTmlPenM3T3pzN096czdPenM3TzFOQldWVXNjVUpCUVVNc1MwRkJTeXhGUVVGRk8wRkJRMnhDTEU5QlFVa3NTMEZCU3l4RFFVRkRMRWxCUVVrc1EwRkJReXhQUVVGUExFTkJRVU1zVDBGQlR5eERRVUZETEV0QlFVc3NRMEZCUXl4RlFVRkZPMEZCUTNSRExGZEJRVThzUTBGQlF5eExRVUZMTEVOQlFVTXNZVUZCWVN4RFFVRkRMRTlCUVU4c1EwRkJReXhEUVVGRExFTkJRVU1zU1VGQlNTeExRVUZMTEVOQlFVTXNZVUZCWVN4RFFVRkRMR05CUVdNc1EwRkJReXhEUVVGRExFTkJRVU1zUTBGQlFTeERRVUZGTEV0QlFVc3NRMEZCUXp0SlFVTjJSanRCUVVORUxGVkJRVThzUzBGQlN5eERRVUZETEV0QlFVc3NRMEZCUXp0SFFVTnVRanM3TzFGQmNtUnRRaXhuUWtGQlowSTdPenR4UWtGQmFFSXNaMEpCUVdkQ096dEJRWGRrY2tNc1owSkJRV2RDTEVOQlFVTXNVVUZCVVN4SFFVRkhPMEZCUXpOQ0xGTkJRVkVzUlVGQlJTeHJRa0ZCVXl4TlFVRk5MRVZCUVVVN1FVRkRNVUlzVFVGQlJ5eE5RVUZOTEVOQlFVTXNTVUZCU1N4RFFVRkRMRTlCUVU4c1EwRkJReXhEUVVGRExFMUJRVTBzUlVGQlJUdEJRVU12UWl4cFEwRkJiVUk3UjBGRGJrSTdPMEZCUlVRc1owTkJRVzFDTzBWQlEyNUNPenRCUVVWRUxHZENRVUZsTEVWQlFVTXNTVUZCU1R0QlFVTndRaXhSUVVGUExFVkJRVU1zUTBGQlF6dEJRVU5VTEUxQlFVc3NSVUZCUlN4TlFVRk5MRU5CUVVNc1MwRkJTenRCUVVOdVFpeGhRVUZaTEVWQlFVVXNTVUZCU1R0QlFVTnNRaXhsUVVGakxFVkJRVVVzU1VGQlNUdEJRVU53UWl4VFFVRlJMRVZCUVVVc1NVRkJTVHRCUVVOa0xGTkJRVkVzUlVGQlJTeEpRVUZKTzBOQlEyUXNRMEZCUXpzN1FVRkZSaXhuUWtGQlowSXNRMEZCUXl4TFFVRkxMRWRCUVVjc1EwRkJReXhEUVVGRE96czdPenM3T3pzN1FVTndaMEp3UWl4SlFVRk5MRkZCUVZFc1IwRkJSeXhyUWtGQmEwSXNRMEZCUXpzN1FVRkRjRU1zU1VGQlRTeGxRVUZsTEVkQlFVY3NjMEpCUVhOQ0xFTkJRVU03TzBGQlF5OURMRWxCUVUwc1kwRkJZeXhIUVVGSExIRkNRVUZ4UWl4RFFVRkRPenRCUVVNM1F5eEpRVUZOTEU5QlFVOHNSMEZCUnl4SlFVRkpMRU5CUVVNN096dEJRVVZ5UWl4SlFVRk5MRzlDUVVGdlFpeEhRVUZITEcxQ1FVRnRRaXhEUVVGRE96dEJRVU5xUkN4SlFVRk5MSEZDUVVGeFFpeEhRVUZITEc5Q1FVRnZRaXhEUVVGRE96dEJRVU51UkN4SlFVRk5MRmxCUVZrc1IwRkJSeXhYUVVGWExFTkJRVU03TzBGQlEycERMRWxCUVUwc2MwSkJRWE5DTEVkQlFVY3NjVUpCUVhGQ0xFTkJRVU03T3p0QlFVVnlSQ3hKUVVGTkxHdENRVUZyUWl4SFFVRkhMSEZDUVVGeFFpeERRVUZET3p0QlFVTnFSQ3hKUVVGTkxGbEJRVmtzUjBGQlJ5eGxRVUZsTEVOQlFVTTdPMEZCUTNKRExFbEJRVTBzYVVKQlFXbENMRWRCUVVjc2IwSkJRVzlDTEVOQlFVTTdPenRCUVVVdlF5eEpRVUZOTEZkQlFWY3NSMEZCUnl4MVFrRkJkVUlzUTBGQlF6czdRVUZETlVNc1NVRkJUU3hYUVVGWExFZEJRVWNzZFVKQlFYVkNMRU5CUVVNN08wRkJRelZETEVsQlFVMHNiMEpCUVc5Q0xHOUNRVUZ2UWl4RFFVRkRPenM3T3pzN096czdPenM3Y1VKRGFFSjZRaXhUUVVGVE96czdPM1ZDUVVOc1FpeFhRVUZYSWl3aVptbHNaU0k2SW1kbGJtVnlZWFJsWkM1cWN5SXNJbk52ZFhKalpWSnZiM1FpT2lJaUxDSnpiM1Z5WTJWelEyOXVkR1Z1ZENJNld5SW9ablZ1WTNScGIyNGdaU2gwTEc0c2NpbDdablZ1WTNScGIyNGdjeWh2TEhVcGUybG1LQ0Z1VzI5ZEtYdHBaaWdoZEZ0dlhTbDdkbUZ5SUdFOWRIbHdaVzltSUhKbGNYVnBjbVU5UFZ3aVpuVnVZM1JwYjI1Y0lpWW1jbVZ4ZFdseVpUdHBaaWdoZFNZbVlTbHlaWFIxY200Z1lTaHZMQ0V3S1R0cFppaHBLWEpsZEhWeWJpQnBLRzhzSVRBcE8zWmhjaUJtUFc1bGR5QkZjbkp2Y2loY0lrTmhibTV2ZENCbWFXNWtJRzF2WkhWc1pTQW5YQ0lyYnl0Y0lpZGNJaWs3ZEdoeWIzY2daaTVqYjJSbFBWd2lUVTlFVlV4RlgwNVBWRjlHVDFWT1JGd2lMR1o5ZG1GeUlHdzlibHR2WFQxN1pYaHdiM0owY3pwN2ZYMDdkRnR2WFZzd1hTNWpZV3hzS0d3dVpYaHdiM0owY3l4bWRXNWpkR2x2YmlobEtYdDJZWElnYmoxMFcyOWRXekZkVzJWZE8zSmxkSFZ5YmlCektHNC9ianBsS1gwc2JDeHNMbVY0Y0c5eWRITXNaU3gwTEc0c2NpbDljbVYwZFhKdUlHNWJiMTB1Wlhod2IzSjBjMzEyWVhJZ2FUMTBlWEJsYjJZZ2NtVnhkV2x5WlQwOVhDSm1kVzVqZEdsdmJsd2lKaVp5WlhGMWFYSmxPMlp2Y2loMllYSWdiejB3TzI4OGNpNXNaVzVuZEdnN2J5c3JLWE1vY2x0dlhTazdjbVYwZFhKdUlITjlLU0lzSW1sdGNHOXlkQ0JTWlhOcGVtRmliR1ZEYjJ4MWJXNXpJR1p5YjIwZ0p5NHZZMnhoYzNNbk8xeHVhVzF3YjNKMElIdEVRVlJCWDBGUVNYMGdabkp2YlNBbkxpOWpiMjV6ZEdGdWRITW5PMXh1WEc0a0xtWnVMbkpsYzJsNllXSnNaVU52YkhWdGJuTWdQU0JtZFc1amRHbHZiaWh2Y0hScGIyNXpUM0pOWlhSb2IyUXNJQzR1TG1GeVozTXBJSHRjYmx4MGNtVjBkWEp1SUhSb2FYTXVaV0ZqYUNobWRXNWpkR2x2YmlncElIdGNibHgwWEhSc1pYUWdKSFJoWW14bElEMGdKQ2gwYUdsektUdGNibHh1WEhSY2RHeGxkQ0JoY0drZ1BTQWtkR0ZpYkdVdVpHRjBZU2hFUVZSQlgwRlFTU2s3WEc1Y2RGeDBhV1lnS0NGaGNHa3BJSHRjYmx4MFhIUmNkR0Z3YVNBOUlHNWxkeUJTWlhOcGVtRmliR1ZEYjJ4MWJXNXpLQ1IwWVdKc1pTd2diM0IwYVc5dWMwOXlUV1YwYUc5a0tUdGNibHgwWEhSY2RDUjBZV0pzWlM1a1lYUmhLRVJCVkVGZlFWQkpMQ0JoY0drcE8xeHVYSFJjZEgxY2JseHVYSFJjZEdWc2MyVWdhV1lnS0hSNWNHVnZaaUJ2Y0hScGIyNXpUM0pOWlhSb2IyUWdQVDA5SUNkemRISnBibWNuS1NCN1hHNWNkRngwWEhSeVpYUjFjbTRnWVhCcFcyOXdkR2x2Ym5OUGNrMWxkR2h2WkYwb0xpNHVZWEpuY3lrN1hHNWNkRngwZlZ4dVhIUjlLVHRjYm4wN1hHNWNiaVF1Y21WemFYcGhZbXhsUTI5c2RXMXVjeUE5SUZKbGMybDZZV0pzWlVOdmJIVnRibk03WEc0aUxDSnBiWEJ2Y25RZ2UxeHVYSFJFUVZSQlgwRlFTU3hjYmx4MFJFRlVRVjlEVDB4VlRVNVRYMGxFTEZ4dVhIUkVRVlJCWDBOUFRGVk5UbDlKUkN4Y2JseDBSRUZVUVY5VVNDeGNibHgwUTB4QlUxTmZWRUZDVEVWZlVrVlRTVnBKVGtjc1hHNWNkRU5NUVZOVFgwTlBURlZOVGw5U1JWTkpXa2xPUnl4Y2JseDBRMHhCVTFOZlNFRk9SRXhGTEZ4dVhIUkRURUZUVTE5SVFVNUVURVZmUTA5T1ZFRkpUa1ZTTEZ4dVhIUkZWa1ZPVkY5U1JWTkpXa1ZmVTFSQlVsUXNYRzVjZEVWV1JVNVVYMUpGVTBsYVJTeGNibHgwUlZaRlRsUmZVa1ZUU1ZwRlgxTlVUMUFzWEc1Y2RGTkZURVZEVkU5U1gxUklMRnh1WEhSVFJVeEZRMVJQVWw5VVJDeGNibHgwVTBWTVJVTlVUMUpmVlU1U1JWTkpXa0ZDVEVWY2JuMWNibVp5YjIwZ0p5NHZZMjl1YzNSaGJuUnpKenRjYmx4dUx5b3FYRzVVWVd0bGN5QmhJRHgwWVdKc1pTQXZQaUJsYkdWdFpXNTBJR0Z1WkNCdFlXdGxjeUJwZENkeklHTnZiSFZ0Ym5NZ2NtVnphWHBoWW14bElHRmpjbTl6Y3lCaWIzUm9YRzV0YjJKcGJHVWdZVzVrSUdSbGMydDBiM0FnWTJ4cFpXNTBjeTVjYmx4dVFHTnNZWE56SUZKbGMybDZZV0pzWlVOdmJIVnRibk5jYmtCd1lYSmhiU0FrZEdGaWJHVWdlMnBSZFdWeWVYMGdhbEYxWlhKNUxYZHlZWEJ3WldRZ1BIUmhZbXhsUGlCbGJHVnRaVzUwSUhSdklHMWhhMlVnY21WemFYcGhZbXhsWEc1QWNHRnlZVzBnYjNCMGFXOXVjeUI3VDJKcVpXTjBmU0JEYjI1bWFXZDFjbUYwYVc5dUlHOWlhbVZqZEZ4dUtpb3ZYRzVsZUhCdmNuUWdaR1ZtWVhWc2RDQmpiR0Z6Y3lCU1pYTnBlbUZpYkdWRGIyeDFiVzV6SUh0Y2JseDBZMjl1YzNSeWRXTjBiM0lvSkhSaFlteGxMQ0J2Y0hScGIyNXpLU0I3WEc1Y2RGeDBkR2hwY3k1dWN5QTlJQ2N1Y21NbklDc2dkR2hwY3k1amIzVnVkQ3NyTzF4dVhIUmNkSFJvYVhNdWIzSnBaMmx1WVd4VVlXSnNaVXhoZVc5MWRDQTlJQ1IwWVdKc1pTNWpjM01vSjNSaFlteGxMV3hoZVc5MWRDY3BYRzVjZEZ4MGRHaHBjeTV2Y0hScGIyNXpJRDBnSkM1bGVIUmxibVFvZTMwc0lGSmxjMmw2WVdKc1pVTnZiSFZ0Ym5NdVpHVm1ZWFZzZEhNc0lHOXdkR2x2Ym5NcE8xeHVYRzVjZEZ4MGRHaHBjeTRrZDJsdVpHOTNJRDBnSkNoM2FXNWtiM2NwTzF4dVhIUmNkSFJvYVhNdUpHOTNibVZ5Ukc5amRXMWxiblFnUFNBa0tDUjBZV0pzWlZzd1hTNXZkMjVsY2tSdlkzVnRaVzUwS1R0Y2JseDBYSFIwYUdsekxpUjBZV0pzWlNBOUlDUjBZV0pzWlR0Y2JseHVYSFJjZEhSb2FYTXVjbVZtY21WemFFaGxZV1JsY25Nb0tUdGNibHgwWEhSMGFHbHpMbkpsYzNSdmNtVkRiMngxYlc1WGFXUjBhSE1vS1R0Y2JseDBYSFIwYUdsekxuTjVibU5JWVc1a2JHVlhhV1IwYUhNb0tUdGNibHh1WEhSY2RIUm9hWE11WW1sdVpFVjJaVzUwY3loMGFHbHpMaVIzYVc1a2IzY3NJQ2R5WlhOcGVtVW5MQ0IwYUdsekxuTjVibU5JWVc1a2JHVlhhV1IwYUhNdVltbHVaQ2gwYUdsektTazdYRzVjYmx4MFhIUnBaaUFvZEdocGN5NXZjSFJwYjI1ekxuTjBZWEowS1NCN1hHNWNkRngwWEhSMGFHbHpMbUpwYm1SRmRtVnVkSE1vZEdocGN5NGtkR0ZpYkdVc0lFVldSVTVVWDFKRlUwbGFSVjlUVkVGU1ZDd2dkR2hwY3k1dmNIUnBiMjV6TG5OMFlYSjBLVHRjYmx4MFhIUjlYRzVjZEZ4MGFXWWdLSFJvYVhNdWIzQjBhVzl1Y3k1eVpYTnBlbVVwSUh0Y2JseDBYSFJjZEhSb2FYTXVZbWx1WkVWMlpXNTBjeWgwYUdsekxpUjBZV0pzWlN3Z1JWWkZUbFJmVWtWVFNWcEZMQ0IwYUdsekxtOXdkR2x2Ym5NdWNtVnphWHBsS1R0Y2JseDBYSFI5WEc1Y2RGeDBhV1lnS0hSb2FYTXViM0IwYVc5dWN5NXpkRzl3S1NCN1hHNWNkRngwWEhSMGFHbHpMbUpwYm1SRmRtVnVkSE1vZEdocGN5NGtkR0ZpYkdVc0lFVldSVTVVWDFKRlUwbGFSVjlUVkU5UUxDQjBhR2x6TG05d2RHbHZibk11YzNSdmNDazdYRzVjZEZ4MGZWeHVYSFI5WEc1Y2JseDBMeW9xWEc1Y2RGSmxabkpsYzJobGN5QjBhR1VnYUdWaFpHVnljeUJoYzNOdlkybGhkR1ZrSUhkcGRHZ2dkR2hwY3lCcGJuTjBZVzVqWlhNZ1BIUmhZbXhsTHo0Z1pXeGxiV1Z1ZENCaGJtUmNibHgwWjJWdVpYSmhkR1Z6SUdoaGJtUnNaWE1nWm05eUlIUm9aVzB1SUVGc2MyOGdZWE56YVdkdWN5QndaWEpqWlc1MFlXZGxJSGRwWkhSb2N5NWNibHh1WEhSQWJXVjBhRzlrSUhKbFpuSmxjMmhJWldGa1pYSnpYRzVjZENvcUwxeHVYSFJ5WldaeVpYTm9TR1ZoWkdWeWN5Z3BJSHRjYmx4MFhIUXZMeUJCYkd4dmR5QjBhR1VnYzJWc1pXTjBiM0lnZEc4Z1ltVWdZbTkwYUNCaElISmxaM1ZzWVhJZ2MyVnNZM1J2Y2lCemRISnBibWNnWVhNZ2QyVnNiQ0JoYzF4dVhIUmNkQzh2SUdFZ1pIbHVZVzFwWXlCallXeHNZbUZqYTF4dVhIUmNkR3hsZENCelpXeGxZM1J2Y2lBOUlIUm9hWE11YjNCMGFXOXVjeTV6Wld4bFkzUnZjanRjYmx4MFhIUnBaaWgwZVhCbGIyWWdjMlZzWldOMGIzSWdQVDA5SUNkbWRXNWpkR2x2YmljcElIdGNibHgwWEhSY2RITmxiR1ZqZEc5eUlEMGdjMlZzWldOMGIzSXVZMkZzYkNoMGFHbHpMQ0IwYUdsekxpUjBZV0pzWlNrN1hHNWNkRngwZlZ4dVhHNWNkRngwTHk4Z1UyVnNaV04wSUdGc2JDQjBZV0pzWlNCb1pXRmtaWEp6WEc1Y2RGeDBkR2hwY3k0a2RHRmliR1ZJWldGa1pYSnpJRDBnZEdocGN5NGtkR0ZpYkdVdVptbHVaQ2h6Wld4bFkzUnZjaWs3WEc1Y2JseDBYSFF2THlCQmMzTnBaMjRnY0dWeVkyVnVkR0ZuWlNCM2FXUjBhSE1nWm1seWMzUXNJSFJvWlc0Z1kzSmxZWFJsSUdSeVlXY2dhR0Z1Wkd4bGMxeHVYSFJjZEhSb2FYTXVZWE56YVdkdVVHVnlZMlZ1ZEdGblpWZHBaSFJvY3lncE8xeHVYSFJjZEhSb2FYTXVZM0psWVhSbFNHRnVaR3hsY3lncE8xeHVYRzVjZEZ4MEx5OW1hWGhsWkNCMFlXSnNaVnh1WEhSY2RIUm9hWE11SkhSaFlteGxMbU56Y3loY0luUmhZbXhsTFd4aGVXOTFkRndpTEZ3aVptbDRaV1JjSWlsY2JseDBmVnh1WEc1Y2RDOHFLbHh1WEhSRGNtVmhkR1Z6SUdSMWJXMTVJR2hoYm1Sc1pTQmxiR1Z0Wlc1MGN5Qm1iM0lnWVd4c0lIUmhZbXhsSUdobFlXUmxjaUJqYjJ4MWJXNXpYRzVjYmx4MFFHMWxkR2h2WkNCamNtVmhkR1ZJWVc1a2JHVnpYRzVjZENvcUwxeHVYSFJqY21WaGRHVklZVzVrYkdWektDa2dlMXh1WEhSY2RHeGxkQ0J5WldZZ1BTQjBhR2x6TGlSb1lXNWtiR1ZEYjI1MFlXbHVaWEk3WEc1Y2RGeDBhV1lnS0hKbFppQWhQU0J1ZFd4c0tTQjdYRzVjZEZ4MFhIUnlaV1l1Y21WdGIzWmxLQ2s3WEc1Y2RGeDBmVnh1WEc1Y2RGeDBkR2hwY3k0a2FHRnVaR3hsUTI5dWRHRnBibVZ5SUQwZ0pDaGdQR1JwZGlCamJHRnpjejBuSkh0RFRFRlRVMTlJUVU1RVRFVmZRMDlPVkVGSlRrVlNmU2NnTHo1Z0tWeHVYSFJjZEhSb2FYTXViM0IwYVc5dWN5NW9ZVzVrYkdWRGIyNTBZV2x1WlhJZ1B5QjBhR2x6TG05d2RHbHZibk11YUdGdVpHeGxRMjl1ZEdGcGJtVnlMbUpsWm05eVpTaDBhR2x6TGlSb1lXNWtiR1ZEYjI1MFlXbHVaWElwSURvZ2RHaHBjeTRrZEdGaWJHVXVZbVZtYjNKbEtIUm9hWE11SkdoaGJtUnNaVU52Ym5SaGFXNWxjaWs3WEc1Y2JseDBYSFIwYUdsekxpUjBZV0pzWlVobFlXUmxjbk11WldGamFDZ29hU3dnWld3cElEMCtJSHRjYmx4MFhIUmNkR3hsZENBa1kzVnljbVZ1ZENBOUlIUm9hWE11SkhSaFlteGxTR1ZoWkdWeWN5NWxjU2hwS1R0Y2JseDBYSFJjZEd4bGRDQWtibVY0ZENBOUlIUm9hWE11SkhSaFlteGxTR1ZoWkdWeWN5NWxjU2hwSUNzZ01TazdYRzVjYmx4MFhIUmNkR2xtSUNna2JtVjRkQzVzWlc1bmRHZ2dQVDA5SURBZ2ZId2dKR04xY25KbGJuUXVhWE1vVTBWTVJVTlVUMUpmVlU1U1JWTkpXa0ZDVEVVcElIeDhJQ1J1WlhoMExtbHpLRk5GVEVWRFZFOVNYMVZPVWtWVFNWcEJRa3hGS1NrZ2UxeHVYSFJjZEZ4MFhIUnlaWFIxY200N1hHNWNkRngwWEhSOVhHNWNibHgwWEhSY2RHeGxkQ0FrYUdGdVpHeGxJRDBnSkNoZ1BHUnBkaUJqYkdGemN6MG5KSHREVEVGVFUxOUlRVTVFVEVWOUp5QXZQbUFwWEc1Y2RGeDBYSFJjZEM1a1lYUmhLRVJCVkVGZlZFZ3NJQ1FvWld3cEtWeHVYSFJjZEZ4MFhIUXVZWEJ3Wlc1a1ZHOG9kR2hwY3k0a2FHRnVaR3hsUTI5dWRHRnBibVZ5S1R0Y2JseDBYSFI5S1R0Y2JseHVYSFJjZEhSb2FYTXVZbWx1WkVWMlpXNTBjeWgwYUdsekxpUm9ZVzVrYkdWRGIyNTBZV2x1WlhJc0lGc25iVzkxYzJWa2IzZHVKeXdnSjNSdmRXTm9jM1JoY25RblhTd2dKeTRuSzBOTVFWTlRYMGhCVGtSTVJTd2dkR2hwY3k1dmJsQnZhVzUwWlhKRWIzZHVMbUpwYm1Rb2RHaHBjeWtwTzF4dVhIUjlYRzVjYmx4MEx5b3FYRzVjZEVGemMybG5ibk1nWVNCd1pYSmpaVzUwWVdkbElIZHBaSFJvSUhSdklHRnNiQ0JqYjJ4MWJXNXpJR0poYzJWa0lHOXVJSFJvWldseUlHTjFjbkpsYm5RZ2NHbDRaV3dnZDJsa2RHZ29jeWxjYmx4dVhIUkFiV1YwYUc5a0lHRnpjMmxuYmxCbGNtTmxiblJoWjJWWGFXUjBhSE5jYmx4MEtpb3ZYRzVjZEdGemMybG5ibEJsY21ObGJuUmhaMlZYYVdSMGFITW9LU0I3WEc1Y2RGeDBkR2hwY3k0a2RHRmliR1ZJWldGa1pYSnpMbVZoWTJnb0tGOHNJR1ZzS1NBOVBpQjdYRzVjZEZ4MFhIUnNaWFFnSkdWc0lEMGdKQ2hsYkNrN1hHNWNkRngwWEhSMGFHbHpMbk5sZEZkcFpIUm9LQ1JsYkZzd1hTd2dKR1ZzTG05MWRHVnlWMmxrZEdnb0tTc2dkR2hwY3k1dmNIUnBiMjV6TG5CaFpHUnBibWNwTzF4dVhIUmNkSDBwTzF4dVhIUjlYRzVjYmx4MEx5b3FYRzVjYmx4dVhIUkFiV1YwYUc5a0lITjVibU5JWVc1a2JHVlhhV1IwYUhOY2JseDBLaW92WEc1Y2RITjVibU5JWVc1a2JHVlhhV1IwYUhNb0tTQjdYRzVjZEZ4MGJHVjBJQ1JqYjI1MFlXbHVaWElnUFNCMGFHbHpMaVJvWVc1a2JHVkRiMjUwWVdsdVpYSmNibHh1WEhSY2RDUmpiMjUwWVdsdVpYSXVkMmxrZEdnb2RHaHBjeTRrZEdGaWJHVXVkMmxrZEdnb0tTazdYRzVjYmx4MFhIUWtZMjl1ZEdGcGJtVnlMbVpwYm1Rb0p5NG5LME5NUVZOVFgwaEJUa1JNUlNrdVpXRmphQ2dvWHl3Z1pXd3BJRDArSUh0Y2JseDBYSFJjZEd4bGRDQWtaV3dnUFNBa0tHVnNLVHRjYmx4dVhIUmNkRngwYkdWMElHaGxhV2RvZENBOUlIUm9hWE11YjNCMGFXOXVjeTV5WlhOcGVtVkdjbTl0UW05a2VTQS9YRzVjZEZ4MFhIUmNkSFJvYVhNdUpIUmhZbXhsTG1obGFXZG9kQ2dwSURwY2JseDBYSFJjZEZ4MGRHaHBjeTRrZEdGaWJHVXVabWx1WkNnbmRHaGxZV1FuS1M1b1pXbG5hSFFvS1R0Y2JseHVYSFJjZEZ4MGJHVjBJR3hsWm5RZ1BTQWtaV3d1WkdGMFlTaEVRVlJCWDFSSUtTNXZkWFJsY2xkcFpIUm9LQ2tnS3lBb1hHNWNkRngwWEhSY2RDUmxiQzVrWVhSaEtFUkJWRUZmVkVncExtOW1abk5sZENncExteGxablFnTFNCMGFHbHpMaVJvWVc1a2JHVkRiMjUwWVdsdVpYSXViMlptYzJWMEtDa3ViR1ZtZEZ4dVhIUmNkRngwS1R0Y2JseHVYSFJjZEZ4MEpHVnNMbU56Y3loN0lHeGxablFzSUdobGFXZG9kQ0I5S1R0Y2JseDBYSFI5S1R0Y2JseDBmVnh1WEc1Y2RDOHFLbHh1WEhSUVpYSnphWE4wY3lCMGFHVWdZMjlzZFcxdUlIZHBaSFJvY3lCcGJpQnNiMk5oYkZOMGIzSmhaMlZjYmx4dVhIUkFiV1YwYUc5a0lITmhkbVZEYjJ4MWJXNVhhV1IwYUhOY2JseDBLaW92WEc1Y2RITmhkbVZEYjJ4MWJXNVhhV1IwYUhNb0tTQjdYRzVjZEZ4MGRHaHBjeTRrZEdGaWJHVklaV0ZrWlhKekxtVmhZMmdvS0Y4c0lHVnNLU0E5UGlCN1hHNWNkRngwWEhSc1pYUWdKR1ZzSUQwZ0pDaGxiQ2s3WEc1Y2JseDBYSFJjZEdsbUlDaDBhR2x6TG05d2RHbHZibk11YzNSdmNtVWdKaVlnSVNSbGJDNXBjeWhUUlV4RlExUlBVbDlWVGxKRlUwbGFRVUpNUlNrcElIdGNibHgwWEhSY2RGeDBkR2hwY3k1dmNIUnBiMjV6TG5OMGIzSmxMbk5sZENoY2JseDBYSFJjZEZ4MFhIUjBhR2x6TG1kbGJtVnlZWFJsUTI5c2RXMXVTV1FvSkdWc0tTeGNibHgwWEhSY2RGeDBYSFIwYUdsekxuQmhjbk5sVjJsa2RHZ29aV3dwWEc1Y2RGeDBYSFJjZENrN1hHNWNkRngwWEhSOVhHNWNkRngwZlNrN1hHNWNkSDFjYmx4dVhIUXZLaXBjYmx4MFVtVjBjbWxsZG1WeklHRnVaQ0J6WlhSeklIUm9aU0JqYjJ4MWJXNGdkMmxrZEdoeklHWnliMjBnYkc5allXeFRkRzl5WVdkbFhHNWNibHgwUUcxbGRHaHZaQ0J5WlhOMGIzSmxRMjlzZFcxdVYybGtkR2h6WEc1Y2RDb3FMMXh1WEhSeVpYTjBiM0psUTI5c2RXMXVWMmxrZEdoektDa2dlMXh1WEhSY2RIUm9hWE11SkhSaFlteGxTR1ZoWkdWeWN5NWxZV05vS0NoZkxDQmxiQ2tnUFQ0Z2UxeHVYSFJjZEZ4MGJHVjBJQ1JsYkNBOUlDUW9aV3dwTzF4dVhHNWNkRngwWEhScFppaDBhR2x6TG05d2RHbHZibk11YzNSdmNtVWdKaVlnSVNSbGJDNXBjeWhUUlV4RlExUlBVbDlWVGxKRlUwbGFRVUpNUlNrcElIdGNibHgwWEhSY2RGeDBiR1YwSUhkcFpIUm9JRDBnZEdocGN5NXZjSFJwYjI1ekxuTjBiM0psTG1kbGRDaGNibHgwWEhSY2RGeDBYSFIwYUdsekxtZGxibVZ5WVhSbFEyOXNkVzF1U1dRb0pHVnNLVnh1WEhSY2RGeDBYSFFwTzF4dVhHNWNkRngwWEhSY2RHbG1LSGRwWkhSb0lDRTlJRzUxYkd3cElIdGNibHgwWEhSY2RGeDBYSFIwYUdsekxuTmxkRmRwWkhSb0tHVnNMQ0IzYVdSMGFDazdYRzVjZEZ4MFhIUmNkSDFjYmx4MFhIUmNkSDFjYmx4MFhIUjlLVHRjYmx4MGZWeHVYRzVjZEM4cUtseHVYSFJRYjJsdWRHVnlMMjF2ZFhObElHUnZkMjRnYUdGdVpHeGxjbHh1WEc1Y2RFQnRaWFJvYjJRZ2IyNVFiMmx1ZEdWeVJHOTNibHh1WEhSQWNHRnlZVzBnWlhabGJuUWdlMDlpYW1WamRIMGdSWFpsYm5RZ2IySnFaV04wSUdGemMyOWphV0YwWldRZ2QybDBhQ0IwYUdVZ2FXNTBaWEpoWTNScGIyNWNibHgwS2lvdlhHNWNkRzl1VUc5cGJuUmxja1J2ZDI0b1pYWmxiblFwSUh0Y2JseDBYSFF2THlCUGJteDVJR0Z3Y0d4cFpYTWdkRzhnYkdWbWRDMWpiR2xqYXlCa2NtRm5aMmx1WjF4dVhIUmNkR2xtS0dWMlpXNTBMbmRvYVdOb0lDRTlQU0F4S1NCN0lISmxkSFZ5YmpzZ2ZWeHVYRzVjZEZ4MEx5OGdTV1lnWVNCd2NtVjJhVzkxY3lCdmNHVnlZWFJwYjI0Z2FYTWdaR1ZtYVc1bFpDd2dkMlVnYldsemMyVmtJSFJvWlNCc1lYTjBJRzF2ZFhObGRYQXVYRzVjZEZ4MEx5OGdVSEp2WW1GaWJIa2daMjlpWW14bFpDQjFjQ0JpZVNCMWMyVnlJRzF2ZFhOcGJtY2diM1YwSUhSb1pTQjNhVzVrYjNjZ2RHaGxiaUJ5Wld4bFlYTnBibWN1WEc1Y2RGeDBMeThnVjJVbmJHd2djMmx0ZFd4aGRHVWdZU0J3YjJsdWRHVnlkWEFnYUdWeVpTQndjbWx2Y2lCMGJ5QnBkRnh1WEhSY2RHbG1LSFJvYVhNdWIzQmxjbUYwYVc5dUtTQjdYRzVjZEZ4MFhIUjBhR2x6TG05dVVHOXBiblJsY2xWd0tHVjJaVzUwS1R0Y2JseDBYSFI5WEc1Y2JseDBYSFF2THlCSloyNXZjbVVnYm05dUxYSmxjMmw2WVdKc1pTQmpiMngxYlc1elhHNWNkRngwYkdWMElDUmpkWEp5Wlc1MFIzSnBjQ0E5SUNRb1pYWmxiblF1WTNWeWNtVnVkRlJoY21kbGRDazdYRzVjZEZ4MGFXWW9KR04xY25KbGJuUkhjbWx3TG1sektGTkZURVZEVkU5U1gxVk9Va1ZUU1ZwQlFreEZLU2tnZTF4dVhIUmNkRngwY21WMGRYSnVPMXh1WEhSY2RIMWNibHh1WEhSY2RHeGxkQ0JuY21sd1NXNWtaWGdnUFNBa1kzVnljbVZ1ZEVkeWFYQXVhVzVrWlhnb0tUdGNibHgwWEhSc1pYUWdKR3hsWm5SRGIyeDFiVzRnUFNCMGFHbHpMaVIwWVdKc1pVaGxZV1JsY25NdVpYRW9aM0pwY0VsdVpHVjRLUzV1YjNRb1UwVk1SVU5VVDFKZlZVNVNSVk5KV2tGQ1RFVXBPMXh1WEhSY2RHeGxkQ0FrY21sbmFIUkRiMngxYlc0Z1BTQjBhR2x6TGlSMFlXSnNaVWhsWVdSbGNuTXVaWEVvWjNKcGNFbHVaR1Y0SUNzZ01Ta3VibTkwS0ZORlRFVkRWRTlTWDFWT1VrVlRTVnBCUWt4RktUdGNibHh1WEhSY2RHeGxkQ0JzWldaMFYybGtkR2dnUFNCMGFHbHpMbkJoY25ObFYybGtkR2dvSkd4bFpuUkRiMngxYlc1Yk1GMHBPMXh1WEhSY2RHeGxkQ0J5YVdkb2RGZHBaSFJvSUQwZ2RHaHBjeTV3WVhKelpWZHBaSFJvS0NSeWFXZG9kRU52YkhWdGJsc3dYU2s3WEc1Y2JseDBYSFIwYUdsekxtOXdaWEpoZEdsdmJpQTlJSHRjYmx4MFhIUmNkQ1JzWldaMFEyOXNkVzF1TENBa2NtbG5hSFJEYjJ4MWJXNHNJQ1JqZFhKeVpXNTBSM0pwY0N4Y2JseHVYSFJjZEZ4MGMzUmhjblJZT2lCMGFHbHpMbWRsZEZCdmFXNTBaWEpZS0dWMlpXNTBLU3hjYmx4dVhIUmNkRngwZDJsa2RHaHpPaUI3WEc1Y2RGeDBYSFJjZEd4bFpuUTZJR3hsWm5SWGFXUjBhQ3hjYmx4MFhIUmNkRngwY21sbmFIUTZJSEpwWjJoMFYybGtkR2hjYmx4MFhIUmNkSDBzWEc1Y2RGeDBYSFJ1WlhkWGFXUjBhSE02SUh0Y2JseDBYSFJjZEZ4MGJHVm1kRG9nYkdWbWRGZHBaSFJvTEZ4dVhIUmNkRngwWEhSeWFXZG9kRG9nY21sbmFIUlhhV1IwYUZ4dVhIUmNkRngwZlZ4dVhIUmNkSDA3WEc1Y2JseDBYSFIwYUdsekxtSnBibVJGZG1WdWRITW9kR2hwY3k0a2IzZHVaWEpFYjJOMWJXVnVkQ3dnV3lkdGIzVnpaVzF2ZG1VbkxDQW5kRzkxWTJodGIzWmxKMTBzSUhSb2FYTXViMjVRYjJsdWRHVnlUVzkyWlM1aWFXNWtLSFJvYVhNcEtUdGNibHgwWEhSMGFHbHpMbUpwYm1SRmRtVnVkSE1vZEdocGN5NGtiM2R1WlhKRWIyTjFiV1Z1ZEN3Z1d5ZHRiM1Z6WlhWd0p5d2dKM1J2ZFdOb1pXNWtKMTBzSUhSb2FYTXViMjVRYjJsdWRHVnlWWEF1WW1sdVpDaDBhR2x6S1NrN1hHNWNibHgwWEhSMGFHbHpMaVJvWVc1a2JHVkRiMjUwWVdsdVpYSmNibHgwWEhSY2RDNWhaR1FvZEdocGN5NGtkR0ZpYkdVcFhHNWNkRngwWEhRdVlXUmtRMnhoYzNNb1EweEJVMU5mVkVGQ1RFVmZVa1ZUU1ZwSlRrY3BPMXh1WEc1Y2RGeDBKR3hsWm5SRGIyeDFiVzVjYmx4MFhIUmNkQzVoWkdRb0pISnBaMmgwUTI5c2RXMXVLVnh1WEhSY2RGeDBMbUZrWkNna1kzVnljbVZ1ZEVkeWFYQXBYRzVjZEZ4MFhIUXVZV1JrUTJ4aGMzTW9RMHhCVTFOZlEwOU1WVTFPWDFKRlUwbGFTVTVIS1R0Y2JseHVYSFJjZEhSb2FYTXVkSEpwWjJkbGNrVjJaVzUwS0VWV1JVNVVYMUpGVTBsYVJWOVRWRUZTVkN3Z1cxeHVYSFJjZEZ4MEpHeGxablJEYjJ4MWJXNHNJQ1J5YVdkb2RFTnZiSFZ0Yml4Y2JseDBYSFJjZEd4bFpuUlhhV1IwYUN3Z2NtbG5hSFJYYVdSMGFGeHVYSFJjZEYwc1hHNWNkRngwWlhabGJuUXBPMXh1WEc1Y2RGeDBaWFpsYm5RdWNISmxkbVZ1ZEVSbFptRjFiSFFvS1R0Y2JseDBmVnh1WEc1Y2RDOHFLbHh1WEhSUWIybHVkR1Z5TDIxdmRYTmxJRzF2ZG1WdFpXNTBJR2hoYm1Sc1pYSmNibHh1WEhSQWJXVjBhRzlrSUc5dVVHOXBiblJsY2sxdmRtVmNibHgwUUhCaGNtRnRJR1YyWlc1MElIdFBZbXBsWTNSOUlFVjJaVzUwSUc5aWFtVmpkQ0JoYzNOdlkybGhkR1ZrSUhkcGRHZ2dkR2hsSUdsdWRHVnlZV04wYVc5dVhHNWNkQ29xTDF4dVhIUnZibEJ2YVc1MFpYSk5iM1psS0dWMlpXNTBLU0I3WEc1Y2RGeDBiR1YwSUc5d0lEMGdkR2hwY3k1dmNHVnlZWFJwYjI0N1hHNWNkRngwYVdZb0lYUm9hWE11YjNCbGNtRjBhVzl1S1NCN0lISmxkSFZ5YmpzZ2ZWeHVYRzVjZEZ4MEx5OGdSR1YwWlhKdGFXNWxJSFJvWlNCa1pXeDBZU0JqYUdGdVoyVWdZbVYwZDJWbGJpQnpkR0Z5ZENCaGJtUWdibVYzSUcxdmRYTmxJSEJ2YzJsMGFXOXVMQ0JoY3lCaElIQmxjbU5sYm5SaFoyVWdiMllnZEdobElIUmhZbXhsSUhkcFpIUm9YRzVjZEZ4MGJHVjBJR1JwWm1abGNtVnVZMlVnUFNCMGFHbHpMbWRsZEZCdmFXNTBaWEpZS0dWMlpXNTBLU0F0SUc5d0xuTjBZWEowV0R0Y2JseDBYSFJwWmloa2FXWm1aWEpsYm1ObElEMDlQU0F3S1NCN1hHNWNkRngwWEhSeVpYUjFjbTQ3WEc1Y2RGeDBmVnh1WEc1Y2RGeDBiR1YwSUd4bFpuUkRiMngxYlc0Z1BTQnZjQzRrYkdWbWRFTnZiSFZ0Ymxzd1hUdGNibHgwWEhSc1pYUWdjbWxuYUhSRGIyeDFiVzRnUFNCdmNDNGtjbWxuYUhSRGIyeDFiVzViTUYwN1hHNWNkRngwYkdWMElIZHBaSFJvVEdWbWRDd2dkMmxrZEdoU2FXZG9kRHRjYmx4dVhIUmNkSGRwWkhSb1RHVm1kQ0E5SUhSb2FYTXVZMjl1YzNSeVlXbHVWMmxrZEdnb2IzQXVkMmxrZEdoekxteGxablFnS3lCa2FXWm1aWEpsYm1ObEtUdGNibHgwWEhSM2FXUjBhRkpwWjJoMElEMGdkR2hwY3k1amIyNXpkSEpoYVc1WGFXUjBhQ2h2Y0M1M2FXUjBhSE11Y21sbmFIUXBPMXh1WEc1Y2RGeDBhV1lvYkdWbWRFTnZiSFZ0YmlrZ2UxeHVYSFJjZEZ4MGRHaHBjeTV6WlhSWGFXUjBhQ2hzWldaMFEyOXNkVzF1TENCM2FXUjBhRXhsWm5RcE8xeHVYSFJjZEgxY2JseDBYSFJwWmloeWFXZG9kRU52YkhWdGJpa2dlMXh1WEhSY2RGeDBkR2hwY3k1elpYUlhhV1IwYUNoeWFXZG9kRU52YkhWdGJpd2dkMmxrZEdoU2FXZG9kQ2s3WEc1Y2RGeDBmVnh1WEc1Y2RGeDBiM0F1Ym1WM1YybGtkR2h6TG14bFpuUWdQU0IzYVdSMGFFeGxablE3WEc1Y2RGeDBiM0F1Ym1WM1YybGtkR2h6TG5KcFoyaDBJRDBnZDJsa2RHaFNhV2RvZER0Y2JseHVYSFJjZEhKbGRIVnliaUIwYUdsekxuUnlhV2RuWlhKRmRtVnVkQ2hGVmtWT1ZGOVNSVk5KV2tVc0lGdGNibHgwWEhSY2RHOXdMaVJzWldaMFEyOXNkVzF1TENCdmNDNGtjbWxuYUhSRGIyeDFiVzRzWEc1Y2RGeDBYSFIzYVdSMGFFeGxablFzSUhkcFpIUm9VbWxuYUhSY2JseDBYSFJkTEZ4dVhIUmNkR1YyWlc1MEtUdGNibHgwZlZ4dVhHNWNkQzhxS2x4dVhIUlFiMmx1ZEdWeUwyMXZkWE5sSUhKbGJHVmhjMlVnYUdGdVpHeGxjbHh1WEc1Y2RFQnRaWFJvYjJRZ2IyNVFiMmx1ZEdWeVZYQmNibHgwUUhCaGNtRnRJR1YyWlc1MElIdFBZbXBsWTNSOUlFVjJaVzUwSUc5aWFtVmpkQ0JoYzNOdlkybGhkR1ZrSUhkcGRHZ2dkR2hsSUdsdWRHVnlZV04wYVc5dVhHNWNkQ29xTDF4dVhIUnZibEJ2YVc1MFpYSlZjQ2hsZG1WdWRDa2dlMXh1WEhSY2RHeGxkQ0J2Y0NBOUlIUm9hWE11YjNCbGNtRjBhVzl1TzF4dVhIUmNkR2xtS0NGMGFHbHpMbTl3WlhKaGRHbHZiaWtnZXlCeVpYUjFjbTQ3SUgxY2JseHVYSFJjZEhSb2FYTXVkVzVpYVc1a1JYWmxiblJ6S0hSb2FYTXVKRzkzYm1WeVJHOWpkVzFsYm5Rc0lGc25iVzkxYzJWMWNDY3NJQ2QwYjNWamFHVnVaQ2NzSUNkdGIzVnpaVzF2ZG1VbkxDQW5kRzkxWTJodGIzWmxKMTBwTzF4dVhHNWNkRngwZEdocGN5NGthR0Z1Wkd4bFEyOXVkR0ZwYm1WeVhHNWNkRngwWEhRdVlXUmtLSFJvYVhNdUpIUmhZbXhsS1Z4dVhIUmNkRngwTG5KbGJXOTJaVU5zWVhOektFTk1RVk5UWDFSQlFreEZYMUpGVTBsYVNVNUhLVHRjYmx4dVhIUmNkRzl3TGlSc1pXWjBRMjlzZFcxdVhHNWNkRngwWEhRdVlXUmtLRzl3TGlSeWFXZG9kRU52YkhWdGJpbGNibHgwWEhSY2RDNWhaR1FvYjNBdUpHTjFjbkpsYm5SSGNtbHdLVnh1WEhSY2RGeDBMbkpsYlc5MlpVTnNZWE56S0VOTVFWTlRYME5QVEZWTlRsOVNSVk5KV2tsT1J5azdYRzVjYmx4MFhIUjBhR2x6TG5ONWJtTklZVzVrYkdWWGFXUjBhSE1vS1R0Y2JseDBYSFIwYUdsekxuTmhkbVZEYjJ4MWJXNVhhV1IwYUhNb0tUdGNibHh1WEhSY2RIUm9hWE11YjNCbGNtRjBhVzl1SUQwZ2JuVnNiRHRjYmx4dVhIUmNkSEpsZEhWeWJpQjBhR2x6TG5SeWFXZG5aWEpGZG1WdWRDaEZWa1ZPVkY5U1JWTkpXa1ZmVTFSUFVDd2dXMXh1WEhSY2RGeDBiM0F1Skd4bFpuUkRiMngxYlc0c0lHOXdMaVJ5YVdkb2RFTnZiSFZ0Yml4Y2JseDBYSFJjZEc5d0xtNWxkMWRwWkhSb2N5NXNaV1owTENCdmNDNXVaWGRYYVdSMGFITXVjbWxuYUhSY2JseDBYSFJkTEZ4dVhIUmNkR1YyWlc1MEtUdGNibHgwZlZ4dVhHNWNkQzhxS2x4dVhIUlNaVzF2ZG1WeklHRnNiQ0JsZG1WdWRDQnNhWE4wWlc1bGNuTXNJR1JoZEdFc0lHRnVaQ0JoWkdSbFpDQkVUMDBnWld4bGJXVnVkSE11SUZSaGEyVnpYRzVjZEhSb1pTQThkR0ZpYkdVdlBpQmxiR1Z0Wlc1MElHSmhZMnNnZEc4Z2FHOTNJR2wwSUhkaGN5d2dZVzVrSUhKbGRIVnlibk1nYVhSY2JseHVYSFJBYldWMGFHOWtJR1JsYzNSeWIzbGNibHgwUUhKbGRIVnliaUI3YWxGMVpYSjVmU0JQY21sbmFXNWhiQ0JxVVhWbGNua3RkM0poY0hCbFpDQThkR0ZpYkdVK0lHVnNaVzFsYm5SY2JseDBLaW92WEc1Y2RHUmxjM1J5YjNrb0tTQjdYRzVjZEZ4MGJHVjBJQ1IwWVdKc1pTQTlJSFJvYVhNdUpIUmhZbXhsTzF4dVhIUmNkR3hsZENBa2FHRnVaR3hsY3lBOUlIUm9hWE11SkdoaGJtUnNaVU52Ym5SaGFXNWxjaTVtYVc1a0tDY3VKeXREVEVGVFUxOUlRVTVFVEVVcE8xeHVYRzVjZEZ4MGRHaHBjeTUxYm1KcGJtUkZkbVZ1ZEhNb1hHNWNkRngwWEhSMGFHbHpMaVIzYVc1a2IzZGNibHgwWEhSY2RGeDBMbUZrWkNoMGFHbHpMaVJ2ZDI1bGNrUnZZM1Z0Wlc1MEtWeHVYSFJjZEZ4MFhIUXVZV1JrS0hSb2FYTXVKSFJoWW14bEtWeHVYSFJjZEZ4MFhIUXVZV1JrS0NSb1lXNWtiR1Z6S1Z4dVhIUmNkQ2s3WEc1Y2JseDBYSFFrYUdGdVpHeGxjeTV5WlcxdmRtVkVZWFJoS0VSQlZFRmZWRWdwTzF4dVhIUmNkQ1IwWVdKc1pTNXlaVzF2ZG1WRVlYUmhLRVJCVkVGZlFWQkpLVHRjYmx4dVhIUmNkSFJvYVhNdUpHaGhibVJzWlVOdmJuUmhhVzVsY2k1eVpXMXZkbVVvS1R0Y2JseDBYSFIwYUdsekxpUm9ZVzVrYkdWRGIyNTBZV2x1WlhJZ1BTQnVkV3hzTzF4dVhIUmNkSFJvYVhNdUpIUmhZbXhsU0dWaFpHVnljeUE5SUc1MWJHdzdYRzVjZEZ4MGRHaHBjeTRrZEdGaWJHVWdQU0J1ZFd4c08xeHVYRzVjZEZ4MGNtVjBkWEp1SUNSMFlXSnNaVHRjYmx4MGZWeHVYRzVjZEM4cUtseHVYSFJDYVc1a2N5Qm5hWFpsYmlCbGRtVnVkSE1nWm05eUlIUm9hWE1nYVc1emRHRnVZMlVnZEc4Z2RHaGxJR2RwZG1WdUlIUmhjbWRsZENCRVQwMUZiR1Z0Wlc1MFhHNWNibHgwUUhCeWFYWmhkR1ZjYmx4MFFHMWxkR2h2WkNCaWFXNWtSWFpsYm5SelhHNWNkRUJ3WVhKaGJTQjBZWEpuWlhRZ2UycFJkV1Z5ZVgwZ2FsRjFaWEo1TFhkeVlYQndaV1FnUkU5TlJXeGxiV1Z1ZENCMGJ5QmlhVzVrSUdWMlpXNTBjeUIwYjF4dVhIUkFjR0Z5WVcwZ1pYWmxiblJ6SUh0VGRISnBibWQ4UVhKeVlYbDlJRVYyWlc1MElHNWhiV1VnS0c5eUlHRnljbUY1SUc5bUtTQjBieUJpYVc1a1hHNWNkRUJ3WVhKaGJTQnpaV3hsWTNSdmNrOXlRMkZzYkdKaFkyc2dlMU4wY21sdVozeEdkVzVqZEdsdmJuMGdVMlZzWldOMGIzSWdjM1J5YVc1bklHOXlJR05oYkd4aVlXTnJYRzVjZEVCd1lYSmhiU0JiWTJGc2JHSmhZMnRkSUh0R2RXNWpkR2x2Ym4wZ1EyRnNiR0poWTJzZ2JXVjBhRzlrWEc1Y2RDb3FMMXh1WEhSaWFXNWtSWFpsYm5SektDUjBZWEpuWlhRc0lHVjJaVzUwY3l3Z2MyVnNaV04wYjNKUGNrTmhiR3hpWVdOckxDQmpZV3hzWW1GamF5a2dlMXh1WEhSY2RHbG1LSFI1Y0dWdlppQmxkbVZ1ZEhNZ1BUMDlJQ2R6ZEhKcGJtY25LU0I3WEc1Y2RGeDBYSFJsZG1WdWRITWdQU0JsZG1WdWRITWdLeUIwYUdsekxtNXpPMXh1WEhSY2RIMWNibHgwWEhSbGJITmxJSHRjYmx4MFhIUmNkR1YyWlc1MGN5QTlJR1YyWlc1MGN5NXFiMmx1S0hSb2FYTXVibk1nS3lBbklDY3BJQ3NnZEdocGN5NXVjenRjYmx4MFhIUjlYRzVjYmx4MFhIUnBaaWhoY21kMWJXVnVkSE11YkdWdVozUm9JRDRnTXlrZ2UxeHVYSFJjZEZ4MEpIUmhjbWRsZEM1dmJpaGxkbVZ1ZEhNc0lITmxiR1ZqZEc5eVQzSkRZV3hzWW1GamF5d2dZMkZzYkdKaFkyc3BPMXh1WEhSY2RIMWNibHgwWEhSbGJITmxJSHRjYmx4MFhIUmNkQ1IwWVhKblpYUXViMjRvWlhabGJuUnpMQ0J6Wld4bFkzUnZjazl5UTJGc2JHSmhZMnNwTzF4dVhIUmNkSDFjYmx4MGZWeHVYRzVjZEM4cUtseHVYSFJWYm1KcGJtUnpJR1YyWlc1MGN5QnpjR1ZqYVdacFl5QjBieUIwYUdseklHbHVjM1JoYm1ObElHWnliMjBnZEdobElHZHBkbVZ1SUhSaGNtZGxkQ0JFVDAxRmJHVnRaVzUwWEc1Y2JseDBRSEJ5YVhaaGRHVmNibHgwUUcxbGRHaHZaQ0IxYm1KcGJtUkZkbVZ1ZEhOY2JseDBRSEJoY21GdElIUmhjbWRsZENCN2FsRjFaWEo1ZlNCcVVYVmxjbmt0ZDNKaGNIQmxaQ0JFVDAxRmJHVnRaVzUwSUhSdklIVnVZbWx1WkNCbGRtVnVkSE1nWm5KdmJWeHVYSFJBY0dGeVlXMGdaWFpsYm5SeklIdFRkSEpwYm1kOFFYSnlZWGw5SUVWMlpXNTBJRzVoYldVZ0tHOXlJR0Z5Y21GNUlHOW1LU0IwYnlCMWJtSnBibVJjYmx4MEtpb3ZYRzVjZEhWdVltbHVaRVYyWlc1MGN5Z2tkR0Z5WjJWMExDQmxkbVZ1ZEhNcElIdGNibHgwWEhScFppaDBlWEJsYjJZZ1pYWmxiblJ6SUQwOVBTQW5jM1J5YVc1bkp5a2dlMXh1WEhSY2RGeDBaWFpsYm5SeklEMGdaWFpsYm5SeklDc2dkR2hwY3k1dWN6dGNibHgwWEhSOVhHNWNkRngwWld4elpTQnBaaWhsZG1WdWRITWdJVDBnYm5Wc2JDa2dlMXh1WEhSY2RGeDBaWFpsYm5SeklEMGdaWFpsYm5SekxtcHZhVzRvZEdocGN5NXVjeUFySUNjZ0p5a2dLeUIwYUdsekxtNXpPMXh1WEhSY2RIMWNibHgwWEhSbGJITmxJSHRjYmx4MFhIUmNkR1YyWlc1MGN5QTlJSFJvYVhNdWJuTTdYRzVjZEZ4MGZWeHVYRzVjZEZ4MEpIUmhjbWRsZEM1dlptWW9aWFpsYm5SektUdGNibHgwZlZ4dVhHNWNkQzhxS2x4dVhIUlVjbWxuWjJWeWN5QmhiaUJsZG1WdWRDQnZiaUIwYUdVZ1BIUmhZbXhsTHo0Z1pXeGxiV1Z1ZENCbWIzSWdZU0JuYVhabGJpQjBlWEJsSUhkcGRHZ2daMmwyWlc1Y2JseDBZWEpuZFcxbGJuUnpMQ0JoYkhOdklITmxkSFJwYm1jZ1lXNWtJR0ZzYkc5M2FXNW5JR0ZqWTJWemN5QjBieUIwYUdVZ2IzSnBaMmx1WVd4RmRtVnVkQ0JwWmx4dVhIUm5hWFpsYmk0Z1VtVjBkWEp1Y3lCMGFHVWdjbVZ6ZFd4MElHOW1JSFJvWlNCMGNtbG5aMlZ5WldRZ1pYWmxiblF1WEc1Y2JseDBRSEJ5YVhaaGRHVmNibHgwUUcxbGRHaHZaQ0IwY21sbloyVnlSWFpsYm5SY2JseDBRSEJoY21GdElIUjVjR1VnZTFOMGNtbHVaMzBnUlhabGJuUWdibUZ0WlZ4dVhIUkFjR0Z5WVcwZ1lYSm5jeUI3UVhKeVlYbDlJRUZ5Y21GNUlHOW1JR0Z5WjNWdFpXNTBjeUIwYnlCd1lYTnpJSFJvY205MVoyaGNibHgwUUhCaGNtRnRJRnR2Y21sbmFXNWhiRVYyWlc1MFhTQkpaaUJuYVhabGJpd2dhWE1nYzJWMElHOXVJSFJvWlNCbGRtVnVkQ0J2WW1wbFkzUmNibHgwUUhKbGRIVnliaUI3VFdsNFpXUjlJRkpsYzNWc2RDQnZaaUIwYUdVZ1pYWmxiblFnZEhKcFoyZGxjaUJoWTNScGIyNWNibHgwS2lvdlhHNWNkSFJ5YVdkblpYSkZkbVZ1ZENoMGVYQmxMQ0JoY21kekxDQnZjbWxuYVc1aGJFVjJaVzUwS1NCN1hHNWNkRngwYkdWMElHVjJaVzUwSUQwZ0pDNUZkbVZ1ZENoMGVYQmxLVHRjYmx4MFhIUnBaaWhsZG1WdWRDNXZjbWxuYVc1aGJFVjJaVzUwS1NCN1hHNWNkRngwWEhSbGRtVnVkQzV2Y21sbmFXNWhiRVYyWlc1MElEMGdKQzVsZUhSbGJtUW9lMzBzSUc5eWFXZHBibUZzUlhabGJuUXBPMXh1WEhSY2RIMWNibHh1WEhSY2RISmxkSFZ5YmlCMGFHbHpMaVIwWVdKc1pTNTBjbWxuWjJWeUtHVjJaVzUwTENCYmRHaHBjMTB1WTI5dVkyRjBLR0Z5WjNNZ2ZId2dXMTBwS1R0Y2JseDBmVnh1WEc1Y2RDOHFLbHh1WEhSRFlXeGpkV3hoZEdWeklHRWdkVzVwY1hWbElHTnZiSFZ0YmlCSlJDQm1iM0lnWVNCbmFYWmxiaUJqYjJ4MWJXNGdSRTlOUld4bGJXVnVkRnh1WEc1Y2RFQndjbWwyWVhSbFhHNWNkRUJ0WlhSb2IyUWdaMlZ1WlhKaGRHVkRiMngxYlc1SlpGeHVYSFJBY0dGeVlXMGdKR1ZzSUh0cVVYVmxjbmw5SUdwUmRXVnllUzEzY21Gd2NHVmtJR052YkhWdGJpQmxiR1Z0Wlc1MFhHNWNkRUJ5WlhSMWNtNGdlMU4wY21sdVozMGdRMjlzZFcxdUlFbEVYRzVjZENvcUwxeHVYSFJuWlc1bGNtRjBaVU52YkhWdGJrbGtLQ1JsYkNrZ2UxeHVYSFJjZEhKbGRIVnliaUIwYUdsekxpUjBZV0pzWlM1a1lYUmhLRVJCVkVGZlEwOU1WVTFPVTE5SlJDa2dLeUFuTFNjZ0t5QWtaV3d1WkdGMFlTaEVRVlJCWDBOUFRGVk5UbDlKUkNrN1hHNWNkSDFjYmx4dVhIUXZLaXBjYmx4MFVHRnljMlZ6SUdFZ1oybDJaVzRnUkU5TlJXeGxiV1Z1ZENkeklIZHBaSFJvSUdsdWRHOGdZU0JtYkc5aGRGeHVYRzVjZEVCd2NtbDJZWFJsWEc1Y2RFQnRaWFJvYjJRZ2NHRnljMlZYYVdSMGFGeHVYSFJBY0dGeVlXMGdaV3hsYldWdWRDQjdSRTlOUld4bGJXVnVkSDBnUld4bGJXVnVkQ0IwYnlCblpYUWdkMmxrZEdnZ2IyWmNibHgwUUhKbGRIVnliaUI3VG5WdFltVnlmU0JGYkdWdFpXNTBKM01nZDJsa2RHZ2dZWE1nWVNCbWJHOWhkRnh1WEhRcUtpOWNibHgwY0dGeWMyVlhhV1IwYUNobGJHVnRaVzUwS1NCN1hHNWNkRngwY21WMGRYSnVJR1ZzWlcxbGJuUWdQeUJ3WVhKelpVWnNiMkYwS0dWc1pXMWxiblF1YzNSNWJHVXVkMmxrZEdncElEb2dNRHRjYmx4MGZWeHVYRzVjZEM4cUtseHVYSFJUWlhSeklIUm9aU0J3WlhKalpXNTBZV2RsSUhkcFpIUm9JRzltSUdFZ1oybDJaVzRnUkU5TlJXeGxiV1Z1ZEZ4dVhHNWNkRUJ3Y21sMllYUmxYRzVjZEVCdFpYUm9iMlFnYzJWMFYybGtkR2hjYmx4MFFIQmhjbUZ0SUdWc1pXMWxiblFnZTBSUFRVVnNaVzFsYm5SOUlFVnNaVzFsYm5RZ2RHOGdjMlYwSUhkcFpIUm9JRzl1WEc1Y2RFQndZWEpoYlNCM2FXUjBhQ0I3VG5WdFltVnlmU0JYYVdSMGFDd2dZWE1nWVNCd1pYSmpaVzUwWVdkbExDQjBieUJ6WlhSY2JseDBLaW92WEc1Y2RITmxkRmRwWkhSb0tHVnNaVzFsYm5Rc0lIZHBaSFJvS1NCN1hHNWNkRngwZDJsa2RHZ2dQU0IzYVdSMGFDNTBiMFpwZUdWa0tESXBPMXh1WEhSY2RIZHBaSFJvSUQwZ2QybGtkR2dnUGlBd0lEOGdkMmxrZEdnZ09pQXdPMXh1WEhSY2RDUW9aV3hsYldWdWRDa3VkMmxrZEdnb2QybGtkR2dwWEc1Y2RIMWNibHh1WEhRdktpcGNibHgwUTI5dWMzUnlZV2x1Y3lCaElHZHBkbVZ1SUhkcFpIUm9JSFJ2SUhSb1pTQnRhVzVwYlhWdElHRnVaQ0J0WVhocGJYVnRJSEpoYm1kbGN5QmtaV1pwYm1Wa0lHbHVYRzVjZEhSb1pTQmdiV2x1VjJsa2RHaGdJR0Z1WkNCZ2JXRjRWMmxrZEdoZ0lHTnZibVpwWjNWeVlYUnBiMjRnYjNCMGFXOXVjeXdnY21WemNHVmpkR2wyWld4NUxseHVYRzVjZEVCd2NtbDJZWFJsWEc1Y2RFQnRaWFJvYjJRZ1kyOXVjM1J5WVdsdVYybGtkR2hjYmx4MFFIQmhjbUZ0SUhkcFpIUm9JSHRPZFcxaVpYSjlJRmRwWkhSb0lIUnZJR052Ym5OMGNtRnBibHh1WEhSQWNtVjBkWEp1SUh0T2RXMWlaWEo5SUVOdmJuTjBjbUZwYm1Wa0lIZHBaSFJvWEc1Y2RDb3FMMXh1WEhSamIyNXpkSEpoYVc1WGFXUjBhQ2gzYVdSMGFDa2dlMXh1WEhSY2RHbG1JQ2gwYUdsekxtOXdkR2x2Ym5NdWJXbHVWMmxrZEdnZ0lUMGdkVzVrWldacGJtVmtLU0I3WEc1Y2RGeDBYSFIzYVdSMGFDQTlJRTFoZEdndWJXRjRLSFJvYVhNdWIzQjBhVzl1Y3k1dGFXNVhhV1IwYUN3Z2QybGtkR2dwTzF4dVhIUmNkSDFjYmx4dVhIUmNkR2xtSUNoMGFHbHpMbTl3ZEdsdmJuTXViV0Y0VjJsa2RHZ2dJVDBnZFc1a1pXWnBibVZrS1NCN1hHNWNkRngwWEhSM2FXUjBhQ0E5SUUxaGRHZ3ViV2x1S0hSb2FYTXViM0IwYVc5dWN5NXRZWGhYYVdSMGFDd2dkMmxrZEdncE8xeHVYSFJjZEgxY2JseHVYSFJjZEhKbGRIVnliaUIzYVdSMGFEdGNibHgwZlZ4dVhHNWNkQzhxS2x4dVhIUkhhWFpsYmlCaElIQmhjblJwWTNWc1lYSWdSWFpsYm5RZ2IySnFaV04wTENCeVpYUnlhV1YyWlhNZ2RHaGxJR04xY25KbGJuUWdjRzlwYm5SbGNpQnZabVp6WlhRZ1lXeHZibWRjYmx4MGRHaGxJR2h2Y21sNmIyNTBZV3dnWkdseVpXTjBhVzl1TGlCQlkyTnZkVzUwY3lCbWIzSWdZbTkwYUNCeVpXZDFiR0Z5SUcxdmRYTmxJR05zYVdOcmN5QmhjeUIzWld4c0lHRnpYRzVjZEhCdmFXNTBaWEl0YkdsclpTQnplWE4wWlcxeklDaHRiMkpwYkdWekxDQjBZV0pzWlhSeklHVjBZeTRwWEc1Y2JseDBRSEJ5YVhaaGRHVmNibHgwUUcxbGRHaHZaQ0JuWlhSUWIybHVkR1Z5V0Z4dVhIUkFjR0Z5WVcwZ1pYWmxiblFnZTA5aWFtVmpkSDBnUlhabGJuUWdiMkpxWldOMElHRnpjMjlqYVdGMFpXUWdkMmwwYUNCMGFHVWdhVzUwWlhKaFkzUnBiMjVjYmx4MFFISmxkSFZ5YmlCN1RuVnRZbVZ5ZlNCSWIzSnBlbTl1ZEdGc0lIQnZhVzUwWlhJZ2IyWm1jMlYwWEc1Y2RDb3FMMXh1WEhSblpYUlFiMmx1ZEdWeVdDaGxkbVZ1ZENrZ2UxeHVYSFJjZEdsbUlDaGxkbVZ1ZEM1MGVYQmxMbWx1WkdWNFQyWW9KM1J2ZFdOb0p5a2dQVDA5SURBcElIdGNibHgwWEhSY2RISmxkSFZ5YmlBb1pYWmxiblF1YjNKcFoybHVZV3hGZG1WdWRDNTBiM1ZqYUdWeld6QmRJSHg4SUdWMlpXNTBMbTl5YVdkcGJtRnNSWFpsYm5RdVkyaGhibWRsWkZSdmRXTm9aWE5iTUYwcExuQmhaMlZZTzF4dVhIUmNkSDFjYmx4MFhIUnlaWFIxY200Z1pYWmxiblF1Y0dGblpWZzdYRzVjZEgxY2JuMWNibHh1VW1WemFYcGhZbXhsUTI5c2RXMXVjeTVrWldaaGRXeDBjeUE5SUh0Y2JseDBjMlZzWldOMGIzSTZJR1oxYm1OMGFXOXVLQ1IwWVdKc1pTa2dlMXh1WEhSY2RHbG1LQ1IwWVdKc1pTNW1hVzVrS0NkMGFHVmhaQ2NwTG14bGJtZDBhQ2tnZTF4dVhIUmNkRngwY21WMGRYSnVJRk5GVEVWRFZFOVNYMVJJTzF4dVhIUmNkSDFjYmx4dVhIUmNkSEpsZEhWeWJpQlRSVXhGUTFSUFVsOVVSRHRjYmx4MGZTeGNibHgwTHk5cWNYVmxjbmtnWld4bGJXVnVkQ0J2WmlCMGFHVWdhR0Z1Wkd4bFEyOXVkR0ZwYm1WeUlIQnZjMmwwYVc5dUxHaGhibVJzWlVOdmJuUmhhVzVsY2lCM2FXeHNJR0psWm05eVpTQjBhR1VnWld4bGJXVnVkQ3dnWkdWbVlYVnNkQ0IzYVd4c0lHSmxJSFJvYVhNZ2RHRmliR1ZjYmx4MGFHRnVaR3hsUTI5dWRHRnBibVZ5T201MWJHd3NYRzVjZEhCaFpHUnBibWM2TUN4Y2JseDBjM1J2Y21VNklIZHBibVJ2ZHk1emRHOXlaU3hjYmx4MGMzbHVZMGhoYm1Sc1pYSnpPaUIwY25WbExGeHVYSFJ5WlhOcGVtVkdjbTl0UW05a2VUb2dkSEoxWlN4Y2JseDBiV0Y0VjJsa2RHZzZJRzUxYkd3c1hHNWNkRzFwYmxkcFpIUm9PaUF3TGpBeFhHNTlPMXh1WEc1U1pYTnBlbUZpYkdWRGIyeDFiVzV6TG1OdmRXNTBJRDBnTUR0Y2JpSXNJbVY0Y0c5eWRDQmpiMjV6ZENCRVFWUkJYMEZRU1NBOUlDZHlaWE5wZW1GaWJHVkRiMngxYlc1ekp6dGNibVY0Y0c5eWRDQmpiMjV6ZENCRVFWUkJYME5QVEZWTlRsTmZTVVFnUFNBbmNtVnphWHBoWW14bExXTnZiSFZ0Ym5NdGFXUW5PMXh1Wlhod2IzSjBJR052Ym5OMElFUkJWRUZmUTA5TVZVMU9YMGxFSUQwZ0ozSmxjMmw2WVdKc1pTMWpiMngxYlc0dGFXUW5PMXh1Wlhod2IzSjBJR052Ym5OMElFUkJWRUZmVkVnZ1BTQW5kR2duTzF4dVhHNWxlSEJ2Y25RZ1kyOXVjM1FnUTB4QlUxTmZWRUZDVEVWZlVrVlRTVnBKVGtjZ1BTQW5jbU10ZEdGaWJHVXRjbVZ6YVhwcGJtY25PMXh1Wlhod2IzSjBJR052Ym5OMElFTk1RVk5UWDBOUFRGVk5UbDlTUlZOSldrbE9SeUE5SUNkeVl5MWpiMngxYlc0dGNtVnphWHBwYm1jbk8xeHVaWGh3YjNKMElHTnZibk4wSUVOTVFWTlRYMGhCVGtSTVJTQTlJQ2R5WXkxb1lXNWtiR1VuTzF4dVpYaHdiM0owSUdOdmJuTjBJRU5NUVZOVFgwaEJUa1JNUlY5RFQwNVVRVWxPUlZJZ1BTQW5jbU10YUdGdVpHeGxMV052Ym5SaGFXNWxjaWM3WEc1Y2JtVjRjRzl5ZENCamIyNXpkQ0JGVmtWT1ZGOVNSVk5KV2tWZlUxUkJVbFFnUFNBblkyOXNkVzF1T25KbGMybDZaVHB6ZEdGeWRDYzdYRzVsZUhCdmNuUWdZMjl1YzNRZ1JWWkZUbFJmVWtWVFNWcEZJRDBnSjJOdmJIVnRianB5WlhOcGVtVW5PMXh1Wlhod2IzSjBJR052Ym5OMElFVldSVTVVWDFKRlUwbGFSVjlUVkU5UUlEMGdKMk52YkhWdGJqcHlaWE5wZW1VNmMzUnZjQ2M3WEc1Y2JtVjRjRzl5ZENCamIyNXpkQ0JUUlV4RlExUlBVbDlVU0NBOUlDZDBjanBtYVhKemRDQStJSFJvT25acGMybGliR1VuTzF4dVpYaHdiM0owSUdOdmJuTjBJRk5GVEVWRFZFOVNYMVJFSUQwZ0ozUnlPbVpwY25OMElENGdkR1E2ZG1semFXSnNaU2M3WEc1bGVIQnZjblFnWTI5dWMzUWdVMFZNUlVOVVQxSmZWVTVTUlZOSldrRkNURVVnUFNCZ1cyUmhkR0V0Ym05eVpYTnBlbVZkWUR0Y2JpSXNJbWx0Y0c5eWRDQlNaWE5wZW1GaWJHVkRiMngxYlc1eklHWnliMjBnSnk0dlkyeGhjM01uTzF4dWFXMXdiM0owSUdGa1lYQjBaWElnWm5KdmJTQW5MaTloWkdGd2RHVnlKenRjYmx4dVpYaHdiM0owSUdSbFptRjFiSFFnVW1WemFYcGhZbXhsUTI5c2RXMXVjenNpWFgwPSJ9
