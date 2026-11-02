// The film's two languages. French is written in the HTML; an element that
// reads differently in English carries its English markup in `data-en`, and
// `Foulee.apply()` swaps it in when the root's `locale` variable is "en"
// (`hyperframes render --variables '{"locale":"en"}'`).
//
// Numbers, decimals and durations follow the app: « 4 218 », « 3,1 »,
// « 2 h 52 » in French (FouleeKit DurationFormatting.swift writes French by
// hand), « 4,218 », « 3.1 », « 2 hr, 52 min » in US English (the system's
// abbreviated units).
(function () {
  function locale() {
    try {
      var vars = window.__hyperframes && window.__hyperframes.getVariables && window.__hyperframes.getVariables();
      if (vars && vars.locale) return vars.locale;
    } catch (error) {}
    return document.documentElement.getAttribute("data-locale") || "fr";
  }

  var Foulee = {
    get en() {
      return locale() === "en";
    },
    /** French text, or its English counterpart. */
    t: function (fr, en) {
      return Foulee.en ? en : fr;
    },
    /** A whole number with its thousands separator. */
    nb: function (value) {
      var digits = String(Math.round(value));
      return digits.replace(/\B(?=(\d{3})+(?!\d))/g, Foulee.en ? "," : " ");
    },
    /** A decimal with `places` digits after the separator. */
    dec: function (value, places) {
      var text = value.toFixed(places);
      return Foulee.en ? text : text.replace(".", ",");
    },
    /** A duration in minutes, as the app writes it. */
    dur: function (minutes) {
      var m = Math.max(Math.round(minutes), 0);
      if (m < 60) return m + " min";
      var h = Math.floor(m / 60);
      var rest = m % 60;
      if (Foulee.en) return rest ? h + " hr, " + rest + " min" : h + " hr";
      return rest ? h + " h " + String(rest).padStart(2, "0") : h + " h";
    },
    /** Monday to Sunday, as the calendars label them. */
    weekdays: function () {
      return Foulee.en ? ["M", "T", "W", "T", "F", "S", "S"] : ["L", "M", "M", "J", "V", "S", "D"];
    },
    /** Swaps in the English markup of every element not swapped yet. */
    apply: function () {
      if (!Foulee.en) return;
      document.documentElement.lang = "en";
      var nodes = document.querySelectorAll("[data-en]:not([data-en-done])");
      for (var i = 0; i < nodes.length; i++) {
        nodes[i].innerHTML = nodes[i].getAttribute("data-en");
        nodes[i].setAttribute("data-en-done", "");
      }
    },
  };

  window.Foulee = Foulee;
})();
