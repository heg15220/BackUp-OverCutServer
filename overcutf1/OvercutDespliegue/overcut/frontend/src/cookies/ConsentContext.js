import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import { SERVICE_TOKEN_CHANGED_EVENT } from "../backend/appFetch";
import { getConsent, saveConsent } from "../backend/consentService";
import {
  loadScriptOnce,
  insertRawScriptOnce,
  unloadAllByPrefix,
} from "./ScriptManager";

const ConsentContext = createContext(null);

export const ConsentProvider = ({ children }) => {
  const [loaded, setLoaded] = useState(false);

  const [preferences, setPreferences] = useState(false);
  const [analytics, setAnalytics] = useState(false);
  const [ads, setAds] = useState(false);

  // Cerrado por defecto: no mostramos el intro hasta saber si ya hay decision valida.
  const [bannerOpen, setBannerOpen] = useState(false);
  const [configOpen, setConfigOpen] = useState(false);

  const loadConsent = useCallback(() => {
    setLoaded(false);
    setBannerOpen(false);

    getConsent(
      (dto) => {
        const nextPreferences = !!dto?.preferences;
        const nextAnalytics = !!dto?.analytics;
        const nextAds = !!dto?.ads;
        const hasDecision = dto?.decided === true;

        setPreferences(nextPreferences);
        setAnalytics(nextAnalytics);
        setAds(nextAds);
        setBannerOpen(!hasDecision);
        setConfigOpen(false);
        setLoaded(true);
      },
      () => {
        setPreferences(false);
        setAnalytics(false);
        setAds(false);
        setBannerOpen(true);
        setConfigOpen(false);
        setLoaded(true);
      }
    );
  }, []);

  useEffect(() => {
    loadConsent();

    const onServiceTokenChanged = () => loadConsent();
    window.addEventListener(SERVICE_TOKEN_CHANGED_EVENT, onServiceTokenChanged);

    return () => {
      window.removeEventListener(SERVICE_TOKEN_CHANGED_EVENT, onServiceTokenChanged);
    };
  }, [loadConsent]);

  useEffect(() => {
    if (!loaded) return;

    if (analytics) {
      loadScriptOnce(
        "ga:gtag",
        "https://www.googletagmanager.com/gtag/js?id=G-XXXXXXX"
      );

      insertRawScriptOnce(
        "ga:init",
        `
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', 'G-XXXXXXX', { anonymize_ip: true });
        `
      );
    } else {
      unloadAllByPrefix("ga:");
    }

    if (ads) {
      loadScriptOnce(
        "ads:gtm",
        "https://www.googletagmanager.com/gtm.js?id=GTM-YYYYYYY"
      );
    } else {
      unloadAllByPrefix("ads:");
    }
  }, [loaded, analytics, ads]);

  const setAndPersist = (next) => {
    const normalized = {
      preferences: !!next.preferences,
      analytics: !!next.analytics,
      ads: !!next.ads,
    };

    setPreferences(normalized.preferences);
    setAnalytics(normalized.analytics);
    setAds(normalized.ads);

    saveConsent(normalized, () => {
      setPreferences(normalized.preferences);
      setAnalytics(normalized.analytics);
      setAds(normalized.ads);
    });
  };

  const acceptAll = () => {
    setAndPersist({
      preferences: true,
      analytics: true,
      ads: true,
    });

    setBannerOpen(false);
    setConfigOpen(false);
  };

  const rejectAll = () => {
    setAndPersist({
      preferences: false,
      analytics: false,
      ads: false,
    });

    setBannerOpen(false);
    setConfigOpen(false);
  };

  const openConfig = () => {
    setBannerOpen(true);
    setConfigOpen(true);
  };

  const save = (flags) => {
    setAndPersist({
      preferences: !!flags.preferences,
      analytics: !!flags.analytics,
      ads: !!flags.ads,
    });

    setBannerOpen(false);
    setConfigOpen(false);
  };

  const value = useMemo(
    () => ({
      loaded,

      preferences,
      analytics,
      ads,

      bannerOpen,
      setBannerOpen,

      configOpen,
      setConfigOpen,

      openConfig,

      acceptAll,
      rejectAll,
      save,
    }),
    [
      loaded,
      preferences,
      analytics,
      ads,
      bannerOpen,
      configOpen,
    ]
  );

  return (
    <ConsentContext.Provider value={value}>
      {children}
    </ConsentContext.Provider>
  );
};

export const useConsent = () => {
  const ctx = useContext(ConsentContext);

  if (!ctx) {
    throw new Error("useConsent must be used within <ConsentProvider/>");
  }

  return ctx;
};
