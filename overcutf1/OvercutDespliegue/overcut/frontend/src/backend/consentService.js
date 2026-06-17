// src/cookies/consentService.js
import { appFetch, fetchConfig } from "./appFetch";

const consentFetchConfig = (method, body) => ({
  ...fetchConfig(method, body),
  credentials: "include",
});

export const getConsent = (onSuccess, onErrors) =>
  appFetch("/consent", consentFetchConfig("GET"), onSuccess, onErrors);

export const saveConsent = (consent, onSuccess, onErrors) =>
  appFetch("/consent", consentFetchConfig("PUT", consent), onSuccess, onErrors);
