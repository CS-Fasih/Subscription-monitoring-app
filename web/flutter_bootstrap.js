{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString() },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('loading')?.remove();
      if ('serviceWorker' in navigator) {
        // The production build generates a versioned, same-origin offline cache.
        // Failure to cache never prevents the app or local storage from working.
        navigator.serviceWorker.register(new URL('sw.js', document.baseURI))
          .catch(() => {});
      }
    } catch (error) {
      document.getElementById('loading-message').textContent =
        'Your workspace could not open. Please reload and try again.';
      const retry = document.createElement('button');
      retry.textContent = 'Reload';
      retry.addEventListener('click', () => location.reload());
      document.getElementById('loading').append(retry);
      console.error('Tally startup failed', error);
    }
  }
});
