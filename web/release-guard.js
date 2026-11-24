// Inlined into both the stable entry and the exported shell by package_release.py.
// Never cache the pointer to the current release. Game files have release-specific names.
window.villageReleaseReady = (async () => {
  const versionURL = new URL('./build-info.json', location.href);
  versionURL.searchParams.set('check', String(Date.now())); // Also bypass the Pages CDN.
  const response = await fetch(versionURL, {cache: 'no-store'});
  if (!response.ok) throw new Error('Не удалось проверить версию игры');
  const release = await response.json();
  if (!/^[a-f0-9]{40}$/.test(release.commit) || release.entry !== `index.${release.commit}.html`) {
    throw new Error('Неверные данные версии игры');
  }
  const entry = new URL(release.entry, location.href);
  if (location.pathname !== entry.pathname) {
    location.replace(entry.href);
    return false;
  }
  // Keep reloads and bookmarks on the stable URL after selecting the release.
  history.replaceState(null, '', new URL('./', location.href));
  document.documentElement.dataset.build = release.commit;
  return true;
})();
// Returning from Safari's back/forward cache must also check for an update.
window.addEventListener('pageshow', event => { if (event.persisted) location.reload(); });
