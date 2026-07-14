-- ============================================================
-- Columna para guardar el token de notificaciones push (FCM) de cada
-- usuario. Necesaria para que updateFcmToken() funcione.
--
-- Ejecutar en: Supabase -> SQL Editor -> Run
-- ============================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
