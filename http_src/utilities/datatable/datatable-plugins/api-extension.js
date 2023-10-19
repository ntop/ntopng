/**
 * (C) 2020-22 - ntop.org
 * This file contains datatables.net extensions.
 */

/* See issue https://datatables.net/forums/discussion/44885 */

$.fn.dataTable.Api.registerPlural( 'columns().names()', 'column().name()', function ( setter ) {
  return this.iterator( 'column', function ( settings, column ) {
      var col = settings.aoColumns[column];

      if ( setter !== undefined ) {
          col.sName = setter;
          return this;
      }
      else {
          return col.sName;
      }
  }, 1 );
} );
