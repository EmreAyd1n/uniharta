-- ============================================================
-- Migration: profiles tablosuna user_type sütunu ekle
-- Supabase Dashboard > SQL Editor'da bu kodu çalıştırın.
-- ============================================================

-- 1) user_type sütununu ekle
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS user_type text
  CHECK (user_type IN ('ogrenci', 'organizator'))
  DEFAULT 'ogrenci';

-- 2) Yeni kullanıcı kayıt olduğunda profiles tablosuna otomatik satır ekleyen trigger fonksiyonu
--    raw_user_meta_data içinden full_name ve user_type bilgilerini alır.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'full_name',
    COALESCE(NEW.raw_user_meta_data ->> 'user_type', 'ogrenci')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Trigger'ı oluştur (zaten varsa önce sil)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
