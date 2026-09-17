-- =========================================================================
-- PROYECTOS: INVOLUCRADOS + CHAT INTERNO
--
-- proy_institucionales no tenía forma de decir QUIÉN participa de un
-- proyecto (solo un campo de texto libre "responsable"), así que no había
-- con quién armar un chat. Esto agrega:
--   1. proy_institucionales.involucrados_auth_ids — array de auth.users.id
--      de los docentes/personal elegidos como participantes.
--   2. proy_mensajes — chat simple por proyecto (autor, texto, fecha).
--   3. Política de lectura/escritura para dirección (como ya tenían
--      proy_institucionales/proy_documentos) + para cada involucrado.
--
-- Correr COMPLETO. Idempotente.
--   node run_proy_chat_migration.js
-- =========================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. INVOLUCRADOS DEL PROYECTO
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.proy_institucionales
    ADD COLUMN IF NOT EXISTS involucrados_auth_ids UUID[] NOT NULL DEFAULT '{}';

-- ¿El usuario autenticado figura entre los involucrados de ese proyecto?
CREATE OR REPLACE FUNCTION public.es_involucrado_proyecto(p_proyecto_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $inv$
    SELECT EXISTS (
        SELECT 1 FROM public.proy_institucionales
        WHERE id = p_proyecto_id AND auth.uid() = ANY(involucrados_auth_ids)
    );
$inv$;

GRANT EXECUTE ON FUNCTION public.es_involucrado_proyecto(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. CHAT DEL PROYECTO
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.proy_mensajes (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proyecto_id    UUID NOT NULL REFERENCES public.proy_institucionales(id) ON DELETE CASCADE,
    autor_auth_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    autor_nombre   TEXT,
    texto          TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_proy_mensajes_proyecto
    ON public.proy_mensajes (proyecto_id, created_at);

ALTER TABLE public.proy_mensajes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proy_mensajes_select ON public.proy_mensajes;
CREATE POLICY proy_mensajes_select ON public.proy_mensajes
    FOR SELECT TO authenticated
    USING (
        public.es_personal_directivo()
        OR public.es_involucrado_proyecto(proyecto_id)
    );

DROP POLICY IF EXISTS proy_mensajes_insert ON public.proy_mensajes;
CREATE POLICY proy_mensajes_insert ON public.proy_mensajes
    FOR INSERT TO authenticated
    WITH CHECK (
        (autor_auth_id IS NULL OR autor_auth_id = auth.uid())
        AND (
            public.es_personal_directivo()
            OR public.es_involucrado_proyecto(proyecto_id)
        )
    );

-- Solo el autor puede borrar su mensaje (o dirección, por moderación).
DROP POLICY IF EXISTS proy_mensajes_delete ON public.proy_mensajes;
CREATE POLICY proy_mensajes_delete ON public.proy_mensajes
    FOR DELETE TO authenticated
    USING (
        autor_auth_id = auth.uid()
        OR public.es_personal_directivo()
    );

COMMIT;
