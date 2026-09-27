// Location
// Browser geolocation configured by setup.sh.
const LOCATION = null;

// ─── Search engines ───────────────────────────────────────────────────────────
const ENGINES = [
  {
    id:    'google',
    label: 'Google',
    icon:  'icons/google.png',
    url:   'https://www.google.com/search?q=',
  },
  {
    id:    'ddg',
    label: 'DuckDuckGo',
    icon:  'icons/duckduckgo.png',
    url:   'https://duckduckgo.com/?q=',
  },
  {
    id:    'bing',
    label: 'Bing',
    icon:  'icons/bing.png',
    url:   'https://www.bing.com/search?q=',
  },
  {
    id:    'brave',
    label: 'Brave Search',
    icon:  'icons/brave.png',
    url:   'https://search.brave.com/search?q=',
  },
];

// ─── Link sections ────────────────────────────────────────────────────────────
// Kept empty because the links module was replaced by Pomodoro.
const LINK_SECTIONS = [];
