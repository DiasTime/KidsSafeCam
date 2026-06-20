// Firebase Cloud Messaging service worker for the parent web app. Receives
// background pushes and displays them. The config below is the public web
// client config (mirrors lib/firebase_options.dart) — not a secret.
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyDwDhFsmFTgm43LtxHZm1AvJLDQVGmB9g8",
  authDomain: "kidssafecam.firebaseapp.com",
  projectId: "kidssafecam",
  storageBucket: "kidssafecam.firebasestorage.app",
  messagingSenderId: "397994773229",
  appId: "1:397994773229:web:9f4c155fa815868cc9dae4",
});

// Messages carrying a `notification` payload are displayed by the browser
// automatically; this also covers any data-only fallbacks.
const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || "Baby Monitor", {
    body: n.body || "",
    icon: "/icons/Icon-192.png",
  });
});
