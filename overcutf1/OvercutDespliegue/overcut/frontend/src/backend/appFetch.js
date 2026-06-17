import NetworkError from "./NetworkError";
import { config } from "../config/constants";

let networkErrorCallback;
let reauthenticationCallback;

export const SERVICE_TOKEN_CHANGED_EVENT = "overcut:service-token-changed";

const notifyServiceTokenChanged = () => {
  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(SERVICE_TOKEN_CHANGED_EVENT));
  }
};

// --- Helpers de almacenamiento (token persistente o de sesion) ---
const setTokenIn = (storage, token) => {
  try { storage.setItem(config.SERVICE_TOKEN_NAME, token); } catch {}
};
const getTokenFrom = (storage) => {
  try { return storage.getItem(config.SERVICE_TOKEN_NAME); } catch { return null; }
};
const removeTokenFrom = (storage) => {
  try { storage.removeItem(config.SERVICE_TOKEN_NAME); } catch {}
};

const isJson = (response) => {
    const contentType = response.headers.get("content-type");

    return contentType && contentType.indexOf("application/json") !== -1;
};

const handleOkResponse = (response, onSuccess) => {
    if (!response.ok) {
        return false;
    }

    if (!onSuccess) {
        return true;
    }

    if (response.status === 204) {
        onSuccess();
        return true;
    }

    if (isJson(response)) {
        response.json().then((payload) => onSuccess(payload));
    } else {
        response.blob().then((blob) => onSuccess(blob));
    }

    return true;
};

const handle4xxResponse = (response, onErrors) => {
    if (response.status < 400 || response.status >= 500) {
        return false;
    }

    if (response.status === 401 && reauthenticationCallback) {
        reauthenticationCallback();
        return true;
    }

    if (!isJson(response)) {
        throw new NetworkError();
    }

    if (onErrors) {
        response.json().then((payload) => {
            if (payload.globalError || payload.fieldErrors) {
                onErrors(payload);
            }
        });
    }

    return true;
};

const handleResponse = (response, onSuccess, onErrors) => {
    if (handleOkResponse(response, onSuccess)) {
        return;
    }

    if (handle4xxResponse(response, onErrors)) {
        return;
    }

    throw new NetworkError();
};

export const init = (callback) => (networkErrorCallback = callback);

export const setReauthenticationCallback = (callback) =>
    (reauthenticationCallback = callback);

// remember = true => localStorage (persistente). false => sessionStorage.
export const setServiceToken = (serviceToken, remember = false) => {
  if (remember) {
    setTokenIn(localStorage, serviceToken);
    removeTokenFrom(sessionStorage);
  } else {
    setTokenIn(sessionStorage, serviceToken);
    removeTokenFrom(localStorage);
  }

  notifyServiceTokenChanged();
};

export const getServiceToken = () =>
  getTokenFrom(localStorage) || getTokenFrom(sessionStorage);

export const removeServiceToken = () => {
  removeTokenFrom(localStorage);
  removeTokenFrom(sessionStorage);
  notifyServiceTokenChanged();
};

export const fetchConfig = (method, body) => {
    const fConfig = {
        method: method,
        cache: "no-store",
    };

    if (body) {
        if (body instanceof FormData) {
            fConfig.body = body;
        } else {
            fConfig.headers = { "Content-Type": "application/json", "Cache-Control": "no-store" };
            fConfig.body = JSON.stringify(body);
        }
    }

    const serviceToken = getServiceToken();

    if (serviceToken) {
        if (fConfig.headers) {
            fConfig.headers["Authorization"] = `Bearer ${serviceToken}`;
        } else {
            fConfig.headers = { Authorization: `Bearer ${serviceToken}`, "Cache-Control": "no-store" };
        }
    }

    return fConfig;
};

export const appFetch = (path, options, onSuccess, onErrors) =>
    fetch(`${config.BASE_PATH}${path}`, options)
        .then((response) => handleResponse(response, onSuccess, onErrors))
        .catch((error) => {
            if (networkErrorCallback) {
                networkErrorCallback(error);
            }
            if (onErrors) {
                onErrors(error);
            }
        });
