import { configureStore } from '@reduxjs/toolkit';
import storage from 'redux-persist/lib/storage';
import { persistReducer, persistStore } from 'redux-persist';
import rootReducer from './rootReducer';

const persistConfig = {
    key: 'root',
    storage,
    blacklist: ['users'], // ⛔️ no persistir el slice users a nivel root
};

const persistedReducer = persistReducer(persistConfig, rootReducer);

// Aplica redux-thunk como middleware
const store = configureStore({
    reducer: persistedReducer,
});

const persistor = persistStore(store);

export { store, persistor };
