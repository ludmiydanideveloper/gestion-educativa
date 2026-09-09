---
name: gestion-escolar
description: >-
  Workflow, toolchain and gotchas for THIS repo — the "gestión escolar" school-management
  app (Flutter web + Supabase/Postgres, deployed on Vercel). Use this skill whenever
  working in this project: before running flutter/dart, before writing or running a
  Supabase migration or a node DB script, before editing RLS/policies or storage buckets,
  before committing or deploying, and when touching panel_administracion.dart, the
  calendar, attendance, EOE, or the admin panels. It records where the Flutter SDK lives
  (not on PATH), how migrations connect (session pooler, not the IPv6 legacy host), the
  RLS helper functions, deploy = push to main, and traps like the deleted cursoIdMock and
  the shared AsistenciaProvider. Consult it even for "small" changes here — the
  environment is non-obvious and getting it wrong wastes a full round-trip.
---

# gestión escolar — repo workflow

Flutter **web** app for a secondary school (6 cursos, "1° SEC"…"6° SEC"). Backend is
Supabase (Postgres + Auth + Storage). Frontend state via `provider`. Deployed on Vercel.
Single developer, iterative. **No automated tests** — `flutter analyze` clean + `flutter
build web` passing is the quality bar.

Roles in `auth.users.raw_user_meta_data.rol`: `ADMIN`, `PRECEPTOR`, `DOCENTE`, `PADRE`.
`ADMIN`/`PRECEPTOR` == "dirección" (see RLS helpers).

## Toolchain (nothing is on PATH)

| Tool | How to invoke |
|---|---|
| Flutter 3.38.10 | `C:\src\fl3810\bin\flutter.bat` — **pinned**, matches `vercel_build.sh`. **Do NOT use `C:\src\flutter`** (wrong version). |
| Dart | `C:\src\fl3810\bin\dart.bat` (e.g. `dart analyze <file>`) |
| Node | `node` (v24, `pg` + `@supabase/supabase-js` installed) — PowerShell or bash |

PowerShell one-liner to get flutter for a command:
`$env:PATH = "C:\src\fl3810\bin;$env:PATH"; flutter analyze`

**Analyze:** target 0 `error` severity. The repo has ~90 pre-existing `info`/`warning`
lints (avoid_print, withOpacity, activeColor, unnecessary_cast…) — do not chase those.
Grep the output for `error ` / `error -`.

**Web build (what Vercel runs):**
```
flutter build web --release --dart-define=SUPABASE_URL="https://qiwwmlysqidwnywmrwko.supabase.co" --dart-define=SUPABASE_ANON_KEY="x"
```
Any non-empty `SUPABASE_ANON_KEY` is fine for a local compile check. `vercel_build.sh`
hard-fails if it is unset.

## Supabase migrations (node + pg)

Credentials live in `.env` (git-ignored, loaded by `load_env.js` / `db_config.js`):
```
SUPABASE_DB_URL=postgresql://postgres.qiwwmlysqidwnywmrwko:<PASS>@aws-1-sa-east-1.pooler.supabase.com:5432/postgres
SUPABASE_SERVICE_ROLE_KEY=sb_secret_...        # for scripts that create auth users
```
- **Always use the Session Pooler host** (`...pooler.supabase.com`). The legacy host
  `db.<ref>.supabase.co:6543` is **IPv6-only** and times out on this network
  (`connect ETIMEDOUT 2600:...`). `db_config.js` prefers `SUPABASE_DB_URL`; if it's
  missing it falls back to `SUPABASE_DB_PASSWORD` + the legacy host (which will fail).
- If `.env` is missing values, ask the user to fill it — do not put real secrets in chat.
  A `.env` template is created if absent.

**Writing a migration:**
1. `<name>_migration.sql` — wrap in `BEGIN; … COMMIT;`, make every statement idempotent
   (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `DROP POLICY IF EXISTS`
   before `CREATE POLICY`, `INSERT … ON CONFLICT DO NOTHING`).
2. `run_<name>_migration.js` — copy `run_eoe_banco_migration.js` and change the filename
   constant. It just `client.query(sql)` inside a try/rollback.
3. Run: `node run_<name>_migration.js`. Re-run to confirm idempotency.
4. Storage buckets: create them inside a `DO $$ … EXCEPTION WHEN insufficient_privilege
   … END $$;` block (see `eoe_banco_migration.sql`) so a permissions gap doesn't roll
   back the whole migration.

**Never fabricate schema.** Query `information_schema` (or the existing `*_migration.sql`
files) before assuming a table/column exists. Applied so far includes: `calendar_`,
`academic_`, `db_completa_`, `calendario_autoria_`, `eoe_banco_`,
`admin_pedagogico_proyectos_horarios_`. See `references/db.md`.

## RLS & Storage conventions

Helper SQL functions (SECURITY DEFINER) — reuse, don't reinvent:
- `public.es_personal_directivo()` — ADMIN or PRECEPTOR
- `public.dicta_en_curso(curso_id)` — current user is a docente of that curso
- `public.docente_ve_legajo(legajo_id)` — docente teaches a course that legajo is enrolled in
- `public.docente_dicta_materia_curso(materia_id, curso_id)` — titular or dmc match

Standard policy shape: SELECT for `es_personal_directivo() OR <docente-scoped clause>`;
writes for `es_personal_directivo()` (+ narrow docente exceptions where the feature needs it).

Private buckets: `eoe`, `banco-evaluaciones`, `pedagogico`, `proyectos`. Upload via
`storage.from(b).uploadBinary(path, Uint8List.fromList(bytes), fileOptions: FileOptions(upsert: true))`;
serve via `SupabaseService.urlFirmadaStorage(bucket, path)` (1 h signed URL) then
`launchUrl(...)`. `file_picker` (`withData: true`) + `url_launcher` are deps.

## Deploy

Push to **`main`** → Vercel auto-builds (`bash vercel_build.sh`: clones Flutter
3.38.10, `flutter pub get`, `flutter build web`, output `build/web`). No PR flow.
Repo remote: `ludmiydanideveloper/gestion-educativa`.

Commit style: `tipo(scope): descripción` in **lowercase Spanish** (`feat(admin): …`,
`fix(asistencia): …`, `seguridad: …`). Keep the co-author trailer.

Only commit/push when the user asks. The user watches the Vercel dashboard for the deploy.

## Gotchas (these have bitten us)

- **`SupabaseService.cursoIdMock` (`953fc2c3-…`) and `docenteIdMock` were DELETED from the
  DB.** They're still string constants and appear as `?? cursoIdMock` fallbacks — never
  rely on them resolving; treat that path as broken.
- **`AsistenciaProvider` is an app-wide singleton.** A screen using it must call
  `resetParaNuevaPantalla()` in `initState` before the first build or it shows the
  previous screen's roster + "ya tomaste lista".
- **`AlumnoAsistencia.copyWith` can't null a field** (uses `x ?? this.x`). Build a fresh
  object to clear `horaEvento`.
- **Notes/grades must NOT create `acad_calendario` events.** That sync was removed on
  purpose; don't re-add it. Old `[TAREA]`/`[CLASE]` events were cleaned out.
- `acad_calendario` PK is **`evento_id`**. `tipo_evento` check allows
  `EVALUACION|ACTIVIDAD|REUNION|TEMARIO`. `materia_id` column exists. `creado_por`/`docente_id`
  added by `calendario_autoria_migration` (code retries insert without them as a fallback).
- **`acad_horarios` has no docente column** — teacher = `acad_materias.docente_titular_id`.
- `panel_administracion.dart` is ~6000 lines. Edit surgically; for large contiguous
  replacements, splice with a short python script rather than one giant Edit.
- `flutter`/`build` go through PowerShell; `dart analyze` via `C:/src/fl3810/bin/dart.bat`.
- Creating auth users (teachers/admins) needs `SUPABASE_SERVICE_ROLE_KEY` and the
  `crear_usuarios_prueba.js` pattern (createUser → row in `usr_docentes` → link `auth_id`).

## Where things are

`lib/services/supabase_service.dart` — the single data layer (~3000 lines, all queries).
`lib/screens/panel_administracion.dart` — admin panel (tabs: Dashboard, Staff, Comunidad,
Académica, Pedagógico, Rendimiento, Horarios, Límites, Proyectos, Trámites, Adecuaciones/EOE,
Gestión de Clases). `lib/screens/dashboard_preceptor.dart` — docente/admin home.
`lib/widgets/calendario_docente.dart` — the one shared calendar widget.
`lib/providers/asistencia_provider.dart` — attendance state.

Read `references/db.md` for the schema map and the list of RLS helpers before writing SQL.
