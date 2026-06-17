import React from 'react';
import ReactDOM from 'react-dom/client';

import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { IntlProvider } from 'react-intl';

import messages from './i18n/messages';

import users from './modules/users';

import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap';

import { store, persistor } from './store';
import backend from './backend';
import { getServiceToken } from './backend/appFetch';
import app from './modules/app';
import App from './modules/app/components/App';

/* Configure backend proxy. */
backend.init(error => store.dispatch(app.actions.error(new backend.NetworkError())));

/* Detect and apply browser language */
const browserLocale = navigator.language.startsWith('es') ? 'es' : 'en';
const defaultLocale = browserLocale in messages ? browserLocale : 'en';


store.dispatch(users.actions.tryLoginFromServiceToken());

/* 🔒 Guard de arranque: si hay user persistido pero NO token, forzar logout */
const token = getServiceToken?.();
const state = store.getState();
const persistedUser = state?.users?.user;
if (persistedUser && !token) {
  store.dispatch(users.actions.logout());
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("/service-worker.js")
      .catch(() => {});
  });
}



/* Render application. */
const root = ReactDOM.createRoot(document.getElementById('root'));

// ✅ Migración HashRouter -> BrowserRouter
if (window.location.hash && window.location.hash.startsWith("#/")) {
  const newPath = window.location.hash.slice(1); // quita "#"
  window.history.replaceState(null, "", newPath + window.location.search);
}


root.render(
  <React.StrictMode>
    <Provider store={store}>
      <IntlProvider locale={defaultLocale} messages={messages[defaultLocale]}>
        <PersistGate loading={null} persistor={persistor}>
          <App />
        </PersistGate>
      </IntlProvider>
    </Provider>
  </React.StrictMode>
);
