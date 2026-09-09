# DB schema map — gestión escolar

Supabase project ref: `qiwwmlysqidwnywmrwko`. Always verify against
`information_schema` before assuming; this is a map, not a contract.

## Núcleo académico

| Tabla | Columnas clave |
|---|---|
| `acad_cursos` | `curso_id`, `identificador_division` ("1° SEC" … "6° SEC"). Solo 6 cursos, sin divisiones A/B. |
| `acad_materias` | `materia_id`, `nombre_asignatura`, `curso_id`, `docente_titular_id` → `usr_docentes` |
| `acad_docente_materia_curso` | `docente_id`, `materia_id`, `curso_id` (tabla puente; unique en la terna) |
| `acad_horarios` | `horario_id`, `materia_id`, `curso_id`, `dia_semana` (LUNES…), `hora_inicio`, `hora_fin` (varchar "7:00"). **Sin docente.** ~193 filas reales. |
| `org_horario_bloques` | esquema más nuevo con `docente_titular_id` + tsrange — **vacío, sin usar** |
| `acad_inscripciones` | `alumno_id` (= legajo_id), `curso_id`, `estado` |
| `acad_calendario` | PK `evento_id`, `titulo`, `descripcion`, `fecha` (date), `tipo_evento` (EVALUACION\|ACTIVIDAD\|REUNION\|TEMARIO), `curso_id`, `materia_id`, `creado_por`, `docente_id` |

## Personas

| Tabla | Columnas clave |
|---|---|
| `usr_docentes` | `docente_id`, `auth_id` → auth.users, `nombre`, `apellido`, `dni`, `ddjj_cargos` (jsonb `[{cargo,jerarquia}]`), `disponibilidad` (jsonb `[{dia,desde,hasta}]`) |
| `usr_legajo_alumno` | `legajo_id`, `auth_id`, `grupo_id`, `datos_demograficos` (jsonb: nombre, apellido, dni, adecuacion_curricular, tipo_adecuacion, detalles_adecuacion) |
| `fin_grupos_familiares` | `grupo_id`, `nombre_grupo` |

## Asistencia / calificaciones / conducta

| Tabla | Notas |
|---|---|
| `asistencia_cabecera` | `asistencia_cabecera_id`, `curso_id`, `materia_id`, `fecha`, `tipo_asistencia` (`PRECEPTOR_DIARIA` \| `POR_MATERIA`), `registrado_por_docente_id`, `estado`. Índices únicos parciales: 1 PRECEPTOR_DIARIA por curso+fecha; 1 POR_MATERIA por curso+fecha+materia. |
| `asistencia_detalle` | `asistencia_cabecera_id`, `alumno_id`, `tipo` (PRESENTE\|AUSENTE\|TARDE\|RETIRO_ANTICIPADO), `valor_inasistencia` |
| `aca_actividades` | `id`, `materia_id`, `docente_id`, `categoria_id`, `titulo`, `fecha`, `peso_porcentaje_actividad` |
| `aca_calificaciones` | `id`, `actividad_id`, `alumno_id`, `nota_numerica`. Upsert por `(actividad_id, alumno_id)`. |
| `aca_categorias_nota` | `id`, `nombre`, `peso_porcentaje`, `materia_id` (nullable = global) |
| `aca_conducta` | conducta/incidencias; conducta diaria = filas con `descripcion` que arranca `Conducta diaria:` |
| `aca_boletines` / `aca_boletin_detalle` | boletines por curso |
| `aca_rubricas_cualitativas`, `aca_cierres_etapa`, `aca_config_materia` | RITE |

## Módulos nuevos (agregados en esta serie de sesiones)

| Tabla | Migración | Para |
|---|---|---|
| `eoe_ficha` | `eoe_banco_migration` | ficha de adecuación por legajo (+ `datos_formulario` jsonb) |
| `eoe_bitacora` | `eoe_banco_migration` | notas de acompañamiento EOE |
| `eoe_documentos` | `eoe_banco_migration` | informes/pautas/eval original/eval adecuada (bucket `eoe`) |
| `banco_evaluaciones` | `fix_banco_evaluaciones` + `eoe_banco_migration` | + `curso_id`, `storage_path`, `subido_por_auth` (bucket `banco-evaluaciones`) |
| `ped_documentos` | `admin_pedagogico_proyectos_horarios_migration` | repositorio pedagógico por curso+materia (bucket `pedagogico`) |
| `proy_institucionales` / `proy_documentos` | idem | proyectos institucionales (bucket `proyectos`) |

## Funciones RLS (SECURITY DEFINER, reutilizar)

| Función | Definida en | Devuelve true si |
|---|---|---|
| `es_personal_directivo()` | `db_completa_migration` | rol ADMIN o PRECEPTOR (via ddjj_cargos ILIKE) |
| `dicta_en_curso(uuid)` | `calendario_autoria_migration` | el `auth.uid()` es docente de ese curso (dmc) |
| `docente_ve_legajo(uuid)` | `eoe_banco_migration` | docente de un curso donde el legajo está inscripto |
| `docente_dicta_materia_curso(uuid, uuid)` | `eoe_banco_migration` | titular de la materia o match en dmc |

## Auth (cuentas de prueba vs reales)

Cuentas de prueba: `admin@colegio.com`, `preceptor@colegio.com`,
`preceptor.test.sge@gmail.com`, `docente@colegio.com` (titular de ~19 materias — ensucia
listados hasta que se carguen profes reales), `familia@colegio.com`.
Real: `Danuugomez@hotmail.com` (Daniela Gomez, DOCENTE).

## Storage buckets (todos privados)

`eoe`, `banco-evaluaciones`, `pedagogico`, `proyectos`. Política sobre `storage.objects`:
`FOR ALL TO authenticated USING (bucket_id IN (...))` — el filtro fino queda en las
tablas + el hecho de que la app solo pide signed URL de registros que el usuario ya ve.
