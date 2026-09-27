// ─── Search ───────────────────────────────────────────────────────────────────
(function () {
  let activeEngine = ENGINES[0];

  const btn      = document.getElementById('engineBtn');
  const menu     = document.getElementById('engineMenu');
  const iconEl   = document.getElementById('engineIcon');
  const labelEl  = document.getElementById('engineLabel');
  const input    = document.getElementById('searchInput');

  // Build menu options
  ENGINES.forEach(engine => {
    const opt = document.createElement('div');
    opt.className = 'engine-option' + (engine === activeEngine ? ' active' : '');
    opt.innerHTML = `<img src="${engine.icon}" alt="" />${engine.label}`;
    opt.addEventListener('click', () => selectEngine(engine, opt));
    menu.appendChild(opt);
  });

  function selectEngine(engine, optEl) {
    activeEngine = engine;
    iconEl.src        = engine.icon;
    labelEl.textContent = engine.label;
    menu.querySelectorAll('.engine-option').forEach(o => o.classList.remove('active'));
    optEl.classList.add('active');
    closeMenu();
    input.focus();
  }

  function openMenu()  { menu.classList.add('open'); }
  function closeMenu() { menu.classList.remove('open'); }
  function toggleMenu() { menu.classList.contains('open') ? closeMenu() : openMenu(); }

  btn.addEventListener('click', e => { e.stopPropagation(); toggleMenu(); });

  document.addEventListener('click', e => {
    if (!e.target.closest('#enginePicker')) closeMenu();
  });

  input.addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      const q = input.value.trim();
      if (q) window.open(activeEngine.url + encodeURIComponent(q), '_blank');
    }
  });

  // Set initial icon
  iconEl.src          = activeEngine.icon;
  labelEl.textContent = activeEngine.label;
})();
