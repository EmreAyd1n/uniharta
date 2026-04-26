import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import './Auth.css';

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const getProfile = async () => {
      const { data: { session } } = await supabase.auth.getSession();

      if (!session) {
        navigate('/login');
        return;
      }

      setUser(session.user);

      // Profil bilgilerini çek
      const { data, error } = await supabase
        .from('profiles')
        .select('full_name, user_type')
        .eq('id', session.user.id)
        .single();

      if (data) {
        setProfile(data);
      } else if (error) {
        console.error('Profil yükleme hatası:', error.message);
        // Fallback: metadata'dan al
        setProfile({
          full_name: session.user.user_metadata?.full_name || '',
          user_type: session.user.user_metadata?.user_type || 'ogrenci',
        });
      }

      setLoading(false);
    };

    getProfile();
  }, [navigate]);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/login');
  };

  if (loading) {
    return (
      <div className="auth-container">
        <div className="spinner" style={{ width: 32, height: 32 }}></div>
      </div>
    );
  }

  const userType = profile?.user_type || 'ogrenci';
  const userTypeLabel = userType === 'organizator' ? '🎯 Organizatör' : '🎓 Öğrenci';

  return (
    <div className="home-container">
      <header className="home-header">
        <h2>
          <span>Uni</span>Harita
        </h2>
        <button className="logout-btn" onClick={handleLogout}>
          Çıkış Yap
        </button>
      </header>

      <main className="home-content">
        <div className="welcome-card">
          <span className="welcome-icon">👋</span>
          <h1>Hoş Geldiniz!</h1>
          <p className="user-email">{user?.email}</p>
          {profile?.full_name && (
            <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: '18px', margin: '0 0 16px 0', fontWeight: 600 }}>
              {profile.full_name}
            </p>
          )}
          <span className={`user-badge ${userType}`}>
            {userTypeLabel}
          </span>
        </div>
      </main>
    </div>
  );
}
