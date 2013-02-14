;(function ($, window, undefined) {
  'use strict';

  var $doc = $(document),
      Modernizr = window.Modernizr;

  $(document).ready(function() {
    $.fn.foundationAccordion        ? $doc.foundationAccordion() : null;
  });

})(jQuery, this);
