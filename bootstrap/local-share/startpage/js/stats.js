// ─── System Stats ─────────────────────────────────────────────────────────────
// Fetches real data from stats-bridge.py running on localhost:7070
// Falls back to simulated values if the bridge isn't running.
(function () {
  const els = {
    cpuVal:  document.getElementById('cpu-val'),
    cpuBar:  document.getElementById('cpu-bar'),
    ramVal:  document.getElementById('ram-val'),
    ramBar:  document.getElementById('ram-bar'),
    tempVal: document.getElementById('temp-val'),
    tempBar: document.getElementById('temp-bar'),
  };

  function render({ cpu, ramUsed, ramTotal, temp }) {
    els.cpuVal.textContent  = `${cpu}%`;
    els.cpuBar.style.width  = `${cpu}%`;

    els.ramVal.textContent  = `${ramUsed} / ${ramTotal} GiB`;
    els.ramBar.style.width  = `${(ramUsed / ramTotal) * 100}%`;

    const tempStr = temp !== null ? `${temp}°C` : '—';
    els.tempVal.textContent = tempStr;
    els.tempBar.style.width = temp !== null ? `${Math.min(temp, 100)}%` : '0%';
  }

  function simulated() {
    return {
      cpu:      Math.round(15 + Math.random() * 25),
      ramUsed:  +(1.8 + Math.random() * 0.8).toFixed(1),
      ramTotal: 16,
      temp:     Math.round(42 + Math.random() * 12),
    };
  }

  async function fetchStats() {
    try {
      const res  = await fetch('http://localhost:7070/stats');
      const data = await res.json();
      render(data);
    } catch {
      render(simulated());
    }
  }

  fetchStats();
  setInterval(fetchStats, 3000);
})();
