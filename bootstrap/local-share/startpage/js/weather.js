// ─── Weather ──────────────────────────────────────────────────────────────────
// Uses Open-Meteo (no API key required).
// If LOCATION (from config.js) is null, asks the browser for geolocation.
(function () {
  const WMO_ICON = {
     0: '☀️', 1: '🌤️', 2: '⛅', 3: '☁️',
    45: '🌫️', 48: '🌫️',
    51: '🌦️', 53: '🌦️', 55: '🌧️',
    61: '🌧️', 63: '🌧️', 65: '🌧️',
    71: '🌨️', 73: '🌨️', 75: '❄️',
    80: '🌦️', 81: '🌧️', 82: '⛈️',
    95: '⛈️', 96: '⛈️', 99: '⛈️',
  };

  const WMO_DESC = {
     0: 'Clear sky', 1: 'Mostly clear', 2: 'Partly cloudy', 3: 'Overcast',
    45: 'Foggy', 48: 'Freezing fog',
    51: 'Light drizzle', 53: 'Drizzle', 55: 'Heavy drizzle',
    61: 'Light rain', 63: 'Rain', 65: 'Heavy rain',
    71: 'Light snow', 73: 'Snow', 75: 'Heavy snow',
    80: 'Rain showers', 81: 'Heavy showers', 82: 'Violent showers',
    95: 'Thunderstorm', 96: 'Hail storm', 99: 'Heavy hail',
  };

  function closestCode(code, map) {
    if (map[code] !== undefined) return map[code];
    for (let c = code; c >= 0; c--) {
      if (map[c] !== undefined) return map[c];
    }
    return '🌡️';
  }

  function setDesc(text) {
    document.getElementById('weather-desc').textContent = text;
  }

  async function fetchWeather(lat, lon) {
    const url =
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${lat}&longitude=${lon}` +
      `&current_weather=true&temperature_unit=celsius`;

    try {
      const res  = await fetch(url);
      const data = await res.json();
      const { temperature, weathercode } = data.current_weather;

      document.getElementById('weather-icon').textContent =
        closestCode(weathercode, WMO_ICON);
      document.getElementById('weather-temp').textContent =
        `${Math.round(temperature)}·°C`;
      setDesc(closestCode(weathercode, WMO_DESC));
    } catch {
      setDesc('Unavailable');
    }
  }

  function startWithCoords(lat, lon) {
    fetchWeather(lat, lon);
    setInterval(() => fetchWeather(lat, lon), 15 * 60 * 1000);
  }

  // ── Location resolution ────────────────────────────────────────────────────
  // LOCATION is defined in config.js.
  // If it's set (manual coords), use it directly.
  // If it's null, fall back to the browser Geolocation API.
  if (LOCATION && typeof LOCATION.lat === 'number') {
    startWithCoords(LOCATION.lat, LOCATION.lon);
  } else if ('geolocation' in navigator) {
    setDesc('Locating…');
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        startWithCoords(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => {
        console.warn('Geolocation denied or failed:', err.message);
        setDesc('Location denied');
        document.getElementById('weather-icon').textContent = '📍';
      },
      { timeout: 10000 }
    );
  } else {
    setDesc('No location');
  }
})();
