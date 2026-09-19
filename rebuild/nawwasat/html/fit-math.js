/* ==========================================================================
   fit-math.js — ضبط تلقائي لعرض المعادلات الطويلة (بلا مسّ المحتوى)
   يقلّص حجم خطّ المعادلة فقط عند تجاوزها عرض حاويتها، ولا يقلّص أكثر من 55%.
   يُشغَّل عند التحميل وقبل الطباعة (وفي NHTML-4 قبل إخراج PDF).
   ========================================================================== */
(function () {
  "use strict";
  var MIN_RATIO = 0.45;     // أدنى نسبة تصغير مسموحة
  var MAX_ITER = 6;

  function containerOf(m) {
    var box = m.closest(".equation") || m.closest(".col") || m.closest("figure") ||
              m.closest("td") || m.closest("p") || m.parentElement;
    var node = box;
    while (node && node !== document.body && (!node.clientWidth || node.clientWidth < 40)) {
      node = node.parentElement;
    }
    return node || box;
  }

  function fitOne(m) {
    m.style.fontSize = "";
    var box = containerOf(m);
    if (!box) return;
    var avail = box.clientWidth - 2;
    if (avail <= 0) return;
    var w = m.getBoundingClientRect().width;
    if (!w || w < 5 || w <= avail) return;
    var base = parseFloat(window.getComputedStyle(m).fontSize) || 16;
    var size = base;
    for (var i = 0; i < MAX_ITER && w > avail; i++) {
      var ratio = avail / w;                       // < 1 دائماً
      var target = size * ratio * 0.97;
      // تصغير فقط، وبسقف أدنى — لا تكبير أبداً
      var next = Math.max(base * MIN_RATIO, Math.min(size, target));
      if (!isFinite(next) || next <= 0 || Math.abs(next - size) < 0.2) break;
      size = next;
      m.style.fontSize = size.toFixed(2) + "px";
      w = m.getBoundingClientRect().width;
    }
    m.dataset.fitted = "1";
  }

  function fitAll() {
    var list = document.querySelectorAll("math");
    for (var i = 0; i < list.length; i++) fitOne(list[i]);
  }

  function schedule() {
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () { requestAnimationFrame(fitAll); });
    }
    requestAnimationFrame(fitAll);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule);
  } else {
    schedule();
  }
  window.addEventListener("beforeprint", fitAll, false);
  window.addEventListener("resize", function () {
    clearTimeout(window.__fitT);
    window.__fitT = setTimeout(fitAll, 200);
  });
  window.__fitMath = fitAll;   // تستدعيها NHTML-4 قبل إخراج PDF
})();
