// ─── Media Player ─────────────────────────────────────────────────────────────
// Connects to media-bridge.py WebSocket on localhost:7071
// Shows currently playing track from Spotify (or any MPRIS player).
(function () {
  const artEl    = document.getElementById('mediaArt');
  const titleEl  = document.getElementById('mediaTitle');
  const artistEl = document.getElementById('mediaArtist');
  const playBtn  = document.getElementById('playBtn');
  const playIcon = document.getElementById('playIcon');

  let playing = false;

  const ICONS = {
    play:  '<path d="M8 5v14l11-7z"/>',
    pause: '<rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/>',
  };

  function setPlaying(state) {
    playing = state;
    playIcon.innerHTML = playing ? ICONS.pause : ICONS.play;
  }

  function applyState({ status, title, artist, art }) {
    const isPlaying = status === 'Playing';
    setPlaying(isPlaying);

    titleEl.textContent  = title  || 'Nothing playing';
    artistEl.textContent = artist || '—';

    if (art && art.startsWith('http')) {
      artEl.style.backgroundImage = `url(${art})`;
      artEl.style.backgroundSize  = 'cover';
      artEl.textContent = '';
    } else {
      artEl.style.backgroundImage = '';
      artEl.textContent = '♪';
    }
  }

  function playerctl(cmd) {
    // Sends a command back — requires the bridge to support POST
    // For now, open Spotify as fallback
    window.open('https://open.spotify.com', '_blank');
  }

  playBtn.addEventListener('click', () => {
    fetch('http://localhost:7072/cmd', {
      method: 'POST',
      body: JSON.stringify({ cmd: 'play-pause' }),
    }).catch(() => {});
  });

  document.getElementById('prevBtn').addEventListener('click', () => {
    fetch('http://localhost:7072/cmd', {
      method: 'POST',
      body: JSON.stringify({ cmd: 'previous' }),
    }).catch(() => {});
  });

  document.getElementById('nextBtn').addEventListener('click', () => {
    fetch('http://localhost:7072/cmd', {
      method: 'POST',
      body: JSON.stringify({ cmd: 'next' }),
    }).catch(() => {});
  });

  // ── WebSocket connection with auto-reconnect ──────────────────────────────
  function connect() {
    const ws = new WebSocket('ws://localhost:7071');

    ws.addEventListener('message', ({ data }) => {
      try { applyState(JSON.parse(data)); } catch {}
    });

    ws.addEventListener('close', () => {
      // Retry after 3s if bridge isn't running yet
      setTimeout(connect, 3000);
    });

    ws.addEventListener('error', () => {
      ws.close();
    });
  }

  connect();
})();
