/* ════════════════════════════════════════════════════════════════════
   StudyPulse — Interactions
   ════════════════════════════════════════════════════════════════════ */

(function () {
  'use strict';

  // ── 1. Theme toggle (light / dark) ────────────────────────────────
  const THEME_KEY = 'sp-theme';
  const root = document.documentElement;

  function applyTheme(theme) {
    if (theme === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
  }

  function initTheme() {
    let stored = null;
    try { stored = localStorage.getItem(THEME_KEY); } catch (_) { /* noop */ }
    if (stored === 'light' || stored === 'dark') {
      applyTheme(stored);
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      applyTheme('dark');
    } else {
      applyTheme('light');
    }
  }

  function bindThemeToggle() {
    const btn = document.querySelector('[data-theme-toggle]');
    if (!btn) return;
    btn.addEventListener('click', () => {
      const next = root.classList.contains('dark') ? 'light' : 'dark';
      applyTheme(next);
      try { localStorage.setItem(THEME_KEY, next); } catch (_) { /* noop */ }
    });
  }

  // ── 2. Active nav highlight ───────────────────────────────────────
  function highlightActiveNav() {
    const path = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    const map = {
      'index.html': 'home',
      '': 'home',
      'features.html': 'features',
      'grades.html': 'grades',
      'health.html': 'health',
      'mistakes.html': 'mistakes',
      'exams.html': 'exams',
      'github.html': 'download'
    };
    const current = map[path] || 'home';
    document.querySelectorAll('[data-nav]').forEach((el) => {
      if (el.dataset.nav === current) el.classList.add('is-active');
    });
    document.querySelectorAll('[data-drawer-nav]').forEach((el) => {
      if (el.dataset.drawerNav === current) el.classList.add('is-active');
    });
  }

  // ── 3. Mobile drawer menu ─────────────────────────────────────────
  function setupMobileMenu() {
    const nav = document.querySelector('.nav');
    const hamburger = document.querySelector('.nav-hamburger');
    const drawer = document.querySelector('.nav-drawer');
    if (!nav || !hamburger || !drawer) return;

    hamburger.addEventListener('click', () => {
      nav.classList.toggle('is-open');
    });

    // Close on link click
    drawer.querySelectorAll('a').forEach((a) => {
      a.addEventListener('click', () => nav.classList.remove('is-open'));
    });

    // Close on resize to desktop
    let lastW = window.innerWidth;
    window.addEventListener('resize', () => {
      const w = window.innerWidth;
      if (w >= 768 && lastW < 768) nav.classList.remove('is-open');
      lastW = w;
    });

    // Close on Escape
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') nav.classList.remove('is-open');
    });
  }

  // ── 4. Scroll-reveal via IntersectionObserver ─────────────────────
  function setupReveal() {
    const els = document.querySelectorAll('.reveal');
    if (!els.length || !('IntersectionObserver' in window)) {
      els.forEach((el) => el.classList.add('is-visible'));
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: '0px 0px -50px 0px' }
    );
    els.forEach((el) => io.observe(el));
  }

  // ── 5. HRV ring animate-on-view ───────────────────────────────────
  function animateHrvRing() {
    const ring = document.querySelector('.hrv-ring');
    if (!ring || !('IntersectionObserver' in window)) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            ring.style.animation = 'ringAppear 1s cubic-bezier(0.34, 1.56, 0.64, 1)';
            io.unobserve(ring);
          }
        });
      },
      { threshold: 0.4 }
    );
    io.observe(ring);
  }

  // ── 6. Smooth anchor scroll (fallback for older browsers) ─────────
  function setupSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach((a) => {
      a.addEventListener('click', (e) => {
        const id = a.getAttribute('href');
        if (id.length > 1) {
          const target = document.querySelector(id);
          if (target) {
            e.preventDefault();
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
      });
    });
  }

  // ── 7. Nav background on scroll (subtle tint over dark hero) ──────
  function setupNavTint() {
    const nav = document.querySelector('.nav');
    if (!nav) return;
    const onScroll = () => {
      if (window.scrollY > 24) {
        nav.style.background = 'rgba(29, 29, 31, 0.92)';
      } else {
        nav.style.background = 'rgba(29, 29, 31, 0.8)';
      }
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // ── Boot ──────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    initTheme();
    bindThemeToggle();
    highlightActiveNav();
    setupMobileMenu();
    setupReveal();
    animateHrvRing();
    setupSmoothScroll();
    setupNavTint();
  });
})();
