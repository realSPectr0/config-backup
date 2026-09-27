// ─── Links ────────────────────────────────────────────────────────────────────
(function () {
  const container = document.getElementById('linksGrid');

  LINK_SECTIONS.forEach(section => {
    const sec = document.createElement('div');
    sec.className = 'link-section';

    const heading = document.createElement('h3');
    heading.textContent = section.title;
    sec.appendChild(heading);

    const list = document.createElement('div');
    list.className = 'links-list';

    section.links.forEach(link => {
      const a = document.createElement('a');
      a.className = 'link-item';
      a.href      = link.href;
      a.target    = '_blank';
      a.rel       = 'noopener noreferrer';

      // Icon — try image, fall back to letter badge
      const img = document.createElement('img');
      img.src   = link.icon;
      img.alt   = '';
      img.className = 'link-icon';

      img.addEventListener('error', () => {
        // Replace with fallback letter badge
        img.replaceWith(makeFallback(link));
      });

      const label = document.createElement('span');
      label.textContent = link.label;

      a.appendChild(img);
      a.appendChild(label);
      list.appendChild(a);
    });

    sec.appendChild(list);
    container.appendChild(sec);
  });

  function makeFallback(link) {
    const fb = link.fallback || { letter: link.label[0], color: '#888' };
    const el = document.createElement('span');
    el.className = 'link-icon-text';
    el.textContent = fb.letter;
    el.style.background = hexToRgba(fb.color, 0.18);
    el.style.color      = fb.color;
    return el;
  }

  function hexToRgba(hex, alpha) {
    // Accepts hex or just return color directly for named/emoji colors
    if (!hex.startsWith('#')) return hex;
    const n = parseInt(hex.slice(1), 16);
    const r = (n >> 16) & 255;
    const g = (n >>  8) & 255;
    const b =  n        & 255;
    return `rgba(${r},${g},${b},${alpha})`;
  }
})();
