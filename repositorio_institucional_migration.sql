-- =========================================================================
-- REPOSITORIO DE DOCUMENTOS INSTITUCIONALES (general, no por materia)
--
-- panel_repositorio_documentos.dart mostraba una lista inventada en memoria
-- (cualquiera que "subiera" algo solo lo veía él mismo, hasta refrescar la
-- página, momento en que desaparecía). Este repositorio es para material de
-- referencia que Dirección quiere que vea TODO el personal — ej. una guía
-- para completar el Libro de Temas — no para que se acumule cualquier cosa
-- que suba cualquiera.
--
-- Lectura: todo el personal autenticado (docente/preceptor/admin).
-- Escritura (subir/eliminar): solo Dirección (es_personal_directivo()).
--
-- Correr COMPLETO. Idempotente.
--   node run_repositorio_institucional_migration.js
-- =========================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.ins_documentos (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre           TEXT NOT NULL,
    descripcion      TEXT,
    storage_path     TEXT NOT NULL,
    subido_por_auth  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subido_por_nombre TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ins_documentos_created ON public.ins_documentos (created_at DESC);

ALTER TABLE public.ins_documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ins_documentos_select ON public.ins_documentos;
CREATE POLICY ins_documentos_select ON public.ins_documentos
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS ins_documentos_write ON public.ins_documentos;
CREATE POLICY ins_documentos_write ON public.ins_documentos
    FOR ALL TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public) VALUES ('institucional', 'institucional', false) ON CONFLICT (id) DO NOTHING;

    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "institucional objetos rw autenticados" ON storage.objects';
        EXECUTE 'CREATE POLICY "institucional objetos rw autenticados" ON storage.objects
                 FOR ALL TO authenticated
                 USING (bucket_id = ''institucional'')
                 WITH CHECK (bucket_id = ''institucional'')';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Sin permiso para políticas de storage.objects: configurar el bucket institucional desde el dashboard.';
    END;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sin permiso sobre storage: crear el bucket institucional (privado) a mano.';
END $$;

COMMIT;
