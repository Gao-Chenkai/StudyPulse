// StudyPulse — Apple-style scroll-driven animations
(function() {
  'use strict';

  // ── Scroll-progress tracker ──────────────────────────────
  // Elements with data-animate="type" get progress-driven transforms.
  // Types: scale-up | slide-left | slide-right | expand | fade-up
  var animatedEls = [];
  var ticking = false;

  function collectAnimatedEls() {
    var els = document.querySelectorAll('[data-animate]');
    animatedEls = [];
    els.forEach(function(el) {
      animatedEls.push({
        el: el,
        type: el.getAttribute('data-animate') || 'fade-up',
        delay: parseInt(el.getAttribute('data-delay') || '0', 10),
        top: 0,
        height: 0,
        progress: 0,
        triggered: false
      });
    });
  }

  function updatePositions() {
    animatedEls.forEach(function(item) {
      var rect = item.el.getBoundingClientRect();
      item.top = rect.top + window.scrollY;
      item.height = rect.height;
    });
  }

  function onScroll() {
    if (!ticking) {
      requestAnimationFrame(updateAnimations);
      ticking = true;
    }
  }

  function updateAnimations() {
    var vh = window.innerHeight;
    animatedEls.forEach(function(item) {
      var elTop = item.el.getBoundingClientRect().top;
      // Progress: 0 (just entered bottom) → 1 (fully visible, centered)
      var raw = 1 - (elTop / (vh * 0.85));
      raw = Math.max(0, Math.min(1, raw));
      item.progress = raw;

      if (raw > 0.05 && !item.triggered) {
        item.triggered = true;
      }

      applyTransform(item);
    });
    ticking = false;
  }

  function applyTransform(item) {
    var p = item.progress;
    var el = item.el;
    var type = item.type;

    // Clamp out for elements that haven't triggered yet
    if (!item.triggered) {
      el.style.opacity = '0';
      return;
    }

    // Eased progress (cubic ease-out)
    var ep = 1 - Math.pow(1 - Math.min(1, p * 1.2), 3);

    switch (type) {
      case 'scale-up':
        el.style.opacity = ep;
        el.style.transform = 'scale(' + (0.88 + 0.12 * ep) + ') translateY(' + (24 * (1 - ep)) + 'px)';
        break;
      case 'slide-left':
        el.style.opacity = ep;
        el.style.transform = 'translateX(' + (-40 * (1 - ep)) + 'px)';
        break;
      case 'slide-right':
        el.style.opacity = ep;
        el.style.transform = 'translateX(' + (40 * (1 - ep)) + 'px)';
        break;
      case 'expand':
        el.style.opacity = ep;
        el.style.transform = 'scale(' + (0.9 + 0.1 * ep) + ') translateY(' + (16 * (1 - ep)) + 'px)';
        break;
      case 'feature-img':
        el.style.opacity = ep;
        el.style.transform = 'scale(' + (0.94 + 0.06 * ep) + ')';
        el.style.filter = 'brightness(' + (0.92 + 0.08 * ep) + ')';
        break;
      default: // fade-up
        el.style.opacity = ep;
        el.style.transform = 'translateY(' + (28 * (1 - ep)) + 'px)';
    }
  }

  // ── Hero immediate reveal ────────────────────────────────
  function revealHero() {
    var heroEls = document.querySelectorAll('.hero [data-animate]');
    heroEls.forEach(function(el, i) {
      setTimeout(function() {
        el.style.opacity = '1';
        el.style.transform = 'scale(1) translateY(0)';
      }, i * 80 + 60);
    });
  }

  // ── Number counter ───────────────────────────────────────
  function setupCounters() {
    var statObserver = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          animateCount(entry.target);
          statObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });

    document.querySelectorAll('.stat-value[data-count]').forEach(function(el) {
      statObserver.observe(el);
    });
  }

  function animateCount(el) {
    var target = parseInt(el.getAttribute('data-count'), 10);
    var suffix = el.getAttribute('data-suffix') || '';
    var duration = 1400;
    var startTime = null;

    function step(ts) {
      if (!startTime) startTime = ts;
      var progress = Math.min((ts - startTime) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = Math.floor(eased * target) + suffix;
      if (progress < 1) requestAnimationFrame(step);
      else el.textContent = target + suffix;
    }
    requestAnimationFrame(step);
  }

  // ── Nav shadow on scroll ─────────────────────────────────
  var nav = document.querySelector('.nav');
  var lastScroll = 0;

  function updateNav() {
    var y = window.scrollY;
    if (y > 30 && !nav.classList.contains('nav-scrolled')) {
      nav.classList.add('nav-scrolled');
    } else if (y <= 30 && nav.classList.contains('nav-scrolled')) {
      nav.classList.remove('nav-scrolled');
    }
  }

  // ── Init ─────────────────────────────────────────────────
  function init() {
    collectAnimatedEls();
    updatePositions();
    revealHero();
    setupCounters();

    window.addEventListener('scroll', function() {
      updateNav();
      onScroll();
    }, { passive: true });

    window.addEventListener('resize', function() {
      updatePositions();
      onScroll();
    }, { passive: true });

    // Initial paint
    requestAnimationFrame(function() {
      updatePositions();
      onScroll();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
