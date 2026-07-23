{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: {
    // Self-host CanvasKit from our own origin instead of the gstatic.com CDN
    // default. Serving it alongside the rest of the app avoids an extra
    // cross-origin DNS/TLS handshake on first paint (worse on slow/Hamburg
    // site-office connections) and keeps EU visitor traffic off a Google
    // domain. build/web/canvaskit/ is already produced by `flutter build web`
    // and already cached by firebase.json's canvaskit/** rule — this just
    // makes the app actually use it instead of the CDN copy.
    canvasKitBaseUrl: "canvaskit/",
  },
});
