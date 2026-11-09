// Passes the website's /__/ addresses on to Firebase's sign-in pages
// (tourexpensetracker-33c77.firebaseapp.com/__/...).
//
// Google sign-in then runs on the site's own address, which iPhone Safari
// requires: it blocks sign-in pages on other sites from sharing data with the
// app. See https://firebase.google.com/docs/auth/web/redirect-best-practices
const FIREBASE_HOST = 'tourexpensetracker-33c77.firebaseapp.com';

export async function onRequest({ request }) {
  const url = new URL(request.url);
  if (!url.pathname.startsWith('/__/auth/') && !url.pathname.startsWith('/__/firebase/')) {
    return new Response('Not found', { status: 404 });
  }
  const target = new URL(url.pathname + url.search, 'https://' + FIREBASE_HOST);
  const init = {
    method: request.method,
    headers: request.headers,
    redirect: 'manual',
  };
  if (request.method !== 'GET' && request.method !== 'HEAD') init.body = request.body;
  return fetch(new Request(target, init));
}
