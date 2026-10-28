-- =========================================================================
-- MIGRACIÓN A SUPABASE AUTH + ACTIVACIÓN DE RLS (v2)
-- Correr una sola vez en el SQL Editor de Supabase, ANTES de desplegar el
-- código que usa sb.auth.* y ANTES de correr scripts/migrate-to-supabase-auth.js
--
-- v2: este proyecto ya tenía un intento previo de migración (columna
-- `user_id` en students, y un set de políticas RLS mixto: algunas abiertas
-- a cualquiera, otras ya bien restringidas). Este script se alinea con esa
-- columna `user_id` existente (en vez de crear una `auth_user_id` paralela),
-- y empieza borrando TODAS las políticas que había antes de recrear las
-- correctas, para no dejar ninguna política abierta activa por accidente.
-- Es 100% idempotente: se puede correr las veces que haga falta.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1. Columna de enlace hacia auth.users. students ya la tenía; se agrega a
--    teachers y admins. No se toca password_hash todavía (se deja para
--    reversa), solo se le quita NOT NULL donde la tenía.
-- -------------------------------------------------------------------------
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.admins   ADD COLUMN IF NOT EXISTS user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.students ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE public.admins   ALTER COLUMN password_hash DROP NOT NULL;

-- students.user_id ya existía de un intento anterior, así que el ADD COLUMN
-- IF NOT EXISTS de arriba no le aplicó UNIQUE/REFERENCES (eso solo pasa al
-- crear la columna). Se agrega aparte, sin tronar si ya estuviera.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'students_user_id_key'
  ) THEN
    ALTER TABLE public.students ADD CONSTRAINT students_user_id_key UNIQUE (user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'students_user_id_fkey'
  ) THEN
    ALTER TABLE public.students ADD CONSTRAINT students_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- -------------------------------------------------------------------------
-- 2. Helpers de RLS
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT auth.jwt() -> 'app_metadata' ->> 'app_role';
$$;

CREATE OR REPLACE FUNCTION public.current_teacher_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM public.teachers WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.current_student_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM public.students WHERE user_id = auth.uid();
$$;

-- -------------------------------------------------------------------------
-- 3. Habilitar RLS en todas las tablas (ya estaba, esto es un no-op seguro)
-- -------------------------------------------------------------------------
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.piense2_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_sessions_p2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_results_p2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avatar_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coordinator_feedback ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- 4. Borrar TODAS las políticas existentes (las de un intento previo, varias
--    completamente abiertas tipo "Allow public select students", y también
--    las que este mismo script pudo haber dejado en una corrida anterior).
--    DROP POLICY IF EXISTS nunca falla si el nombre no existe, así que esto
--    es seguro de correr aunque el estado real no coincida exactamente.
-- -------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public insert exam_sessions_p2" ON public.exam_sessions_p2;
DROP POLICY IF EXISTS "Allow public select exam_sessions_p2" ON public.exam_sessions_p2;
DROP POLICY IF EXISTS "Allow public update exam_sessions_p2" ON public.exam_sessions_p2;
DROP POLICY IF EXISTS sessions_public_read ON public.exam_sessions_p2;
DROP POLICY IF EXISTS exam_sessions_p2_public_read ON public.exam_sessions_p2;
DROP POLICY IF EXISTS exam_sessions_p2_owner_write ON public.exam_sessions_p2;

DROP POLICY IF EXISTS "docentes pueden leer exámenes" ON public.exams;
DROP POLICY IF EXISTS exams_insert ON public.exams;
DROP POLICY IF EXISTS exams_public_read ON public.exams;
DROP POLICY IF EXISTS exams_update ON public.exams;
DROP POLICY IF EXISTS exams_owner_write ON public.exams;

DROP POLICY IF EXISTS "Allow teachers manage groups p2" ON public.groups;
DROP POLICY IF EXISTS groups_insert ON public.groups;
DROP POLICY IF EXISTS groups_public_read ON public.groups;
DROP POLICY IF EXISTS groups_update ON public.groups;
DROP POLICY IF EXISTS groups_owner_write ON public.groups;

DROP POLICY IF EXISTS "Allow public select piense2_questions" ON public.piense2_questions;
DROP POLICY IF EXISTS questions_public_read ON public.piense2_questions;
DROP POLICY IF EXISTS piense2_questions_read ON public.piense2_questions;

DROP POLICY IF EXISTS "alumnos pueden leer preguntas" ON public.questions;
DROP POLICY IF EXISTS "docentes pueden leer preguntas" ON public.questions;
DROP POLICY IF EXISTS questions_public_read ON public.questions;
DROP POLICY IF EXISTS questions_read ON public.questions;

DROP POLICY IF EXISTS "alumnos pueden insertar respuestas" ON public.responses;
DROP POLICY IF EXISTS "docentes pueden leer respuestas" ON public.responses;
DROP POLICY IF EXISTS responses_public_insert ON public.responses;
DROP POLICY IF EXISTS responses_public_read ON public.responses;
DROP POLICY IF EXISTS responses_insert ON public.responses;
DROP POLICY IF EXISTS responses_select ON public.responses;

DROP POLICY IF EXISTS shop_public_read ON public.shop_items;
DROP POLICY IF EXISTS shop_items_read ON public.shop_items;

DROP POLICY IF EXISTS inventory_own ON public.student_inventory;
DROP POLICY IF EXISTS student_inventory_self ON public.student_inventory;

DROP POLICY IF EXISTS "alumnos pueden insertar resultados" ON public.student_results_p2;
DROP POLICY IF EXISTS "alumnos pueden leer sus resultados" ON public.student_results_p2;
DROP POLICY IF EXISTS results_own ON public.student_results_p2;
DROP POLICY IF EXISTS student_results_p2_insert ON public.student_results_p2;
DROP POLICY IF EXISTS student_results_p2_select ON public.student_results_p2;

DROP POLICY IF EXISTS "Allow public insert students" ON public.students;
DROP POLICY IF EXISTS "Allow public select students" ON public.students;
DROP POLICY IF EXISTS "Allow public update students" ON public.students;
DROP POLICY IF EXISTS students_own ON public.students;
DROP POLICY IF EXISTS students_select ON public.students;
DROP POLICY IF EXISTS students_self_update ON public.students;

DROP POLICY IF EXISTS teachers_public_insert ON public.teachers;
DROP POLICY IF EXISTS teachers_public_read ON public.teachers;
DROP POLICY IF EXISTS teachers_self_select ON public.teachers;
DROP POLICY IF EXISTS teachers_self_update ON public.teachers;

DROP POLICY IF EXISTS admins_self_select ON public.admins;
DROP POLICY IF EXISTS avatar_items_read ON public.avatar_items;
DROP POLICY IF EXISTS student_challenges_public ON public.student_challenges;
DROP POLICY IF EXISTS student_challenges_insert ON public.student_challenges;
DROP POLICY IF EXISTS challenge_results_public ON public.challenge_results;
DROP POLICY IF EXISTS challenge_results_insert ON public.challenge_results;
DROP POLICY IF EXISTS coordinator_feedback_admin ON public.coordinator_feedback;
DROP POLICY IF EXISTS coordinator_feedback_teacher_read ON public.coordinator_feedback;
DROP POLICY IF EXISTS coordinator_feedback_teacher_mark_read ON public.coordinator_feedback;

-- -------------------------------------------------------------------------
-- 5. Políticas (set limpio y completo)
-- -------------------------------------------------------------------------

-- teachers: cada docente ve/edita solo su fila; admin ve todas.
CREATE POLICY teachers_self_select ON public.teachers FOR SELECT
  USING (user_id = auth.uid() OR current_app_role() = 'admin');
CREATE POLICY teachers_self_update ON public.teachers FOR UPDATE
  USING (user_id = auth.uid());

-- students: el propio alumno, el docente dueño de su grupo, y admin.
CREATE POLICY students_select ON public.students FOR SELECT
  USING (
    user_id = auth.uid()
    OR group_id IN (SELECT id FROM public.groups WHERE teacher_id = current_teacher_id())
    OR current_app_role() = 'admin'
  );
CREATE POLICY students_self_update ON public.students FOR UPDATE
  USING (
    user_id = auth.uid()
    OR group_id IN (SELECT id FROM public.groups WHERE teacher_id = current_teacher_id())
  );

-- admins: cada admin ve solo su fila.
CREATE POLICY admins_self_select ON public.admins FOR SELECT
  USING (user_id = auth.uid());

-- groups: lectura abierta (se usa para "unirse con código" y leaderboard);
-- solo el docente dueño (o admin) puede crear/editar/borrar.
CREATE POLICY groups_public_read ON public.groups FOR SELECT USING (true);
CREATE POLICY groups_owner_write ON public.groups FOR ALL
  USING (teacher_id = current_teacher_id() OR current_app_role() = 'admin')
  WITH CHECK (teacher_id = current_teacher_id());

-- exams (PIENSE I): lectura abierta (sala de espera antes de activarse);
-- solo el docente dueño (o admin) puede crear/editar/borrar.
CREATE POLICY exams_public_read ON public.exams FOR SELECT USING (true);
CREATE POLICY exams_owner_write ON public.exams FOR ALL
  USING (teacher_id = current_teacher_id() OR current_app_role() = 'admin')
  WITH CHECK (teacher_id = current_teacher_id());

-- exam_sessions_p2 (PIENSE II): mismo patrón con docente_id.
CREATE POLICY exam_sessions_p2_public_read ON public.exam_sessions_p2 FOR SELECT USING (true);
CREATE POLICY exam_sessions_p2_owner_write ON public.exam_sessions_p2 FOR ALL
  USING (docente_id = current_teacher_id() OR current_app_role() = 'admin')
  WITH CHECK (docente_id = current_teacher_id());

-- Catálogos de reactivos y tienda: lectura abierta a cualquiera (incluye
-- el modo invitado de PIENSE I). Nada en el cliente les escribe hoy.
CREATE POLICY questions_read ON public.questions FOR SELECT USING (true);
CREATE POLICY piense2_questions_read ON public.piense2_questions FOR SELECT USING (true);
CREATE POLICY shop_items_read ON public.shop_items FOR SELECT USING (true);
CREATE POLICY avatar_items_read ON public.avatar_items FOR SELECT USING (true);

-- responses (PIENSE I): el alumno dueño (o invitado, student_id nulo) inserta;
-- el docente dueño del examen y el admin leen todo.
CREATE POLICY responses_insert ON public.responses FOR INSERT
  WITH CHECK (student_id = current_student_id() OR student_id IS NULL);
CREATE POLICY responses_select ON public.responses FOR SELECT
  USING (
    student_id = current_student_id()
    OR current_app_role() = 'admin'
    OR exam_id IN (SELECT id FROM public.exams WHERE teacher_id = current_teacher_id())
  );

-- student_results_p2: mismo patrón vía exam_sessions_p2 (sin modo invitado).
CREATE POLICY student_results_p2_insert ON public.student_results_p2 FOR INSERT
  WITH CHECK (student_id = current_student_id());
CREATE POLICY student_results_p2_select ON public.student_results_p2 FOR SELECT
  USING (
    student_id = current_student_id()
    OR current_app_role() = 'admin'
    OR session_id IN (SELECT id FROM public.exam_sessions_p2 WHERE docente_id = current_teacher_id())
  );

-- Inventario (compras de tienda): solo el propio alumno.
CREATE POLICY student_inventory_self ON public.student_inventory FOR ALL
  USING (student_id = current_student_id() OR current_app_role() = 'admin')
  WITH CHECK (student_id = current_student_id());

-- student_challenges / challenge_results ("retos" entre compañeros, PIENSE I):
-- se comparten por código entre cualquier alumno o invitado, lectura y
-- escritura abiertas, sin UPDATE/DELETE desde el cliente.
CREATE POLICY student_challenges_public ON public.student_challenges FOR SELECT USING (true);
CREATE POLICY student_challenges_insert ON public.student_challenges FOR INSERT WITH CHECK (true);
CREATE POLICY challenge_results_public ON public.challenge_results FOR SELECT USING (true);
CREATE POLICY challenge_results_insert ON public.challenge_results FOR INSERT WITH CHECK (true);

-- coordinator_feedback: el admin que la escribe, y el docente a quien va dirigida.
CREATE POLICY coordinator_feedback_admin ON public.coordinator_feedback FOR ALL
  USING (current_app_role() = 'admin')
  WITH CHECK (current_app_role() = 'admin');
CREATE POLICY coordinator_feedback_teacher_read ON public.coordinator_feedback FOR SELECT
  USING (teacher_id = current_teacher_id());
CREATE POLICY coordinator_feedback_teacher_mark_read ON public.coordinator_feedback FOR UPDATE
  USING (teacher_id = current_teacher_id());

-- =========================================================================
-- REVERSA RÁPIDA — si algo se rompe en producción, correr esto y luego
-- revertir el deployment de Vercel al commit anterior mientras se investiga.
-- =========================================================================
-- ALTER TABLE public.teachers DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.groups DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.students DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.questions DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.exams DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.responses DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.shop_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.student_inventory DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.piense2_questions DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.exam_sessions_p2 DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.student_results_p2 DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.student_challenges DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.challenge_results DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.avatar_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.admins DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.coordinator_feedback DISABLE ROW LEVEL SECURITY;
