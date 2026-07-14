const { createClient } = require('@supabase/supabase-js');
const { Client } = require('pg');

const SUPABASE_URL = 'https://qiwwmlysqidwnywmrwko.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8';

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

const usersToCreate = [
  { email: 'admin@colegio.com', role: 'ADMIN', name: 'Administrador' },
  { email: 'docente@colegio.com', role: 'DOCENTE', name: 'Profesor Titular' },
  { email: 'preceptor@colegio.com', role: 'PRECEPTOR', name: 'Preceptor Encargado' },
  { email: 'familia@colegio.com', role: 'PADRE', name: 'Tutor Responsable' }
];

const DEFAULT_PASSWORD = 'Password123!';

async function setup() {
  const pgClient = new Client(pgConfig);
  try {
    await pgClient.connect();
    console.log("Connected to PostgreSQL database.");
    
    const report = [];

    for (const u of usersToCreate) {
      console.log(`\nCreating or updating user: ${u.email}...`);
      
      // Create user in auth.users
      let authUserId;
      const { data: adminData, error: adminErr } = await supabase.auth.admin.createUser({
        email: u.email,
        password: DEFAULT_PASSWORD,
        email_confirm: true,
        user_metadata: { rol: u.role, nombre: u.name }
      });

      if (adminErr) {
        if (adminErr.message.includes('already exists') || adminErr.message.includes('already registered')) {
            console.log(`User ${u.email} already exists. Fetching ID...`);
            const { data: usersData, error: fetchErr } = await supabase.auth.admin.listUsers();
            if (fetchErr) throw fetchErr;
            const existingUser = usersData.users.find(x => x.email === u.email);
            authUserId = existingUser.id;
            
            // Update metadata and password
            await supabase.auth.admin.updateUserById(authUserId, {
                password: DEFAULT_PASSWORD,
                user_metadata: { rol: u.role, nombre: u.name }
            });
        } else {
            throw adminErr;
        }
      } else {
        authUserId = adminData.user.id;
      }
      
      console.log(`Auth ID: ${authUserId}`);

      let linkedDataDesc = '';

      if (['ADMIN', 'DOCENTE', 'PRECEPTOR'].includes(u.role)) {
        // Staff belongs to usr_docentes in our schema
        const checkRes = await pgClient.query("SELECT docente_id FROM usr_docentes WHERE auth_id = $1", [authUserId]);
        if (checkRes.rows.length === 0) {
            const cargos = JSON.stringify([{ cargo: u.role, jerarquia: u.role === 'ADMIN' ? 1 : 2 }]);
            await pgClient.query("INSERT INTO usr_docentes (auth_id, ddjj_cargos) VALUES ($1, $2)", [authUserId, cargos]);
            linkedDataDesc = `Insertado en usr_docentes con rol ${u.role}`;
        } else {
            linkedDataDesc = `Ya existía en usr_docentes.`;
        }
      } else if (u.role === 'PADRE') {
        // Familia
        // 1. Check if user is in usr_legajo_alumno
        const checkRes = await pgClient.query("SELECT legajo_id, grupo_id FROM usr_legajo_alumno WHERE auth_id = $1", [authUserId]);
        let grupoId;
        
        if (checkRes.rows.length === 0) {
            // Need to create group and account
            const grupoRes = await pgClient.query("INSERT INTO fin_grupos_familiares (nombre_grupo) VALUES ('Familia Prueba') RETURNING grupo_id");
            grupoId = grupoRes.rows[0].grupo_id;
            
            await pgClient.query("INSERT INTO fin_cuentas_corrientes (grupo_id, documento_fiscal, moneda) VALUES ($1, '20123456789', 'ARS')", [grupoId]);
            
            const demo = JSON.stringify({ nombre: u.name });
            await pgClient.query("INSERT INTO usr_legajo_alumno (auth_id, grupo_id, rol_financiero, datos_demograficos) VALUES ($1, $2, 'RESPONSABLE_PAGO', $3)", [authUserId, grupoId, demo]);
            linkedDataDesc = `Insertado en usr_legajo_alumno. Creado grupo familiar y cuenta corriente (ARS).`;
        } else {
            grupoId = checkRes.rows[0].grupo_id;
            if (!grupoId) {
                const grupoRes = await pgClient.query("INSERT INTO fin_grupos_familiares (nombre_grupo) VALUES ('Familia Prueba') RETURNING grupo_id");
                grupoId = grupoRes.rows[0].grupo_id;
                await pgClient.query("INSERT INTO fin_cuentas_corrientes (grupo_id, documento_fiscal, moneda) VALUES ($1, '20123456789', 'ARS')", [grupoId]);
                await pgClient.query("UPDATE usr_legajo_alumno SET grupo_id = $1, rol_financiero = 'RESPONSABLE_PAGO' WHERE auth_id = $2", [grupoId, authUserId]);
                linkedDataDesc = `Actualizado grupo_id en usr_legajo_alumno. Creado grupo y cuenta corriente.`;
            } else {
                linkedDataDesc = `Ya existía en usr_legajo_alumno con su grupo_id.`;
            }
        }
      }

      report.push({
          Correo: u.email,
          Contrasena: DEFAULT_PASSWORD,
          Rol: u.role,
          Descripcion: linkedDataDesc
      });
    }

    console.log("\n=== REPORTE FINAL ===");
    console.table(report);

  } catch (e) {
    console.error("Error en setup:", e);
  } finally {
    await pgClient.end();
  }
}

setup();
