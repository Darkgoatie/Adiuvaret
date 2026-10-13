// Page script for the in-app browser. Injected in its own content world, so the page cannot see or change it.
// window.__agent.snapshot(max)   lists what is in view as numbered elements (JSON string)
// window.__agent.act(id, action, value, enter)   click or fill one element (JSON string)
// window.__agent.scroll(direction)   scrolls the page (JSON string)
// window.__agent.readText()   the visible text of the page
(() => {
  if (window.__agent) return;

  const ids = new WeakMap();
  const byId = new Map();
  let nextId = 1;

  const SELECTOR = [
    'a[href]', 'button', 'input:not([type=hidden])', 'select', 'textarea', 'summary',
    '[role=button]', '[role=link]', '[role=checkbox]', '[role=radio]', '[role=tab]', '[role=menuitem]',
    '[role=switch]', '[role=slider]', '[role=option]', '[role=textbox]', '[role=combobox]', '[role=searchbox]',
    '[contenteditable=""]', '[contenteditable=true]', '[onclick]'
  ].join(',');

  const clean = (s, n) => (s || '').replace(/\s+/g, ' ').trim().slice(0, n);

  // Every element a user could use, including inside shadow roots and same-origin frames.
  function collect(root, ox, oy, out, depth) {
    if (depth > 4) return;
    try {
      root.querySelectorAll(SELECTOR).forEach(el => out.push({ el, ox, oy }));
      root.querySelectorAll('*').forEach(el => {
        if (el.shadowRoot) collect(el.shadowRoot, ox, oy, out, depth + 1);
      });
      root.querySelectorAll('iframe').forEach(f => {
        let doc = null;
        try { doc = f.contentDocument; } catch (e) { doc = null; }
        if (doc && doc.documentElement) {
          const r = f.getBoundingClientRect();
          collect(doc, ox + r.left, oy + r.top, out, depth + 1);
        }
      });
    } catch (e) { /* a frame went away while reading */ }
  }

  function roleOf(el) {
    const attr = el.getAttribute('role');
    if (attr) { const r = attr.toLowerCase(); return r === 'searchbox' ? 'textbox' : r; }
    const t = el.tagName.toLowerCase();
    if (t === 'a') return 'link';
    if (t === 'button' || t === 'summary') return 'button';
    if (t === 'select') return 'dropdown';
    if (t === 'textarea') return 'textbox';
    if (t === 'input') {
      const ty = (el.type || 'text').toLowerCase();
      if (ty === 'checkbox') return 'checkbox';
      if (ty === 'radio') return 'radio';
      if (ty === 'range') return 'slider';
      if (['submit', 'button', 'reset', 'image'].includes(ty)) return 'button';
      return 'textbox';
    }
    if (el.isContentEditable) return 'textbox';
    return 'button';
  }

  function labelOf(el) {
    const doc = el.ownerDocument;
    let s = el.getAttribute('aria-label');
    if (!s) {
      const by = el.getAttribute('aria-labelledby');
      if (by) s = by.split(/\s+/).map(i => { const n = doc.getElementById(i); return n ? n.textContent : ''; }).join(' ');
    }
    if (!s && el.labels && el.labels.length) s = el.labels[0].textContent;
    const tag = el.tagName.toLowerCase();
    if (!s && tag === 'input' && ['submit', 'button', 'reset'].includes((el.type || '').toLowerCase())) s = el.value;
    if (!s && tag !== 'input' && tag !== 'textarea' && tag !== 'select') s = el.innerText || el.textContent;
    if (!s) s = el.getAttribute('placeholder');
    if (!s) { const img = el.querySelector && el.querySelector('img[alt]'); if (img) s = img.getAttribute('alt'); }
    if (!s) s = el.getAttribute('title') || el.getAttribute('name') || el.getAttribute('alt');
    return clean(s, 80);
  }

  function isSensitive(el) {
    const type = (el.type || '').toLowerCase();
    const auto = (el.getAttribute('autocomplete') || '').toLowerCase();
    return type === 'password' || auto.includes('password') || auto.includes('cc-') || auto.includes('one-time-code');
  }

  function deepTop(doc, x, y) {
    let e = doc.elementFromPoint(x, y);
    while (e && e.shadowRoot) {
      const inner = e.shadowRoot.elementFromPoint(x, y);
      if (!inner || inner === e) break;
      e = inner;
    }
    return e;
  }

  function composedContains(a, b) {
    for (let n = b; n; n = n.parentNode || n.host) { if (n === a) return true; }
    return false;
  }

  function measure(item) {
    const { el, ox, oy } = item;
    const win = el.ownerDocument.defaultView;
    if (!win) return null;
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return null;
    const cs = win.getComputedStyle(el);
    if (cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) < 0.05) return null;
    const top = r.top + oy, bottom = r.bottom + oy, left = r.left + ox, right = r.right + ox;
    const inView = bottom > 0 && top < window.innerHeight && right > 0 && left < window.innerWidth;
    let covered = false;
    if (inView) {
      const cx = Math.min(Math.max(r.left + r.width / 2, 0), win.innerWidth - 1);
      const cy = Math.min(Math.max(r.top + r.height / 2, 0), win.innerHeight - 1);
      const t = deepTop(el.ownerDocument, cx, cy);
      covered = !!t && !composedContains(el, t) && !composedContains(t, el);
    }
    return { top, bottom, inView, covered };
  }

  function snapshot(max, query) {
    const limit = max || 60;
    const want = clean(query, 60).toLowerCase();
    const all = [];
    collect(document, 0, 0, all, 0);
    const seen = new Set();
    const elements = [];
    let above = 0, below = 0, more = 0, hasPassword = false;
    for (const item of all) {
      if (seen.has(item.el)) continue;
      seen.add(item.el);
      const m = measure(item);
      if (!m) continue;
      const el = item.el;
      if (want && !labelOf(el).toLowerCase().includes(want)) continue;
      if (!m.inView && !want) { if (m.bottom <= 0) above++; else below++; continue; }
      if (m.covered) continue;
      if (el.type && el.type.toLowerCase() === 'password') hasPassword = true;
      if (elements.length >= limit) { more++; continue; }
      let id = ids.get(el);
      if (!id) { id = nextId++; ids.set(el, id); byId.set(id, new WeakRef(el)); }
      const role = roleOf(el);
      const tag = el.tagName.toLowerCase();
      const sensitive = isSensitive(el);
      let value = null;
      if (!sensitive) {
        if (tag === 'select') value = clean(Array.from(el.selectedOptions || []).map(o => o.text).join(', '), 40);
        else if (tag === 'input' || tag === 'textarea') value = clean(el.value, 40);
        else if (role === 'textbox' && el.isContentEditable) value = clean(el.textContent, 40);
      }
      let checked = null;
      if (role === 'checkbox' || role === 'radio' || role === 'switch') {
        checked = typeof el.checked === 'boolean' ? el.checked : el.getAttribute('aria-checked') === 'true';
      }
      elements.push({
        id, role, label: labelOf(el), value,
        type: el.type ? String(el.type).toLowerCase() : null,
        auto: el.getAttribute('autocomplete') || null,
        checked, disabled: !!el.disabled || el.getAttribute('aria-disabled') === 'true',
        offscreen: m.inView ? null : true
      });
    }
    return JSON.stringify({
      url: location.href, title: clean(document.title, 120),
      scrollY: Math.round(window.scrollY), scrollHeight: Math.round(document.documentElement.scrollHeight),
      viewportHeight: window.innerHeight, above, below, more, hasPassword, elements
    });
  }

  function find(id) {
    const ref = byId.get(id);
    const el = ref && ref.deref();
    return el && el.isConnected ? el : null;
  }

  const out = (ok, message, extra) => JSON.stringify(Object.assign({ ok, message }, extra || {}));
  const truthy = v => /^(true|yes|on|check|checked|1)$/i.test(String(v == null ? '' : v).trim());

  function fireInput(el) {
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function setNative(el, value) {
    const proto = el.tagName.toLowerCase() === 'textarea' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value');
    if (setter && setter.set) setter.set.call(el, value); else el.value = value;
  }

  function pressEnter(el) {
    const form = el.form;
    ['keydown', 'keypress', 'keyup'].forEach(t =>
      el.dispatchEvent(new KeyboardEvent(t, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true })));
    if (form && typeof form.requestSubmit === 'function') {
      setTimeout(() => { try { form.requestSubmit(); } catch (e) { /* page handled it */ } }, 150);
    }
  }

  function act(id, action, value, enter) {
    const el = find(id);
    if (!el) return out(false, 'That element is gone. Look at the page again.');
    const label = labelOf(el);
    if (action === 'click') {
      el.scrollIntoView({ block: 'center', inline: 'center' });
      if (el.tagName === 'A' && el.target && el.target !== '_self') el.target = '_self';
      el.click();
      return out(true, 'clicked', { label });
    }
    if (action !== 'fill') return out(false, 'Unknown action.');
    if (isSensitive(el)) return out(false, 'sensitive', { label });
    const tag = el.tagName.toLowerCase();
    const type = (el.type || '').toLowerCase();
    const role = roleOf(el);
    el.scrollIntoView({ block: 'center', inline: 'center' });
    if (tag === 'select') {
      const want = String(value == null ? '' : value).trim().toLowerCase();
      const options = Array.from(el.options);
      const hit = options.find(o => o.text.trim().toLowerCase() === want || o.value.toLowerCase() === want)
        || options.find(o => o.text.trim().toLowerCase().includes(want));
      if (!hit) return out(false, 'No option matches "' + clean(value, 40) + '". Options: ' + options.slice(0, 8).map(o => clean(o.text, 30)).join(', '), { label });
      el.value = hit.value; fireInput(el);
      return out(true, 'chose ' + clean(hit.text, 40), { label });
    }
    if (type === 'checkbox' || type === 'radio' || role === 'checkbox' || role === 'switch' || role === 'radio') {
      const want = type === 'radio' || role === 'radio' ? true : truthy(value);
      const now = typeof el.checked === 'boolean' ? el.checked : el.getAttribute('aria-checked') === 'true';
      if (now !== want) el.click();
      return out(true, want ? 'checked' : 'unchecked', { label });
    }
    if (type === 'range') {
      const n = Number(value);
      if (Number.isNaN(n)) return out(false, 'A number is needed for a slider.', { label });
      const lo = el.min === '' ? 0 : Number(el.min), hi = el.max === '' ? 100 : Number(el.max);
      setNative(el, String(Math.min(Math.max(n, lo), hi))); fireInput(el);
      return out(true, 'set to ' + el.value, { label });
    }
    if (type === 'file') return out(false, 'File fields cannot be filled.', { label });
    if (tag === 'input' || tag === 'textarea') {
      el.focus();
      setNative(el, String(value == null ? '' : value));
      fireInput(el);
      if (enter) pressEnter(el);
      return out(true, enter ? 'typed and pressed Enter' : 'typed', { label });
    }
    if (el.isContentEditable) {
      el.focus();
      document.execCommand('selectAll', false, null);
      if (!document.execCommand('insertText', false, String(value == null ? '' : value))) el.textContent = String(value);
      fireInput(el);
      return out(true, 'typed', { label });
    }
    return out(false, 'This element cannot be typed into.', { label });
  }

  function scroll(direction) {
    const before = window.scrollY;
    const step = Math.round(window.innerHeight * 0.8);
    const doc = document.documentElement;
    if (direction === 'top') window.scrollTo(0, 0);
    else if (direction === 'bottom') window.scrollTo(0, doc.scrollHeight);
    else if (direction === 'up') window.scrollBy(0, -step);
    else window.scrollBy(0, step);
    if (Math.abs(window.scrollY - before) < 2) {
      // The page scrolls inside a container instead of the window.
      let best = null, area = 0;
      document.querySelectorAll('*').forEach(e => {
        const cs = getComputedStyle(e);
        if ((cs.overflowY === 'auto' || cs.overflowY === 'scroll') && e.scrollHeight > e.clientHeight + 20) {
          const a = e.clientWidth * e.clientHeight;
          if (a > area) { area = a; best = e; }
        }
      });
      if (best) {
        if (direction === 'top') best.scrollTop = 0;
        else if (direction === 'bottom') best.scrollTop = best.scrollHeight;
        else best.scrollTop += (direction === 'up' ? -step : step);
      }
    }
    return out(true, 'scrolled');
  }

  // Large pictures on the page (a scanned notice, a menu, a timetable), for text recognition when the page itself has no text.
  function images() {
    const out = [];
    document.querySelectorAll('img').forEach(img => {
      const w = img.naturalWidth || img.width || 0, h = img.naturalHeight || img.height || 0;
      const src = img.currentSrc || img.src || '';
      if (w >= 300 && h >= 120 && /^https:/i.test(src) && out.length < 4 && !out.some(o => o.src === src)) out.push({ src, alt: clean(img.getAttribute('alt') || '', 80) });
    });
    return JSON.stringify(out);
  }

  function readText() { return document.body ? (document.body.innerText || document.body.textContent || '') : ''; }

  Object.defineProperty(window, '__agent', { value: Object.freeze({ snapshot, act, scroll, readText, images }), configurable: false });
})();
