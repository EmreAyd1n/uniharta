-- ============================================================
-- Migration: events tablosuna category, location, is_active ekle
-- Supabase Dashboard > SQL Editor'da bu kodu çalıştırın.
-- ============================================================

-- 1) Kategori enum type oluştur
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_category') THEN
    CREATE TYPE event_category AS ENUM ('seminer', 'spor', 'yemek', 'eglence');
  END IF;
END$$;

-- 2) Mevcut events tablosuna yeni sütunlar ekle
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS category event_category DEFAULT 'seminer',
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- 3) Performans index'leri
CREATE INDEX IF NOT EXISTS idx_events_active ON public.events (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_events_category ON public.events (category);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON public.events (start_time);
