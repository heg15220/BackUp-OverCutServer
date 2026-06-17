import React from 'react';
import { Link } from 'react-router-dom';
import './Header.css';
import translations from '../../../i18n/translations';

const lang = navigator.language.startsWith('es') ? 'es' : 'en';
const t = translations[lang];

const Header = () => {
  return (
    <header className="f1hub-header">
      <div className="f1hub-logo">OverCut<span>Hub</span></div>
      <nav className="f1hub-nav">
        <Link to="/">{t.headerHome}</Link>
        <Link to="/tables">{t.headerTables}</Link>
        <Link to="/graphs">{t.headerCharts}</Link>
	{/* ✅ Acceso directo a OverCut */}
        <a className="f1hub-nav-overcut" href="/">
          OverCut
        </a>

      </nav>
    </header>
  );
};

export default Header;
