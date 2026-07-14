-- ============================================================
-- OPCIONAL: permitir eliminar filas de la tabla "users".
--
-- La tabla users tiene RLS activado con politicas de SELECT/INSERT/UPDATE
-- pero le falta la de DELETE, por eso los borrados no surten efecto.
-- Esto agrega una politica que permite eliminar.
--
-- Ejecutar en: Supabase -> SQL Editor -> Run
-- ============================================================

CREATE POLICY "allow_delete_users"
  ON public.users
  FOR DELETE
  USING (true);

-- Despues de esto ya podras borrar usuarios (incluido el fantasma id=2).
-- Para borrar el fantasma directamente aqui mismo:
DELETE FROM public.users WHERE email = '204800-old@unsaac.edu.pe';
