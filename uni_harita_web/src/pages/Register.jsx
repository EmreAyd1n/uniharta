import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import './Auth.css';

export default function Register() {
  const navigate = useNavigate();
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [userType, setUserType] = useState('ogrenci');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleRegister = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    try {
      const { data, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            user_type: userType,
          },
        },
      });

      if (authError) throw authError;

      // Supabase e-posta onayı aktifse kullanıcıya bilgi ver
      if (data.user && data.user.identities && data.user.identities.length === 0) {
        setError('Bu e-posta adresi zaten kayıtlı.');
      } else if (data.session) {
        // Oturum oluşturulduysa direkt yönlendir
        console.log('Kayıt başarılı, oturum açıldı:', data.user.email);
        navigate('/home');
      } else {
        // E-posta onayı gerekiyorsa bilgilendir
        setSuccess('Kayıt başarılı! Lütfen e-posta adresinizi doğrulayın, ardından giriş yapabilirsiniz.');
      }
    } catch (err) {
      setError(err.message || 'Kayıt olurken bir hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <div className="auth-brand">
          <span className="logo-icon">🗺️</span>
          <h1>UniHarita</h1>
          <p>Yeni hesap oluşturun</p>
        </div>

        {error && <div className="auth-message error">{error}</div>}
        {success && <div className="auth-message success">{success}</div>}

        <form className="auth-form" onSubmit={handleRegister}>
          <div className="input-group">
            <label htmlFor="register-fullname">Ad Soyad</label>
            <input
              id="register-fullname"
              type="text"
              placeholder="Adınız Soyadınız"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
            />
          </div>

          <div className="input-group">
            <label htmlFor="register-email">E-posta</label>
            <input
              id="register-email"
              type="email"
              placeholder="ornek@universite.edu.tr"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="input-group">
            <label htmlFor="register-password">Şifre</label>
            <input
              id="register-password"
              type="password"
              placeholder="En az 6 karakter"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>

          <div className="input-group">
            <label htmlFor="register-usertype">Kullanıcı Tipi</label>
            <select
              id="register-usertype"
              value={userType}
              onChange={(e) => setUserType(e.target.value)}
              required
            >
              <option value="ogrenci">🎓 Öğrenci</option>
              <option value="organizator">🎯 Organizatör</option>
            </select>
          </div>

          <button type="submit" className="auth-btn" disabled={loading}>
            {loading ? (
              <>
                <span className="spinner"></span>
                Kayıt Yapılıyor...
              </>
            ) : (
              'Kayıt Ol'
            )}
          </button>
        </form>

        <div className="auth-footer">
          Zaten hesabınız var mı?{' '}
          <Link to="/login">Giriş Yap</Link>
        </div>
      </div>
    </div>
  );
}
