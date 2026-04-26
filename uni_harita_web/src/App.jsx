import { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { supabase } from './supabaseClient';

import Login from './pages/Login';
import Register from './pages/Register';
import Home from './pages/Home';

function App() {
  const [session, setSession] = useState(undefined); // undefined = loading

  useEffect(() => {
    // Mevcut oturumu kontrol et
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
    });

    // Auth durumu değişikliklerini dinle
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setSession(session);
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  // Yükleniyor durumu
  if (session === undefined) {
    return null;
  }

  return (
    <Router>
      <Routes>
        <Route
          path="/login"
          element={session ? <Navigate to="/home" replace /> : <Login />}
        />
        <Route
          path="/register"
          element={session ? <Navigate to="/home" replace /> : <Register />}
        />
        <Route
          path="/home"
          element={session ? <Home /> : <Navigate to="/login" replace />}
        />
        <Route
          path="*"
          element={<Navigate to={session ? '/home' : '/login'} replace />}
        />
      </Routes>
    </Router>
  );
}

export default App;
