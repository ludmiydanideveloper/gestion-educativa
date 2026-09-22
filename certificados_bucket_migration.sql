-- =========================================================================
-- CERTIFICADOS MÉDICOS / JUSTIFICATIVOS DE INASISTENCIA
--
-- La pestaña "Certificados" de la Ficha del Alumno mostraba una lista
-- inventada en memoria (no persistía nada). El modelo real ya existe en
-- asistencia_detalle (columnas url_certificado / estado_justificacion),
-- solo faltaba dónde guardar el archivo: bucket privado 'certificados'.
--
-- RLS de asistencia_detalle ya permite UPDATE a PRECEPTOR/ADMIN (política
-- docente_asistencia_detalle_all), así que no hace falta tocarla.
--
-- Correr COMPLETO. Idempotente.
--   node run_certificados_bucket_migration.js
-- =========================================================================

BEGIN;

DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public) VALUES ('certificados', 'certificados', false) ON CONFLICT (id) DO NOTHING;

    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "certificados objetos rw autenticados" ON storage.objects';
        EXECUTE 'CREATE POLICY "certificados objetos rw autenticados" ON storage.objects
                 FOR ALL TO authenticated
                 USING (bucket_id = ''certificados'')
                 WITH CHECK (bucket_id = ''certificados'')';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Sin permiso para políticas de storage.objects: configurar el bucket certificados desde el dashboard.';
    END;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sin permiso sobre storage: crear el bucket certificados (privado) a mano.';
END $$;

COMMIT;
