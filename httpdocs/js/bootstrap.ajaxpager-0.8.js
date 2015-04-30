/**
 * @depends /core/jquery-1.7.2.js
 * @depends /bootstrap/bootstrap.js
 * @depends /bootstrap/html5.js
 */
(function($) {

	$.fn.ajaxPager = function(options) {
		
		if($.ajaxPager.methods[options]){
			return $.ajaxPager.methods[options].apply( this, Array.prototype.slice.call( arguments, 1 ));
		} else if ( typeof options === 'object' || ! options ) {
			return $.ajaxPager.methods.init.apply( this, arguments );
		} else {
			$.error( 'Method ' +  options + ' does not exist on jQuery.ajaxPager' );
		}
		
		var settings = {};
		var privatevars = {};
		var handlers = {};
		var getAccessor = null;
		var makeRequest = null;
		var changePage = null;
		var mask = null;
		var unmask = null;
	}; 

	// publicly accessible defaults
	$.fn.ajaxPager.defaults = {
		position		: 'top', // top|bottom|both
		classes			: '', // for additional classes
		stripedrows		: false,
		loadtext   		: 'Loading...',
		page			: 1,
		limit			: 25, // number of records
		limitdd			: true,
		limitoptions	: [25,50,75,100],
		sortcolumn		: null,
		sortdir			: 'asc',
		sortby			: {},
		searchtext		: null,
		ajaxoptions		: {
			url			: '',
			type		: 'POST',
			data		: {},
			dataType	: 'json'
		},
		reader			: {
			success			: 'success',
			message			: 'message',
			totalpages		: 'totalpages',
			totalrecords	: 'totalrecords',
			root			: ''
		},
		params			: {
			start	: 'start',
			limit	: 'limit',
			page	: 'page',
			sort	: 'sort',
			dir		: 'dir',
			search	: 'search'
		},
		renderoutput	: null,
		listeners: {
			init		: null,
			render		: null,
			preprocess	: null,
			beforeload	: null,
			load		: null,
			destroy		: null
		}
    };
	
	$.fn.ajaxPager.privatevars = {
		dataloaded	: false,
		rendered	: false,
		totalpages	: 12,
		totalrecords: 293,
		firstrecord	: 0,
		lastrecord	: 0,
		pagers: null
	};
    
	// These are the methods of the plugin
	$.ajaxPager = {
		methods: {
			init: function(options){
				var options = options||{};
				settings = $.extend(true, {}, $.fn.ajaxPager.defaults, options);
				handlers = $.ajaxPager.handlers;
				getAccessor = $.ajaxPager._getAccessor;
				makeRequest = $.ajaxPager._makeRequest;
				changePage = $.ajaxPager._changePage;
				mask = $.ajaxPager._maskContent;
				unmask = $.ajaxPager._unmaskContent;
				
				return this.each(function(){
					var $self = $(this),
						data = $self.data('ajaxPager');
					
					// setup bindings
					$self.bind('optionchange.ajaxPager', handlers.optionChangeHandler);
					$self.bind('pagechange.ajaxPager', handlers.pageChangeHandler);
					$self.bind('firstpage.ajaxPager', handlers.firstPageHandler);
					$self.bind('previouspage.ajaxPager', handlers.previousPageHandler);
					$self.bind('nextpage.ajaxPager', handlers.nextPageHandler);
					$self.bind('lastpage.ajaxPager', handlers.lastPageHandler);
					$self.bind('init.ajaxPager', handlers.initHandler);
					$self.bind('render.ajaxPager', handlers.renderHandler);
					$self.bind('beforeload.ajaxPager', handlers.beforeLoadHandler);
					$self.bind('load.ajaxPager', handlers.loadHandler);
					$self.bind('destroy.ajaxPager', handlers.destroyHandler);
					
					// Create some UI
					var barUI = $.ajaxPager._buildPagerBar(settings);
					$self.wrap('<div class="ajaxPagerContainer" />').addClass('pagingContent');
					switch (settings.position) {
						case "both":
							$self.before(barUI).after(barUI);
							break;
						case "top":
							$self.before(barUI);
							break;
						case "bottom":
							$self.after(barUI);
							break;
					}
					
					if(!data){
						$self.data('ajaxPager',$.extend({}, $.fn.ajaxPager.privatevars, {
							target: $self,
							pagers: $('.pagingbar', $self.parent()),
							origcontent: $(this).html()
						}));
					}
					//console.log('data init ', $self.data('ajaxPager'));
					
					$self.trigger('init').trigger('render');
				});
			},
			destroy: function(){
				
				return this.each(function(){
					var $self = $(this),
						data = $self.data('ajaxPager');
					if (settings.listeners.destroy && typeof settings.listeners.destroy === 'function'){
						settings.listeners.destroy.call($self, 'destroy');
					}
					$self.unbind('.ajaxPager');
					$('a.paging-nav', data.pagers).unbind('click');
					if (!$.isEmptyObject(settings.sortby)) {
						$('a.paging-filter', data.pagers).unbind('click');
					}
					if (settings.limitdd) {
						$('a.paging-limit', data.pagers).unbind('click');
					}
					$('.navbar-form', data.pagers).unbind('submit');
					$('.navbar-form input', data.pagers).unbind('keypress');
					$self.html(data.origcontent);
					data.pagers.remove();
					$self.unwrap().removeClass('pagingContent');
					$self.removeData('ajaxPager');
				});
			},
			option: function(options){
				var orig = $.extend({}, settings);
				var $self = $(this);
				if (typeof options === 'object'){
					settings = $.extend(true, settings, options);
				} else if (arguments.length === 2) {
					settings[arguments[0]] = arguments[1];
				} else {
					return settings[arguments[0]];
				}
				$.each(orig, function(ind,el){
					if(settings[ind]!==el){
						$self.trigger('optionchange', [ind, el, settings[ind]]);
					}
				})
				return;
			},
			reload: function() {
				var $self = $(this),
					data = $(this).data('ajaxPager');
				$.ajaxPager._makeRequest.call($self, settings.page);
			}
		},
		handlers: {
			optionChangeHandler: function(event, option, oldvalue, newvalue){
				var $self = $(this),
					data = $(this).data('ajaxPager');
				switch (option) {
					case "page":
						if (newvalue > data.totalpages && (data.rendered && data.dataloaded)) {
							settings.page = oldvalue;
							$('form[name="jump"] input[name="page"]', data.pagers).val(oldvalue);
							$.error( 'You have tried to set a \"page\" beyond the number of available pages' );
						} else {
							$self.trigger('pagechange', newvalue);
						}
						break;
					case "classes":
						var pagers = data.pagers;
						if (!pagers.hasClass(newvalue)) {
							pagers.addClass(newvalue);
						}
						break;
					case "searchtext":
						$self.trigger('pagechange', 1);
						break;
				}
			},
			jumpFormHandler: function(event){
				event.preventDefault();
				var $pager = $('.pagingContent', $(this).closest('.pagingbar').parent());
				var val = $('input[name="page"]', $(this)).val();
				$pager.ajaxPager('option', 'page', val);
				return false;
			},
			pageChangeHandler: function(event, page){
				var $self = $(this),
					data = $(this).data('ajaxPager');
				
				var newpage = page;
				switch(page){
					case 1:
						newpage = 1;
						break;
					case data.totalpages:
						newpage = data.totalpages;
						break;
					default:
						break;
				}
				//console.log('in page change to page ', page)
				$.ajaxPager._makeRequest.call($(this), newpage);
			},
			filterLinkHandler: function(event){
				event.preventDefault();
				var $pager = event.data.el,
					action = $(this).attr('rel'),
					icon = $('i', $('a[rel="' + action + '"]')),
					diricon = icon.attr('class'),
					data = $pager.data('ajaxPager'),
					sortby = $('.paging-filter', data.pagers),
					newicon = 'icon-arrow-down';
				$('i',sortby).removeClass('icon-arrow-up').removeClass('icon-arrow-down').removeClass('icon-').addClass('icon-');
				
				settings.sortcolumn = action;
				if (diricon === 'icon-arrow-up') {
					settings.sortdir = 'desc';
					newicon = 'icon-arrow-down';
				} else if (diricon === 'icon-arrow-down') {
					settings.sortdir = 'asc';
					newicon = 'icon-arrow-up';
				} else {
					settings.sortdir = 'desc';
				}
				icon.removeClass('icon-').addClass(newicon);
				$('li.dropdown.open').removeClass('open');
				//console.log(settings.sortcolumn, settings.sortdir);
				$.ajaxPager._makeRequest.call($pager, settings.page);
				return false;
			},
			limitLinkHandler: function(event) {
				event.preventDefault();
				var $pager = event.data.el,
					action = $(this).attr('rel'),
					newlimit = $(this).text(),
					icon = $('i', $('a[rel="' + action + '"]')),
					diricon = icon.attr('class'),
					data = $pager.data('ajaxPager'),
					limitby = $('.paging-limit', data.pagers);
				settings.limit = newlimit;
				$('i',limitby).removeClass('icon-chevron-right').removeClass('icon-').addClass('icon-');
				icon.removeClass('icon-').addClass('icon-chevron-right');
				$('li.dropdown.open').removeClass('open');
				//console.log(settings.sortcolumn, settings.sortdir);
				$.ajaxPager._makeRequest.call($pager, settings.page);
				return false;
			},
			navLinkHandler: function(event) {
				event.preventDefault();
				var $pager = event.data.el,
					action = $(this).attr('rel');
				if (!$(this).hasClass('disabled')){
					$pager.trigger(action + 'page');
				}
				return false;
			},
			firstPageHandler: function(event){
				$(this).trigger('optionchange',['page', settings.page, 1]);
			},
			previousPageHandler: function(event){
				$(this).trigger('optionchange',['page', settings.page, settings.page-1]);
			},
			lastPageHandler: function(event){
				var $self = $(this),
					data = $(this).data('ajaxPager');
				$(this).trigger('optionchange',['page', settings.page, data.totalpages]);
			},
			nextPageHandler: function(event){
				$(this).trigger('optionchange',['page', settings.page, settings.page+1]);
			},
			initHandler: function () {
				var $self = $(this);
				if (settings.listeners.init && typeof settings.listeners.init === 'function'){
					settings.listeners.init.call($self, 'init');
				}
			},
			renderHandler: function(event){
				var $self = $(this),
					data = $(this).data('ajaxPager');
				if (settings.listeners.render && typeof settings.listeners.render === 'function'){
					settings.listeners.render.call($self, 'render');
				}
				// setup UI bindings
				$('a.paging-nav', data.pagers).bind('click', {el: $self}, handlers.navLinkHandler);
				$('.navbar-form', data.pagers).bind('submit', handlers.jumpFormHandler);
				$('.navbar-form input', data.pagers).bind('keypress',function(e){
					c = e.which ? e.which : e.keyCode;
					if(c === 13) {
						e.preventDefault();
						var form = $(this).parent();
						form.trigger('submit');
						return false;
					}
					return true;
				});
				// if there are sortby, we setup bindings
				if (!$.isEmptyObject(settings.sortby)) {
					$('a.paging-filter', data.pagers).bind('click', {el: $self}, handlers.filterLinkHandler);
				}
				if (settings.limitdd) {
					$('a.paging-limit', data.pagers).bind('click', {el: $self}, handlers.limitLinkHandler);
				}
				$self.data('ajaxPager', $.extend(data,{rendered: true}));
				//console.log('in render ', $self.data('ajaxPager'));
				$self.trigger('pagechange', settings.page);
			},
			beforeLoadHandler: function(event) {
				var $self = $(this);
				if (settings.listeners.beforeload && typeof settings.listeners.beforeload === 'function'){
					settings.listeners.beforeload.call($self, 'beforeload');
				}
			},
			loadHandler: function(event) {
				var $self = $(this);
				if (settings.listeners.load && typeof settings.listeners.load === 'function'){
					settings.listeners.load.call($self, 'load');
				}
			}
		},
		_buildPagerBar: function(settings){
			var ui = '<div class="pagingbar ajaxPager' + ((settings.classes.length > 0) ? (' ' + settings.classes) : '') + '">'
						+ '<div class="pagingbar-inner">'
							+ '<div class="container">'
								+ '<div class="nav-collapse">'
									+ '<ul class="nav nav-pills">'
										+ '<li><a href="#first" class="paging-nav" rel="first">|&#171;</a></li>'
										+ '<li class="divider-vertical"></li>'
										+ '<li><a href="#previous" class="paging-nav" rel="previous">&#171;</a></li>'
										+ '<li class="divider-vertical"></li>'
									+ '</ul>'
									+ '<form name="jump" class="navbar-form pull-left">'
										+ '<strong>Page</strong> <input type="text" name="page" value="0" style="width:25px;" /> <strong>of <span class="total-pages">0</span></strong>'
									+ '</form>'
									+ '<ul class="nav nav-pills">'
										+ '<li class="divider-vertical"></li>'
										+ '<li><a href="#next" class="paging-nav" rel="next">&#187;</a></li>'
										+ '<li class="divider-vertical"></li>'
										+ '<li><a href="#last" class="paging-nav" rel="last">&#187;|</a></li>'
										+ '<li class="divider-vertical"></li>';
			if (settings.limitdd) {
				ui += '<li class="dropdown">'
					+ '<a class="dropdown-toggle" data-toggle="dropdown" href="#">Limit<b class="caret"></b></a>'
						+ '<ul class="dropdown-menu">';
						for (var i = 0; i < settings.limitoptions.length; i++) {
							ui += '<li><a href="#limit-' + settings.limitoptions[i] + '" class="paging-limit" rel="' + settings.limitoptions[i] + '"><i class="icon-' + ((settings.limitoptions[i] === settings.limit) ? 'chevron-right' : '') + '"></i>' + settings.limitoptions[i] + '</a></li>';
						}
						ui += '</ul>'
					+ '</li>'
					+ '<li class="divider-vertical"></li>';
			}
			if (!$.isEmptyObject(settings.sortby)) {
				ui += '<li class="dropdown">'
						+ '<a class="dropdown-toggle" data-toggle="dropdown" href="#">Sort By<b class="caret"></b></a>'
							+ '<ul class="dropdown-menu">';
							for (var i in settings.sortby){
								ui += '<li><a href="#filter-' + i + '" class="paging-filter" rel="' + i + '">';
								if (settings.sortcolumn && i === settings.sortcolumn) {
									if (settings.sortdir === 'asc') {
										ui += '<i class="icon-arrow-up"></i> ';
									} else if (settings.sortcolumn && settings.sortdir === 'desc') {
										ui += '<i class="icon-arrow-down"></i> ';
									}
								} else {
									ui += '<i class="icon-"></i> ';
								}
								ui += settings.sortby[i] + '</a>';
							}
						ui += '</ul>'
					+ '</li>'
					+ '<li class="divider-vertical"></li>';
			}
							ui += '</ul>'
								+'<span class="pull-right navbar-text pagingbar-counts" style="margin-right:20px;">'
									+ '<strong>View <span class="first-record">0</span> - <span class="last-record">0</span> of <span class="record-count">0</span></strong>'
								+ '</span>'
							+ '</div>'
						+ '</div>'
					+ '</div>'
				+ '</div>';
			return ui;
		},
		_maskContent: function (label) {
			var $self = $(this);
			$self.append('<div class="component-backdrop fade in" />').addClass('masked');
			if(label !== undefined) {
				var maskMsgDiv = $('<div class="mask-msg alert alert-info" style="display:none;"></div>');
				maskMsgDiv.append('<div>' + label + '</div>');
				$self.append(maskMsgDiv);
				
				//calculate center position
				maskMsgDiv.css("top", Math.round($self.height() / 2 - (maskMsgDiv.height() - parseInt(maskMsgDiv.css("padding-top")) - parseInt(maskMsgDiv.css("padding-bottom"))) / 2)+"px");
				maskMsgDiv.css("left", Math.round($self.width() / 2 - (maskMsgDiv.width() - parseInt(maskMsgDiv.css("padding-left")) - parseInt(maskMsgDiv.css("padding-right"))) / 2)+"px");
				
				maskMsgDiv.show();
			}
		},
		_unmaskContent: function () {
			var $self = $(this);
			$('div.component-backdrop,div.mask-msg', $self).remove();
			$self.removeClass('masked');
			//console.log('let\'s unmask this thing',$('div.component-backdrop', $self));
		},
		_changePage: function (page, totalpages, totalrecords) {
			var $self = $(this),
				data = $(this).data('ajaxPager');
			data = $.extend(data, {totalpages: totalpages, totalrecords: totalrecords});
			switch(page){
				case 1:
					$('a.paging-nav[rel="first"], a.paging-nav[rel="previous"]', data.pagers).addClass('disabled');
					if (data.totalpages !== 1){
						$('a.paging-nav[rel="next"], a.paging-nav[rel="last"]', data.pagers).removeClass('disabled');
					} else {
						$('a.paging-nav[rel="next"], a.paging-nav[rel="last"]', data.pagers).addClass('disabled');
					}
					break;
				case data.totalpages:
					$('a.paging-nav[rel="first"], a.paging-nav[rel="previous"]', data.pagers).removeClass('disabled');
					$('a.paging-nav[rel="next"], a.paging-nav[rel="last"]', data.pagers).addClass('disabled');
					break;
				default:
					$('a.paging-nav[rel="first"], a.paging-nav[rel="previous"]', data.pagers).removeClass('disabled');
					$('a.paging-nav[rel="next"], a.paging-nav[rel="last"]', data.pagers).removeClass('disabled');
					break;
			}
			settings.page = page;
			
			var count = (page*settings.limit);
			data = $.extend(data, {
				firstrecord: ((settings.limit*(page-1))+1),
				lastrecord: (count > data.totalrecords) ? data.totalrecords : count
			});
			$self.data('ajaxPager', data);
			//console.log('after some sets ', $self.data('ajaxPager'));
			$('.pagingbar-counts .first-record', data.pagers).html(data.firstrecord);
			$('.pagingbar-counts .last-record', data.pagers).html(data.lastrecord);
			$('.pagingbar-counts .record-count', data.pagers).html(data.totalrecords);
			$('.navbar-form .total-pages', data.pagers).html(data.totalpages);
			
			$('form[name="jump"] input[name="page"]', data.pagers).val(page);
		},
		_makeRequest: function (page) {
			var $self = $(this),
				req = $.extend({}, settings.ajaxoptions),
				tmp = {},
				opts = settings,
				acc = getAccessor
				cp = changePage,
				u = unmask,
				data = $self.data('ajaxPager'),
				target = data.target;
			
			tmp[settings.params.start] = (page-1) * settings.limit;
			tmp[settings.params.page] = page;
			tmp[settings.params.limit] = settings.limit;
			if (settings.sortcolumn) {
				tmp[settings.params.sort] = settings.sortcolumn;
				tmp[settings.params.dir] = settings.sortdir;
			}
			if (settings.searchtext) {
				tmp[settings.params.search] = settings.searchtext;
			}
			for(var i in req){
				if (req[i] === null) {
					delete req[i];
				}
			}
			req.data = $.extend({}, req.data, tmp);
			mask.call($self, opts.loadtext);
			$.ajax($.extend(req,{
				success: function (d, s, o) {
					var output = null,
						dataset = null,
						totalpages = null,
						totalrecords = null;
					// Preprocess the return, if necessary
					d = (opts.listeners.preprocess && typeof opts.listeners.preprocess === 'function') ? opts.listeners.preprocess.call($self, d) : d;
					// Adjust our internal data to reflect values returned from the server
					// Valuable to change the display if a search is conducted
					dataset = acc(d, opts.reader.root);
					totalpages = parseInt(acc(d, opts.reader.totalpages));
					totalpages = parseInt((totalpages !== 'undefined') ? totalpages : 1);
					totalrecords = parseInt(acc(d,opts.reader.totalrecords));
					totalrecords = parseInt((totalrecords !== undefined) ? totalrecords : dataset.length);
					cp.call($self, page, totalpages, totalrecords);
					output = (opts.renderoutput && typeof opts.renderoutput === 'function') ? opts.renderoutput.call($self, d) : d;
					$self.trigger('beforeload');
					u.call($self,[]);
					target.html(output);
					
					if (opts.stripedrows) {
						$self.children(':even').addClass('striped-row')
					}
					data = $.extend(data, {dataloaded: true});
					$self.data('ajaxPager', data);
					$self.trigger('load');
				},
				error: function (o, s, err){
					u.call($self,[]);
					$.error('There was an error in making your request. Please notify your developer.');
				}
			}));
		},
		_getAccessor : function(obj, expr) {
			var ret,p,prm = [], i;
			if( typeof expr === 'function') { return expr(obj); }
			ret = obj[expr];
			if(ret===undefined) {
				try {
					if ( typeof expr === 'string' ) {
						prm = expr.split('.');
					}
					i = prm.length;
					if( i ) {
						ret = obj;
					    while (ret && i--) {
							p = prm.shift();
							ret = ret[p];
						}
					}
				} catch (e) {}
			}
			return ret;
		}
	};

})(jQuery);