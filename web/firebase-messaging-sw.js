// Firebase Cloud Messaging service worker — handles push notifications when
// no Capacify tab has focus. Runs in its own worker context (no access to the
// Flutter app's Dart runtime), so the project config below is duplicated from
// lib/firebase_options.dart's `web` block rather than shared with it.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC9g9HUEbMUVHYmuv9li102q8Eerd8zTbk',
  appId: '1:903715286905:web:c79bb75cce51557cd089a8',
  messagingSenderId: '903715286905',
  projectId: 'capacify-mvp',
  authDomain: 'capacify-mvp.firebaseapp.com',
  storageBucket: 'capacify-mvp.firebasestorage.app',
});

const messaging = firebase.messaging();

// Background (no-focus) messages arrive here; foreground messages are
// handled entirely in Dart (FirebaseMessaging.onMessage), not here.
messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Capacify';
  const body = (payload.notification && payload.notification.body) || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
