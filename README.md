# gestion_escolar

Sistema de gestión escolar (Flutter + Supabase).

## Configuración

Las credenciales no viven en el código: se pasan al compilar.

### Clave de Supabase (obligatoria)

En **Supabase > Settings > API** copiá la clave **`anon` `public`**.
No uses la `service_role`: saltea todas las políticas RLS y quedaría publicada
en el navegador de cada usuario.

**Web (local):**

```bash
flutter run -d chrome --dart-define=SUPABASE_ANON_KEY=<clave anon public>
```

**Android:**

```bash
$env:SUPABASE_ANON_KEY = "<clave anon public>"; ./build_apk.ps1
```

**Vercel:** cargá `SUPABASE_ANON_KEY` (y opcionalmente `SUPABASE_URL`) en
*Settings > Environment Variables*. `vercel_build.sh` las inyecta al compilar.

Si falta la clave, la app arranca mostrando una pantalla que explica cómo
configurarla en vez de conectarse con una credencial escrita en el código.

### Acceso directo a la base (scripts de migración)

Los scripts `.js` leen la contraseña de postgres del entorno:

```bash
$env:SUPABASE_DB_PASSWORD = "<password de postgres>"
node run_db_completa_migration.js
```

También se puede dejar un archivo `.env` local (está en `.gitignore`):

```
SUPABASE_DB_HOST=db.xxxx.supabase.co
SUPABASE_DB_PASSWORD=...
```

## Migraciones

`db_completa_migration.sql` deja operativas las secciones que apuntaban a
tablas o columnas inexistentes: perfil docente, DDJJ/CV/certificados, faltas y
licencias, observaciones áulicas, libro de temas, trayectoria del alumno,
materias adeudadas, libro de actas, trámites y notificaciones.

Es idempotente, así que se puede volver a correr sin romper nada:

```bash
node run_db_completa_migration.js
```

O pegando el contenido en el **SQL Editor** de Supabase.
