/* ==========================================================================
   fit-math.js — ضبط تلقائي لعرض المعادلات الطويلة (بلا مسّ المحتوى)
   يقلّص حجم خطّ المعادلة فقط عند تجاوزها عرض حاويتها، ولا يقلّص أكثر من 55%.
   يُشغَّل عند التحميل وقبل الطباعة (وفي NHTML-4 قبل إخراج PDF).
   ========================================================================== */
(function () {
  "use strict";
  var MIN_RATIO = 0.45;     // أدنى نسبة تصغير مسموحة
  var MIN_RATIO_COL = 0.24; // داخل أعمدة ضيّقة: تصغير أعمق
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
    // عرض المحتوى الفعلي (قد يتجاوز إطار math في حال display:block) — وإلا فشلت الملاءمة
    var w = Math.max(m.getBoundingClientRect().width, m.scrollWidth || 0);
    if (!w || w < 5 || w <= avail) return;
    var base = parseFloat(window.getComputedStyle(m).fontSize) || 16;
    var minRatio = m.closest(".col") ? MIN_RATIO_COL : MIN_RATIO;
    var size = base;
    for (var i = 0; i < MAX_ITER + 3 && w > avail; i++) {
      var ratio = avail / w;                       // < 1 دائماً
      var target = size * ratio * 0.97;
      // تصغير فقط، وبسقف أدنى — لا تكبير أبداً
      var next = Math.max(base * minRatio, Math.min(size, target));
      if (!isFinite(next) || next <= 0 || Math.abs(next - size) < 0.2) break;
      size = next;
      m.style.fontSize = size.toFixed(2) + "px";
      w = Math.max(m.getBoundingClientRect().width, m.scrollWidth || 0);
    }
    m.dataset.fitted = "1";
  }

  /* الجداول الأعرض من الصفحة: يُصغَّر حجم خطّها فقط (المحتوى كما هو) */
  function fitTables() {
    var tables = document.querySelectorAll("table.data-table");
    for (var t = 0; t < tables.length; t++) {
      var table = tables[t];
      table.style.fontSize = "";
      var box = table.parentElement || table;
      var avail = box.clientWidth - 2;
      if (avail <= 0) continue;
      var w = Math.max(table.getBoundingClientRect().width, table.scrollWidth || 0);
      if (!w || w <= avail) continue;
      var base = parseFloat(window.getComputedStyle(table).fontSize) || 15;
      var size = base;
      for (var i = 0; i < MAX_ITER && w > avail; i++) {
        var next = Math.max(base * 0.5, Math.min(size, size * (avail / w) * 0.97));
        if (!isFinite(next) || Math.abs(next - size) < 0.2) break;
        size = next;
        table.style.fontSize = size.toFixed(2) + "px";
        w = Math.max(table.getBoundingClientRect().width, table.scrollWidth || 0);
      }
      table.dataset.fitted = "1";
    }
  }

  /* أعمدة لا تلائمها معادلاتها حتى بعد التصغير: يُعاد ترتيب الشبكة صفّاً واحداً
     (الشكل فقط — النصّ وترتيبه كما هما، ولا يُقصّ أي عنصر) */
  function relaxGrids() {
    var grids = document.querySelectorAll(".cols");
    for (var g = 0; g < grids.length; g++) {
      var grid = grids[g];
      if (grid.dataset.relaxed) continue;
      var cols = grid.children, bad = false;
      for (var c = 0; c < cols.length && !bad; c++) {
        var col = cols[c], limit = col.getBoundingClientRect().right + 1;
        var nodes = col.querySelectorAll("math, table, img, svg");
        for (var n = 0; n < nodes.length; n++) {
          var r = nodes[n].getBoundingClientRect();
          if (r.right > limit || r.left < col.getBoundingClientRect().left - 1) { bad = true; break; }
        }
      }
      if (bad) {
        grid.style.gridTemplateColumns = "1fr";
        grid.dataset.relaxed = "1";
      }
    }
  }

  function fitAll() {
    var list = document.querySelectorAll("math");
    for (var i = 0; i < list.length; i++) fitOne(list[i]);
    fitTables();
    relaxGrids();
    // بعد تحويل الشبكات: ملاءمة ثانية للأعمدة التي صارت أوسع
    for (var j = 0; j < list.length; j++) fitOne(list[j]);
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
