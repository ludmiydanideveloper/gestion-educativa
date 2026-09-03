CREATE TABLE IF NOT EXISTS aca_rubricas_cualitativas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    etapa VARCHAR(50) NOT NULL,
    criterio_apropiacion VARCHAR(10),
    criterio_resolucion VARCHAR(10),
    criterio_participacion VARCHAR(10),
    criterio_planteos VARCHAR(10),
    criterio_entrega VARCHAR(10),
    criterio_prolijidad VARCHAR(10),
    criterio_aic VARCHAR(10),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(alumno_id, materia_id, etapa)
);

CREATE TABLE IF NOT EXISTS aca_cierres_etapa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    etapa VARCHAR(50) NOT NULL,
    calificacion_numerica NUMERIC(4,2),
    condicion_trayectoria VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(alumno_id, materia_id, etapa)
);

-- =============================================
-- ROW LEVEL SECURITY (consistente con el resto del proyecto)
-- El rol está en auth.jwt() -> 'user_metadata' ->> 'rol'
-- Valores: 'ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE', 'ALUMNO', 'PADRE'
-- =============================================

ALTER TABLE aca_rubricas_cualitativas ENABLE ROW LEVEL SECURITY;
ALTER TABLE aca_cierres_etapa         ENABLE ROW LEVEL SECURITY;

-- Personal (ADMIN / DIRECTIVO / PRECEPTOR / DOCENTE): acceso total
CREATE POLICY "personal_rubricas_all" ON aca_rubricas_cualitativas
  FOR ALL TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol')
    IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')
  );

CREATE POLICY "personal_cierres_all" ON aca_cierres_etapa
  FOR ALL TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol')
    IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')
  );

-- =============================================
-- MIGRACIÓN: Renombrar etapas al nuevo esquema seguimiento/cierre
-- Ejecutar UNA SOLA VEZ si ya existe data con '1° ETAPA' / '2° ETAPA'
-- =============================================

-- Paso 1: Renombrar temporalmente para evitar conflicto de UNIQUE constraint
UPDATE aca_rubricas_cualitativas SET etapa = '1° CIERRE_TMP' WHERE etapa = '1° ETAPA';
UPDATE aca_rubricas_cualitativas SET etapa = '2° CIERRE_TMP' WHERE etapa = '2° ETAPA';
UPDATE aca_cierres_etapa         SET etapa = '1° CIERRE_TMP' WHERE etapa = '1° ETAPA';
UPDATE aca_cierres_etapa         SET etapa = '2° CIERRE_TMP' WHERE etapa = '2° ETAPA';

-- Paso 2: Nombre final
UPDATE aca_rubricas_cualitativas SET etapa = '1° CIERRE' WHERE etapa = '1° CIERRE_TMP';
UPDATE aca_rubricas_cualitativas SET etapa = '2° CIERRE' WHERE etapa = '2° CIERRE_TMP';
UPDATE aca_cierres_etapa         SET etapa = '1° CIERRE' WHERE etapa = '1° CIERRE_TMP';
UPDATE aca_cierres_etapa         SET etapa = '2° CIERRE' WHERE etapa = '2° CIERRE_TMP';

-- Alumnos: solo leen sus propios registros
CREATE POLICY "alumnos_rubricas_read" ON aca_rubricas_cualitativas
  FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol') = 'ALUMNO'
    AND alumno_id = (
      SELECT legajo_id FROM usr_legajo_alumno
      WHERE auth_id = auth.uid() LIMIT 1
    )
  );

CREATE POLICY "alumnos_cierres_read" ON aca_cierres_etapa
  FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol') = 'ALUMNO'
    AND alumno_id = (
      SELECT legajo_id FROM usr_legajo_alumno
      WHERE auth_id = auth.uid() LIMIT 1
    )
  );
