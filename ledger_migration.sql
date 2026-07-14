-- ========================================================
-- MÓDULO DE GESTIÓN ADMINISTRATIVA Y FACTURACIÓN (LEDGER)
-- ========================================================

-- 1. Tabla fin_grupos_familiares (Agrupador contable de familias)
CREATE TABLE IF NOT EXISTS fin_grupos_familiares (
    grupo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_grupo VARCHAR(150) NOT NULL, -- Ej: Familia Rodríguez
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla fin_cuentas_corrientes (Cuentas contables para facturación)
CREATE TABLE IF NOT EXISTS fin_cuentas_corrientes (
    cuenta_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grupo_id UUID NOT NULL REFERENCES fin_grupos_familiares(grupo_id) ON DELETE RESTRICT,
    documento_fiscal VARCHAR(50) NOT NULL, -- DNI/CUIT del titular
    moneda VARCHAR(10) NOT NULL DEFAULT 'ARS', -- 'ARS', 'USD', etc.
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Vínculo con usuarios: Modificar usr_legajo_alumno para agregar grupo_id y rol_financiero
ALTER TABLE usr_legajo_alumno 
ADD COLUMN IF NOT EXISTS grupo_id UUID REFERENCES fin_grupos_familiares(grupo_id) ON DELETE SET NULL;

ALTER TABLE usr_legajo_alumno
ADD COLUMN IF NOT EXISTS rol_financiero VARCHAR(50) CHECK (rol_financiero IN ('RESPONSABLE_PAGO', 'INTERESADO'));

-- 4. Tabla fin_transacciones (Cabecera del Asiento Contable)
CREATE TABLE IF NOT EXISTS fin_transacciones (
    transaccion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_evento VARCHAR(50) NOT NULL CHECK (tipo_evento IN ('EMISION_FACTURA', 'PAGO_RECIBIDO', 'AJUSTE_CREDITO', 'AJUSTE_DEBITO')),
    observaciones TEXT NULL,
    fecha_ejecucion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Tabla fin_movimientos (Detalle del Asiento Contable / Posting)
CREATE TABLE IF NOT EXISTS fin_movimientos (
    movimiento_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaccion_id UUID NOT NULL REFERENCES fin_transacciones(transaccion_id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES fin_cuentas_corrientes(cuenta_id) ON DELETE RESTRICT,
    monto NUMERIC(19,4) NOT NULL, -- Positivo = Débito, Negativo = Crédito
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Índices de Alto Rendimiento para Consultas de Saldo y Ledger
CREATE INDEX IF NOT EXISTS idx_fin_cuentas_corrientes_grupo ON fin_cuentas_corrientes(grupo_id);
CREATE INDEX IF NOT EXISTS idx_fin_movimientos_cuenta ON fin_movimientos(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_fin_movimientos_transaccion ON fin_movimientos(transaccion_id);

-- ========================================================
-- 7. TRIGGER DE PARTIDA DOBLE (RESTRICTIVO CONTABLE)
-- ========================================================

-- Función PL/pgSQL para verificar el balance contable
CREATE OR REPLACE FUNCTION fn_verify_double_entry_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_sum NUMERIC(19,4);
BEGIN
    -- Calcula la sumatoria de todos los movimientos de la transacción actual
    SELECT SUM(monto) INTO v_sum
    FROM fin_movimientos
    WHERE transaccion_id = NEW.transaccion_id;

    -- Si la sumatoria no es cero (Partida Doble desbalanceada), abortar la transacción
    IF v_sum IS NULL OR v_sum <> 0.0000 THEN
        RAISE EXCEPTION 'Control de Partida Doble fallido para transaccion_id %. El balance debe ser exactamente cero, saldo actual: %.', NEW.transaccion_id, COALESCE(v_sum, 0);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Constraint Trigger Diferido: Se ejecuta al final de la transacción (en el COMMIT)
DROP TRIGGER IF EXISTS check_double_entry_balance ON fin_movimientos;
CREATE CONSTRAINT TRIGGER check_double_entry_balance
AFTER INSERT OR UPDATE OR DELETE ON fin_movimientos
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_verify_double_entry_balance();

-- ========================================================
-- 8. CONFIGURACIÓN DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ========================================================
ALTER TABLE fin_grupos_familiares ENABLE ROW LEVEL SECURITY;
ALTER TABLE fin_cuentas_corrientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE fin_transacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE fin_movimientos ENABLE ROW LEVEL SECURITY;

-- Limpieza preventiva de políticas
DROP POLICY IF EXISTS admin_grupos_familiares_all ON fin_grupos_familiares;
DROP POLICY IF EXISTS familia_grupos_familiares_select ON fin_grupos_familiares;
DROP POLICY IF EXISTS admin_cuentas_corrientes_all ON fin_cuentas_corrientes;
DROP POLICY IF EXISTS familia_cuentas_corrientes_select ON fin_cuentas_corrientes;
DROP POLICY IF EXISTS admin_transacciones_all ON fin_transacciones;
DROP POLICY IF EXISTS familia_transacciones_select ON fin_transacciones;
DROP POLICY IF EXISTS admin_movimientos_all ON fin_movimientos;
DROP POLICY IF EXISTS familia_movimientos_select ON fin_movimientos;

-- Políticas para fin_grupos_familiares
CREATE POLICY admin_grupos_familiares_all ON fin_grupos_familiares FOR ALL TO authenticated USING ((auth.jwt() -> 'user_metadata' ->> 'rol') IN ('ADMIN', 'DIRECTIVO'));
CREATE POLICY familia_grupos_familiares_select ON fin_grupos_familiares FOR SELECT TO authenticated USING (
    grupo_id = (SELECT grupo_id FROM usr_legajo_alumno WHERE auth_id = auth.uid() LIMIT 1)
);

-- Políticas para fin_cuentas_corrientes
CREATE POLICY admin_cuentas_corrientes_all ON fin_cuentas_corrientes FOR ALL TO authenticated USING ((auth.jwt() -> 'user_metadata' ->> 'rol') IN ('ADMIN', 'DIRECTIVO'));
CREATE POLICY familia_cuentas_corrientes_select ON fin_cuentas_corrientes FOR SELECT TO authenticated USING (
    grupo_id = (SELECT grupo_id FROM usr_legajo_alumno WHERE auth_id = auth.uid() LIMIT 1)
);

-- Políticas para fin_transacciones
CREATE POLICY admin_transacciones_all ON fin_transacciones FOR ALL TO authenticated USING ((auth.jwt() -> 'user_metadata' ->> 'rol') IN ('ADMIN', 'DIRECTIVO'));
CREATE POLICY familia_transacciones_select ON fin_transacciones FOR SELECT TO authenticated USING (
    transaccion_id IN (
        SELECT m.transaccion_id 
        FROM fin_movimientos m
        JOIN fin_cuentas_corrientes c ON m.cuenta_id = c.cuenta_id
        WHERE c.grupo_id = (SELECT grupo_id FROM usr_legajo_alumno WHERE auth_id = auth.uid() LIMIT 1)
    )
);

-- Políticas para fin_movimientos
CREATE POLICY admin_movimientos_all ON fin_movimientos FOR ALL TO authenticated USING ((auth.jwt() -> 'user_metadata' ->> 'rol') IN ('ADMIN', 'DIRECTIVO'));
CREATE POLICY familia_movimientos_select ON fin_movimientos FOR SELECT TO authenticated USING (
    cuenta_id IN (
        SELECT cuenta_id 
        FROM fin_cuentas_corrientes 
        WHERE grupo_id = (SELECT grupo_id FROM usr_legajo_alumno WHERE auth_id = auth.uid() LIMIT 1)
    )
);
