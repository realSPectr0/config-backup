// ─── Notes ────────────────────────────────────────────────────────────────────
(function () {
  const area = document.getElementById('notesArea');
  const KEY  = 'startpage:notes';

  // Load saved note
  area.value = localStorage.getItem(KEY) || '';

  // Debounced save
  let timer;
  area.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => localStorage.setItem(KEY, area.value), 500);
  });
})();
