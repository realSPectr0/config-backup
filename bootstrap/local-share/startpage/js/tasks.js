// ─── Tasks ────────────────────────────────────────────────────────────────────
(function () {
  const list     = document.getElementById('taskList');
  const input    = document.getElementById('taskInput');
  const addBtn   = document.getElementById('addTaskBtn');

  const STORAGE_KEY = 'startpage:tasks';

  // ── Persistence ──────────────────────────────────────────────────────────
  function load() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || []; }
    catch { return []; }
  }

  function save() {
    const tasks = [...list.querySelectorAll('.task-item')].map(el => ({
      text: el.querySelector('.task-text').textContent,
      done: el.classList.contains('done'),
    }));
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks));
  }

  // ── Render a single task ──────────────────────────────────────────────────
  function createTaskEl({ text, done = false }) {
    const li = document.createElement('li');
    li.className = 'task-item' + (done ? ' done' : '');

    // Checkbox circle
    const check = document.createElement('div');
    check.className = 'task-check';
    check.innerHTML = `
      <svg viewBox="0 0 9 7" fill="none">
        <polyline points="1,3.5 3.5,6 8,1" stroke="rgba(120,180,255,0.9)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;

    // Text
    const span = document.createElement('span');
    span.className   = 'task-text';
    span.textContent = text;

    // Delete button
    const del = document.createElement('button');
    del.className = 'task-delete';
    del.title     = 'Remove task';
    del.innerHTML = `
      <svg viewBox="0 0 9 9" fill="none">
        <line x1="1" y1="1" x2="8" y2="8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        <line x1="8" y1="1" x2="1" y2="8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>`;

    // Toggle done on row / check click
    function toggle(e) {
      if (e.target.closest('.task-delete')) return;
      li.classList.toggle('done');
      save();
    }

    li.addEventListener('click', toggle);

    del.addEventListener('click', e => {
      e.stopPropagation();
      li.remove();
      save();
    });

    li.appendChild(check);
    li.appendChild(span);
    li.appendChild(del);
    return li;
  }

  function addTask(text) {
    const trimmed = text.trim();
    if (!trimmed) return;
    list.appendChild(createTaskEl({ text: trimmed }));
    save();
  }

  // ── Add button ───────────────────────────────────────────────────────────
  addBtn.addEventListener('click', () => {
    input.classList.toggle('visible');
    if (input.classList.contains('visible')) input.focus();
  });

  input.addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      addTask(input.value);
      input.value = '';
      input.classList.remove('visible');
    }
    if (e.key === 'Escape') {
      input.value = '';
      input.classList.remove('visible');
    }
  });

  // ── Init from storage ─────────────────────────────────────────────────────
  const saved = load();
  if (saved.length) {
    saved.forEach(t => list.appendChild(createTaskEl(t)));
  } else {
    // Default placeholder tasks
    ['Review pull requests', 'Submit assignment', 'Morning standup'].forEach(t =>
      list.appendChild(createTaskEl({ text: t }))
    );
    save();
  }
})();
