-- SCHEMA PARA PIENSE I Y PIENSE II
-- Recreación de las tablas basadas en el código del frontend

-- =========================================================================
-- 1. TABLAS COMPARTIDAS Y DE CONFIGURACIÓN
-- =========================================================================

-- Tabla de Maestros
CREATE TABLE IF NOT EXISTS public.teachers (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    email text UNIQUE NOT NULL,
    password_hash text
);

-- Tabla de Grupos (asociados a un maestro)
CREATE TABLE IF NOT EXISTS public.groups (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    teacher_id uuid REFERENCES public.teachers(id) ON DELETE CASCADE,
    name text NOT NULL,
    access_code text UNIQUE NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- Tabla de Alumnos
CREATE TABLE IF NOT EXISTS public.students (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nombre text NOT NULL,
    email text UNIQUE NOT NULL,
    password_hash text NOT NULL,
    grado text,
    puntos_totales integer DEFAULT 0,
    playera_activa text,
    playeras_desbloqueadas jsonb DEFAULT '[]'::jsonb
);

-- =========================================================================
-- 2. PIENSE I
-- =========================================================================

-- Tabla de Preguntas (Reactivos PIENSE I)
CREATE TABLE IF NOT EXISTS public.questions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stem text NOT NULL,
    option_a text NOT NULL,
    option_b text NOT NULL,
    option_c text NOT NULL,
    option_d text NOT NULL,
    correct_answer text NOT NULL,
    subject text NOT NULL,
    topic text,
    reading_passage text,
    reading_title text,
    difficulty text,
    source text
);

-- Tabla de Exámenes (Sesiones PIENSE I)
CREATE TABLE IF NOT EXISTS public.exams (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    teacher_id uuid REFERENCES public.teachers(id) ON DELETE CASCADE,
    group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,
    name text NOT NULL,
    question_ids jsonb NOT NULL,
    status text DEFAULT 'draft',
    activated_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);

-- Tabla de Resultados / Respuestas (PIENSE I)
CREATE TABLE IF NOT EXISTS public.responses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    exam_id uuid REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id uuid REFERENCES public.students(id) ON DELETE CASCADE,
    answers jsonb NOT NULL,
    score integer NOT NULL,
    total_questions integer NOT NULL,
    elapsed_seconds integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- =========================================================================
-- 3. TIENDA DE RECOMPENSAS
-- =========================================================================

-- Catálogo de ítems en la tienda
CREATE TABLE IF NOT EXISTS public.shop_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    slug text UNIQUE NOT NULL,
    nombre text NOT NULL,
    costo_puntos integer NOT NULL DEFAULT 0,
    disponible boolean DEFAULT true
);

-- Inventario de cada alumno (ítems comprados)
CREATE TABLE IF NOT EXISTS public.student_inventory (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id) ON DELETE CASCADE,
    item_id uuid REFERENCES public.shop_items(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now()
);

-- =========================================================================
-- 4. PIENSE II
-- =========================================================================

-- Tabla de Preguntas (Reactivos PIENSE II)
CREATE TABLE IF NOT EXISTS public.piense2_questions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enunciado text NOT NULL,
    contexto text,
    opciones jsonb NOT NULL,
    respuesta_correcta text NOT NULL,
    prueba text NOT NULL,
    subtipo text,
    activo boolean DEFAULT true
);

-- Tabla de Exámenes (Sesiones PIENSE II)
CREATE TABLE IF NOT EXISTS public.exam_sessions_p2 (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,
    docente_id uuid REFERENCES public.teachers(id) ON DELETE CASCADE,
    nombre text NOT NULL,
    question_ids jsonb NOT NULL,
    prueba text NOT NULL,
    activa boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);

-- Tabla de Resultados / Respuestas (PIENSE II)
CREATE TABLE IF NOT EXISTS public.student_results_p2 (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id uuid REFERENCES public.exam_sessions_p2(id) ON DELETE CASCADE,
    student_id uuid REFERENCES public.students(id) ON DELETE CASCADE,
    respuestas jsonb NOT NULL,
    calificacion integer NOT NULL,
    aciertos integer NOT NULL,
    total_preguntas integer NOT NULL,
    tiempo_segundos integer NOT NULL,
    puntos_ganados integer NOT NULL,
    completed_at timestamp with time zone DEFAULT now()
);

-- =========================================================================
-- 5. PERMISOS (ROW LEVEL SECURITY)
-- =========================================================================

ALTER TABLE public.teachers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.students DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.responses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.piense2_questions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_sessions_p2 DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_results_p2 DISABLE ROW LEVEL SECURITY;

-- Insertar las playeras básicas
-- Envuelto en DO/EXCEPTION porque la tabla real puede tener columnas
-- adicionales NOT NULL (p. ej. "pais") que este schema reconstruido no
-- conoce; si falla, no debe tumbar el resto del script (secciones 1-6).
DO $$
BEGIN
  INSERT INTO public.shop_items (slug, nombre, costo_puntos, disponible) VALUES
  ('mexico', 'México (Básica)', 0, true),
  ('oro', 'Playera de Oro', 100, true),
  ('diamante', 'Diamante Cósmico', 500, true)
  ON CONFLICT (slug) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Se omitió el insert de shop_items (tabla real con columnas adicionales): %', SQLERRM;
END $$;

-- =========================================================================
-- 6. PRUEBAS ESTANDARIZADAS 1° A 11° (generador rápido: 10 reactivos / 10 min)
-- =========================================================================
-- Todo este bloque es ADITIVO y seguro de volver a correr en una base de
-- datos que YA tiene maestros, grupos, alumnos y reactivos cargados:
--   - Las columnas se agregan solo si no existen (IF NOT EXISTS).
--   - El banco graduado 1°-11° se identifica con source = 'banco_1a11_original'
--     y se reemplaza solo a sí mismo (DELETE + INSERT por ese source), nunca
--     toca el banco de PIENSE I/PIENSE II ni nada capturado por docentes.

-- 6.1 Columna de grado escolar en el banco de PIENSE I (tabla questions)
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS grade_level smallint;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'questions_grade_level_check') THEN
    ALTER TABLE public.questions
      ADD CONSTRAINT questions_grade_level_check CHECK (grade_level IS NULL OR grade_level BETWEEN 1 AND 11);
  END IF;
END $$;

-- 6.2 Columnas que el frontend ya usa en exams / exam_sessions_p2 pero que
-- faltaban en el schema reconstruido (código de examen, duración, modalidad).
ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS exam_code text;
ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS duration_seconds integer DEFAULT 600;
ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS modalidad text DEFAULT 'examen';
CREATE UNIQUE INDEX IF NOT EXISTS exams_exam_code_key ON public.exams (exam_code) WHERE exam_code IS NOT NULL;

ALTER TABLE public.exam_sessions_p2 ADD COLUMN IF NOT EXISTS codigo text;
ALTER TABLE public.exam_sessions_p2 ADD COLUMN IF NOT EXISTS duracion_segundos integer DEFAULT 600;
ALTER TABLE public.exam_sessions_p2 ADD COLUMN IF NOT EXISTS modalidad text DEFAULT 'examen';
CREATE UNIQUE INDEX IF NOT EXISTS exam_sessions_p2_codigo_key ON public.exam_sessions_p2 (codigo) WHERE codigo IS NOT NULL;

-- 6.3 El banco histórico de PIENSE I (tabla questions) está alineado a 6to
-- grado. Si ya tiene reactivos sin grade_level, se etiquetan como 6° para
-- que aparezcan de inmediato en el generador — no se borra ni modifica
-- ningún otro dato de esas filas.
UPDATE public.questions
SET grade_level = 6
WHERE grade_level IS NULL
  AND (source IS NULL OR source <> 'banco_1a11_original');

-- 6.4 Banco original graduado 1° a 11° (reactivos propios, no tomados de
-- material con derechos reservados de terceros).
DELETE FROM public.questions WHERE source = 'banco_1a11_original';

INSERT INTO public.questions
  (grade_level, subject, topic, difficulty, stem, option_a, option_b, option_c, option_d, correct_answer, reading_title, reading_passage, source)
VALUES
-- ── 1° grado ──────────────────────────────────────────────────────────
(1,'matematicas','Suma y resta','facil','2 + 3 = ?','4','5','6','7','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Suma y resta','facil','7 − 2 = ?','3','4','5','6','C',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Suma y resta','facil','Si Luis tiene 3 canicas y gana 4 más, ¿cuántas tiene en total?','6','7','8','5','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Conteo','facil','¿Qué número va antes del 5?','3','4','6','7','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Conteo','facil','Cuenta: 1, 2, 3, __, 5','4','6','7','8','A',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Conteo','facil','¿Cuántos dedos tiene una mano?','4','5','6','10','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Comparación de números','facil','¿Cuál número es menor: 4 o 8?','4','8','son iguales','ninguno','A',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Comparación de números','facil','¿Cuál de estos números es el mayor: 2, 9, 5?','2','9','5','ninguno','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Comparación de números','medio','¿Qué símbolo va entre 6 y 3: 6 __ 3?','<','>','=','+','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Formas geométricas','facil','¿Cuántos lados tiene un cuadrado?','3','4','5','6','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Formas geométricas','facil','¿Qué forma tiene una pelota?','cuadrado','triángulo','círculo','rectángulo','C',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Formas geométricas','facil','¿Cuántos lados tiene un triángulo?','2','3','4','5','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Valor posicional','medio','¿Cuántas decenas hay en el número 20?','1','2','20','0','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Valor posicional','medio','El número 15 tiene __ unidades.','1','5','10','15','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Valor posicional','medio','¿Cuál número tiene 1 decena y 3 unidades?','31','13','10','3','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Rimas','facil','¿Cuál palabra rima con "pan"?','sol','flan','mesa','libro','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Rimas','facil','¿Cuál palabra rima con "flor"?','amor','casa','perro','luz','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Rimas','facil','¿Cuál palabra rima con "ratón"?','mesa','camión','perro','sol','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Letras y sonidos','facil','¿Cuál es la última letra de la palabra "sol"?','s','o','l','a','C',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Letras y sonidos','facil','¿Con qué letra empieza la palabra "árbol"?','a','r','b','t','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Letras y sonidos','facil','¿Cuál palabra empieza con la letra "m"?','pato','mesa','sol','casa','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Vocabulario','facil','¿Qué palabra nombra una fruta?','mesa','manzana','silla','libro','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Vocabulario','facil','¿Qué palabra nombra un color?','azul','mesa','perro','casa','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Vocabulario','facil','¿Qué palabra nombra una parte del cuerpo?','mano','mesa','sol','libro','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Sílabas','facil','¿Cuántas sílabas tiene la palabra "casa"?','1','2','3','4','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Sílabas','medio','¿Cuántas sílabas tiene la palabra "mariposa"?','2','3','4','5','C',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Sílabas','facil','¿Cuántas sílabas tiene la palabra "sol"?','1','2','3','4','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Gramática','facil','Completa: La niña __ feliz.','está','estás','estoy','estamos','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Gramática','facil','¿Cuál palabra es un nombre de persona?','correr','Ana','rojo','rápido','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Gramática','medio','Completa: Los perros __ en el jardín.','juega','juego','juegan','jugar','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Colores','facil','What color is the sun?','blue','yellow','green','black','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Colores','facil','What color is grass?','red','green','purple','orange','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Colores','facil','What color is the sky on a clear day?','brown','blue','yellow','gray','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Números','facil','How do you say "3" in English?','two','three','four','five','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Números','facil','How do you say "7" in English?','six','eight','seven','nine','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Números','facil','How many is "ten"?','5','8','10','12','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Animales','facil','What animal says "moo"?','dog','cat','cow','bird','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Animales','facil','What animal lives in water and has fins?','fish','dog','cat','bird','A',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Animales','medio','What do we call a baby dog?','kitten','puppy','cub','chick','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Saludos','facil','How do you say "hola" in English?','bye','hello','please','thanks','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Saludos','facil','How do you say "gracias" in English?','sorry','please','thank you','hello','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Saludos','facil','Which word means "adiós"?','goodbye','good morning','good night','hello','A',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Familia','medio','What do you call your father''s mother?','aunt','sister','grandmother','cousin','C',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Familia','facil','What is the English word for "hermano"?','sister','brother','father','cousin','B',NULL,NULL,'banco_1a11_original'),
(1,'ingles','Familia','facil','What is the English word for "mamá"?','dad','mom','aunt','grandma','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Secuencias','facil','¿Qué número sigue: 1, 2, 3, 4, __?','3','5','6','7','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Secuencias','medio','¿Qué sigue en la secuencia: rojo, azul, rojo, azul, __?','rojo','verde','amarillo','azul','A',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Secuencias','facil','¿Qué número sigue: 2, 4, 6, __?','7','8','9','10','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Clasificación','facil','¿Cuál de estos NO es un animal?','perro','gato','mesa','pájaro','C',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Clasificación','facil','¿Cuál de estas NO es una fruta?','manzana','plátano','silla','naranja','C',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Clasificación','facil','¿Cuál de estos es un medio de transporte?','carro','árbol','flor','casa','A',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Analogías simples','medio','Pájaro es a volar como pez es a:','correr','nadar','saltar','dormir','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Analogías simples','medio','Perro es a ladrar como gato es a:','maullar','nadar','volar','rugir','A',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Analogías simples','medio','Sol es a día como luna es a:','mañana','noche','tarde','lluvia','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Patrones','medio','¿Qué figura sigue: círculo, cuadrado, círculo, cuadrado, __?','triángulo','círculo','cuadrado','rectángulo','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Patrones','medio','¿Cuál figura NO sigue el patrón: grande, pequeño, grande, pequeño, grande, grande?','la primera','la segunda','la última','ninguna','C',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Patrones','facil','Completa el patrón: A, B, A, B, __','A','B','C','D','A',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Comparación','facil','¿Cuál es más grande, un elefante o un ratón?','el ratón','el elefante','son iguales','ninguno','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Comparación','medio','¿Cuál pesa más, una pluma o una piedra?','la pluma','la piedra','pesan igual','ninguna','B',NULL,NULL,'banco_1a11_original'),
(1,'habilidad','Comparación','medio','¿Cuál es más larga, una serpiente o una hormiga?','la hormiga','la serpiente','son iguales','ninguna','B',NULL,NULL,'banco_1a11_original'),
-- ── 2° grado ──────────────────────────────────────────────────────────
(2,'matematicas','Suma y resta','facil','38 + 15 = ?','43','53','63','48','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Suma y resta','medio','72 − 29 = ?','43','53','33','47','A',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Suma y resta','medio','Carla tenía 25 estampas y perdió 8. ¿Cuántas le quedan?','15','17','18','33','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Multiplicación inicial','medio','Si cada caja tiene 2 lápices, ¿cuántos lápices hay en 4 cajas?','6','8','10','4','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Multiplicación inicial','medio','3 grupos de 5 manzanas, ¿cuántas manzanas en total?','8','10','15','20','C',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Multiplicación inicial','facil','¿Cuánto es el doble de 6?','8','10','12','16','C',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Valor posicional','medio','¿Cuántas decenas y unidades tiene el número 47?','4 decenas, 7 unidades','7 decenas, 4 unidades','47 decenas','4 unidades, 7 decenas','A',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Valor posicional','medio','¿Cuál número es 3 decenas y 6 unidades?','63','36','306','30','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Valor posicional','facil','¿Cuál es el número mayor: 58 o 85?','58','85','son iguales','ninguno','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Medidas simples','facil','¿Qué instrumento se usa para medir la temperatura?','regla','termómetro','reloj','báscula','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Medidas simples','facil','¿Qué instrumento se usa para medir el tiempo?','reloj','regla','termómetro','báscula','A',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Medidas simples','facil','¿Cuántos días tiene una semana?','5','6','7','8','C',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Problemas con dinero','medio','Si tienes 2 monedas de 5 pesos, ¿cuánto dinero tienes?','5','7','10','15','C',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Problemas con dinero','medio','Compras un dulce de 8 pesos y pagas con 10. ¿Cuánto te regresan?','1','2','3','18','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Problemas con dinero','medio','¿Cuántos pesos son 4 monedas de 10 pesos?','14','20','40','44','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Comprensión lectora','facil','¿Cómo se llama el perro de Sofía?','Rex','Max','Toby','Fido','B','El perro de Sofía','Sofía tiene un perro llamado Max. Todas las tardes lo saca a pasear al parque cercano. A Max le encanta correr detrás de las pelotas.','banco_1a11_original'),
(2,'espanol','Comprensión lectora','facil','¿A dónde lleva Sofía a su perro?','a la escuela','al parque','a la tienda','a la playa','B','El perro de Sofía','Sofía tiene un perro llamado Max. Todas las tardes lo saca a pasear al parque cercano. A Max le encanta correr detrás de las pelotas.','banco_1a11_original'),
(2,'espanol','Comprensión lectora','medio','¿Qué le gusta hacer a Max?','dormir','nadar','correr detrás de pelotas','ladrar','C','El perro de Sofía','Sofía tiene un perro llamado Max. Todas las tardes lo saca a pasear al parque cercano. A Max le encanta correr detrás de las pelotas.','banco_1a11_original'),
(2,'espanol','Sinónimos','facil','¿Cuál palabra significa lo mismo que "bonito"?','feo','hermoso','triste','grande','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Sinónimos','facil','¿Cuál palabra significa lo mismo que "rápido"?','lento','veloz','pequeño','alto','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Sinónimos','facil','¿Cuál palabra significa lo mismo que "contento"?','alegre','enojado','cansado','asustado','A',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Antónimos','facil','¿Cuál es el antónimo de "grande"?','enorme','pequeño','alto','ancho','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Antónimos','medio','¿Cuál es el antónimo de "día"?','tarde','mañana','noche','sol','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Antónimos','facil','¿Cuál es el antónimo de "subir"?','bajar','correr','caminar','saltar','A',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Plural y singular','facil','¿Cuál es el plural de "casa"?','casas','casa','caseo','casos','A',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Plural y singular','facil','¿Cuál es el singular de "libros"?','librero','libro','libra','librería','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Plural y singular','medio','¿Cuál palabra está en singular?','mesas','sillas','ventana','puertas','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Gramática','medio','¿Cuál es el sujeto en "El gato duerme en el sofá"?','duerme','el gato','en el sofá','sofá','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Gramática','medio','¿Cuál palabra es un verbo en "Los niños corren rápido"?','niños','corren','rápido','los','B',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Gramática','medio','Completa: Ayer yo __ al parque.','voy','iré','fui','va','C',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Días de la semana','facil','What day comes after Monday?','Sunday','Tuesday','Wednesday','Friday','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Días de la semana','facil','What is the first day of the school week?','Saturday','Sunday','Monday','Friday','C',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Días de la semana','facil','How many days are in a week?','5','6','7','8','C',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Objetos del salón','facil','What do you use to write?','a chair','a pencil','a window','a door','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Objetos del salón','facil','What do you sit on in a classroom?','a desk','a chair','a book','a board','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Objetos del salón','facil','Where does the teacher write?','on the floor','on the board','on the chair','on the window','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Verbos simples','medio','I ___ to school every day.','go','goes','going','gone','A',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Verbos simples','medio','She ___ a book right now.','read','reads','is reading','readed','C',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Verbos simples','medio','They ___ soccer on weekends.','plays','play','playing','played','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Preposiciones de lugar','facil','The cat is ___ the box.','in','is','are','be','A',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Preposiciones de lugar','facil','The book is ___ the table.','on','at','be','is','A',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Preposiciones de lugar','facil','The dog is ___ the house.','under','is','be','to','A',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Adjetivos simples','facil','The elephant is very ___.','small','big','fast','tiny','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Adjetivos simples','facil','The ice is ___.','hot','cold','warm','soft','B',NULL,NULL,'banco_1a11_original'),
(2,'ingles','Adjetivos simples','facil','The sun is ___.','cold','dark','bright','wet','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Secuencias numéricas','facil','¿Qué número sigue: 5, 10, 15, __?','18','20','25','16','B',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Secuencias numéricas','medio','¿Qué número falta: 3, 6, __, 12?','7','8','9','10','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Secuencias numéricas','medio','¿Qué número sigue: 20, 18, 16, __?','14','15','17','12','A',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Analogías','medio','Zapato es a pie como guante es a:','cabeza','mano','pie','brazo','B',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Analogías','medio','Libro es a leer como lápiz es a:','cortar','escribir','pintar','borrar','B',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Analogías','medio','Pez es a agua como pájaro es a:','tierra','aire','fuego','agua','B',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Clasificación','facil','¿Cuál de estos NO es un medio de transporte?','carro','avión','árbol','barco','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Clasificación','facil','¿Cuál de estos es un instrumento musical?','guitarra','mesa','silla','libro','A',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Clasificación','medio','¿Cuál de estos NO es una estación del año?','verano','invierno','martes','otoño','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Razonamiento lógico','medio','Si todos los pájaros tienen plumas, y el gorrión es un pájaro, entonces el gorrión tiene:','pelo','escamas','plumas','nada','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Razonamiento lógico','medio','Si hoy es lunes, ¿qué día fue ayer?','domingo','martes','miércoles','sábado','A',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Razonamiento lógico','dificil','Si Juan es más alto que Pedro, y Pedro es más alto que Luis, ¿quién es el más bajo?','Juan','Pedro','Luis','no se sabe','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Patrones','medio','¿Qué sigue: 2, 2, 4, 4, 6, 6, __?','6','7','8','9','C',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Patrones','facil','Completa el patrón: AA, BB, AA, BB, __','AA','CC','BA','AB','A',NULL,NULL,'banco_1a11_original'),
(2,'habilidad','Patrones','medio','¿Qué figura sigue: triángulo, triángulo, cuadrado, triángulo, triángulo, cuadrado, __?','cuadrado','triángulo','círculo','rectángulo','B',NULL,NULL,'banco_1a11_original'),
-- ── 3° grado ──────────────────────────────────────────────────────────
(3,'matematicas','Multiplicación','medio','6 × 4 = ?','20','22','24','26','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Multiplicación','medio','7 × 3 = ?','18','20','21','24','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Multiplicación','dificil','Si hay 5 bolsas con 6 canicas cada una, ¿cuántas canicas hay en total?','25','30','35','11','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','División','medio','24 ÷ 6 = ?','3','4','5','6','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','División','medio','45 ÷ 9 = ?','4','5','6','9','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','División','dificil','Si repartes 20 dulces entre 4 niños por igual, ¿cuántos recibe cada uno?','4','5','6','16','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Fracciones','medio','¿Qué fracción representa "un cuarto"?','1/2','1/3','1/4','2/4','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Fracciones','medio','¿Cuál fracción es mayor: 1/2 o 1/4?','1/2','1/4','son iguales','no se puede saber','A',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Fracciones','dificil','Si divides una pizza en 8 partes iguales y comes 2, ¿qué fracción comiste?','2/6','2/8','8/2','6/8','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Geometría básica','medio','¿Cuál es el perímetro de un cuadrado de lado 4 cm?','8 cm','12 cm','16 cm','20 cm','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Geometría básica','facil','¿Cuántos lados tiene un pentágono?','4','5','6','7','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Geometría básica','facil','¿Cuál figura tiene todos sus lados iguales y 4 ángulos rectos?','rectángulo','cuadrado','triángulo','círculo','B',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Medidas y tiempo','facil','¿Cuántos minutos tiene una hora?','30','45','60','100','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Medidas y tiempo','facil','¿Cuántos meses tiene un año?','10','11','12','13','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Medidas y tiempo','medio','Si son las 3:00 y pasan 2 horas, ¿qué hora es?','4:00','5:00','6:00','1:00','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Comprensión lectora','medio','¿Para qué usa su lengua el oso hormiguero?','para nadar','para atrapar hormigas','para trepar árboles','para dormir','B','El oso hormiguero','El oso hormiguero tiene una lengua muy larga y pegajosa que usa para atrapar hormigas dentro de los hormigueros. Puede comer miles de hormigas en un solo día.','banco_1a11_original'),
(3,'espanol','Comprensión lectora','medio','¿Cuántas hormigas puede comer en un día?','cientos','miles','decenas','ninguna','B','El oso hormiguero','El oso hormiguero tiene una lengua muy larga y pegajosa que usa para atrapar hormigas dentro de los hormigueros. Puede comer miles de hormigas en un solo día.','banco_1a11_original'),
(3,'espanol','Comprensión lectora','medio','¿Qué característica tiene la lengua del oso hormiguero?','corta y seca','larga y pegajosa','gruesa y dura','delgada y fría','B','El oso hormiguero','El oso hormiguero tiene una lengua muy larga y pegajosa que usa para atrapar hormigas dentro de los hormigueros. Puede comer miles de hormigas en un solo día.','banco_1a11_original'),
(3,'espanol','Antónimos','medio','¿Cuál es el antónimo de "largo"?','ancho','corto','grueso','alto','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Antónimos','facil','¿Cuál es el antónimo de "rápido"?','veloz','lento','fuerte','débil','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Antónimos','facil','¿Cuál es el antónimo de "abrir"?','entrar','cerrar','salir','romper','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Sinónimos','facil','¿Cuál palabra es sinónimo de "feliz"?','triste','contento','enojado','cansado','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Sinónimos','facil','¿Cuál palabra es sinónimo de "comenzar"?','terminar','empezar','parar','continuar','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "enorme"?','pequeño','gigante','mediano','delgado','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Ortografía','medio','Elige la opción con ortografía correcta.','ablar','havlar','hablar','ablarr','C',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Ortografía','facil','¿Cuál palabra está escrita correctamente?','árbol','arbol','arvol','hárbol','A',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Ortografía','medio','¿Cuál palabra lleva "h"?','ospital','hospital','ospitál','spital','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Tipos de oración','medio','¿Cuál oración es interrogativa?','El perro corre.','¿Dónde está el perro?','¡Qué bonito perro!','El perro duerme.','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Tipos de oración','medio','¿Cuál oración es exclamativa?','El sol brilla.','¿Hace calor?','¡Qué calor hace!','Hoy es lunes.','C',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Tipos de oración','dificil','¿Cuál es una oración completa?','El niño','Corre rápido','El niño corre rápido','Rápido y niño','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Vocabulario cotidiano','facil','What do you use to brush your teeth?','a fork','a toothbrush','a spoon','a comb','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Vocabulario cotidiano','facil','Where do you sleep?','kitchen','bathroom','bedroom','garage','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Vocabulario cotidiano','facil','What do you wear on your feet?','gloves','hat','shoes','scarf','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Presente simple','medio','My mom ___ dinner every night.','cook','cooks','cooking','cooked','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Presente simple','medio','We ___ to the park on Saturdays.','go','goes','going','went','A',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Presente simple','medio','He ___ his homework after school.','do','does','doing','did','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Plural en inglés','facil','What is the plural of "dog"?','dogs','doges','dogies','dogs''s','A',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Plural en inglés','medio','What is the plural of "box"?','boxs','boxes','boxies','box','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Plural en inglés','dificil','What is the plural of "child"?','childs','childes','children','childrens','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Preguntas simples','facil','___ is your name?','What','Who','Where','When','A',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Preguntas simples','medio','___ old are you?','What','How','Who','Where','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Preguntas simples','medio','___ do you live?','What','Who','Where','When','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Adjetivos comparativos','medio','An elephant is ___ than a mouse.','small','smaller','bigger','big','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Adjetivos comparativos','dificil','This book is ___ than that one.','interesting','more interesting','interestinger','most interesting','B',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Adjetivos comparativos','medio','My sister is ___ than me.','tall','taller','tallest','more tall','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Secuencias','facil','¿Qué número sigue: 2, 4, 6, 8, __?','9','10','12','14','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Secuencias','medio','¿Qué número sigue: 1, 3, 5, 7, __?','8','9','10','11','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Secuencias','medio','¿Qué letra sigue: A, C, E, G, __?','H','I','J','K','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Analogías','medio','Libro es a leer como tenedor es a:','cortar','comer','cocinar','lavar','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Analogías','medio','Médico es a hospital como maestro es a:','casa','escuela','tienda','parque','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Analogías','medio','Pollo es a gallina como ternero es a:','caballo','vaca','cerdo','oveja','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Silogismos simples','medio','Todos los perros ladran. Rex es un perro. Por lo tanto, Rex:','maúlla','ladra','vuela','nada','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Silogismos simples','medio','Ningún pez vuela. El salmón es un pez. Por lo tanto, el salmón:','vuela','no vuela','camina','canta','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Silogismos simples','dificil','Todas las aves tienen plumas. El águila es un ave. Por lo tanto, el águila tiene:','pelo','escamas','plumas','nada','C',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Clasificación','facil','¿Cuál palabra no pertenece al grupo?','manzana','zanahoria','pera','uva','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Clasificación','facil','¿Cuál de estos NO es un instrumento musical?','piano','violín','silla','tambor','C',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Clasificación','medio','¿Cuál de estos es un planeta?','sol','luna','tierra','estrella','C',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Razonamiento espacial','medio','Si giras un cuadrado 90 grados, ¿en qué se convierte?','en un triángulo','sigue siendo un cuadrado','en un círculo','en una línea','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Razonamiento espacial','medio','¿Cuál figura tiene más lados: un hexágono o un pentágono?','el pentágono','el hexágono','tienen los mismos','ninguno tiene lados','B',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Razonamiento espacial','dificil','Si un cubo tiene 6 caras, ¿cuántas caras tiene si le quitas la mitad?','2','3','4','6','B',NULL,NULL,'banco_1a11_original'),
-- ── 4° grado ──────────────────────────────────────────────────────────
(4,'matematicas','Fracciones','medio','1/4 + 2/4 = ?','1/4','4/4','3/4','2/4','C',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Fracciones','medio','¿Cuál fracción es equivalente a 1/2?','2/5','2/4','3/5','1/5','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Fracciones','dificil','De 12 galletas, Juan comió 1/3. ¿Cuántas comió?','3','4','6','9','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Multiplicación y división','medio','7 × 8 = ?','54','64','58','56','D',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Multiplicación y división','medio','96 ÷ 8 = ?','10','11','12','13','C',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Multiplicación y división','dificil','Si un paquete tiene 9 lápices y compras 6 paquetes, ¿cuántos lápices tienes?','45','54','63','15','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Perímetro y área','medio','El perímetro de un cuadrado de lado 5 cm es:','15 cm','10 cm','25 cm','20 cm','D',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Perímetro y área','medio','¿Cuál es el área de un rectángulo de 4 cm de largo por 3 cm de ancho?','14 cm²','7 cm²','12 cm²','10 cm²','C',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Perímetro y área','dificil','Un terreno rectangular mide 6 m por 4 m. ¿Cuál es su área?','10 m²','20 m²','24 m²','28 m²','C',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Geometría','facil','¿Cuántos lados tiene un hexágono?','5','6','7','8','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Geometría','medio','¿Qué tipo de ángulo mide menos de 90°?','recto','agudo','obtuso','llano','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Geometría','facil','¿Cuántos ángulos rectos tiene un rectángulo?','1','2','3','4','D',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Problemas de varios pasos','dificil','Ana compra 3 bolsas de 8 dulces cada una y regala 10. ¿Cuántos dulces le quedan?','14','16','24','34','A',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Problemas de varios pasos','medio','Un tren recorre 120 km en 2 horas. ¿Cuántos km recorre en 1 hora?','40','60','80','100','B',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Problemas de varios pasos','medio','Pedro ahorra 5 pesos cada día. ¿Cuánto ahorra en 6 días?','11','25','30','35','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Idea principal','medio','¿Cuál es la idea principal del texto?','Las flores producen néctar','Las abejas recolectan néctar y ayudan a las plantas','Las plantas se reproducen solas','Las abejas viven en colmenas','B','Las abejas','Las abejas recolectan el néctar de las flores y lo transforman en miel dentro de la colmena. Gracias a su trabajo, muchas plantas pueden reproducirse.','banco_1a11_original'),
(4,'espanol','Idea principal','medio','¿Dónde transforman las abejas el néctar en miel?','en las flores','en la colmena','en el aire','en el suelo','B','Las abejas','Las abejas recolectan el néctar de las flores y lo transforman en miel dentro de la colmena. Gracias a su trabajo, muchas plantas pueden reproducirse.','banco_1a11_original'),
(4,'espanol','Idea principal','medio','¿Qué beneficio traen las abejas a las plantas?','las destruyen','las riegan','ayudan a que se reproduzcan','les quitan el color','C','Las abejas','Las abejas recolectan el néctar de las flores y lo transforman en miel dentro de la colmena. Gracias a su trabajo, muchas plantas pueden reproducirse.','banco_1a11_original'),
(4,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "recolectar"?','tirar','perder','juntar','esconder','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Sinónimos','facil','¿Cuál palabra es sinónimo de "veloz"?','lento','rápido','pesado','suave','B',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "construir"?','destruir','edificar','romper','tirar','B',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tiempos verbales','medio','En la oración "Las abejas volaron toda la tarde", el verbo está en tiempo:','futuro','presente','ninguno','pasado','D',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tiempos verbales','medio','¿Cuál oración está en tiempo futuro?','Comí pan.','Como pan.','Comeré pan.','Comiendo pan.','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tiempos verbales','facil','Completa en presente: Ella __ todos los días.','estudió','estudiará','estudia','estudiando','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Ortografía','medio','¿Cuál de las siguientes palabras está escrita correctamente?','arbol','arvol','árbol','hárbol','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Ortografía','medio','¿Cuál de estas palabras necesita tilde?','camion','mesa','silla','perro','A',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Ortografía','dificil','¿Cuál palabra está mal escrita?','zapato','caballo','jugete','mesa','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tipos de palabras','facil','¿Cuál palabra es un sustantivo?','corre','rápido','perro','y','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tipos de palabras','medio','¿Cuál palabra es un adjetivo?','casa','grande','correr','y','B',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tipos de palabras','facil','¿Cuál palabra es un verbo?','mesa','azul','saltar','rápido','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Gramática presente/pasado','medio','Yesterday, she ___ to the store.','go','goes','went','going','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Gramática presente/pasado','medio','They ___ playing soccer right now.','is','are','am','be','B',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Gramática presente/pasado','medio','Last week, we ___ a movie.','watch','watches','watched','watching','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Vocabulario escolar','facil','What do you use to erase pencil marks?','a ruler','an eraser','a stapler','a marker','B',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Vocabulario escolar','facil','Where do students borrow books?','cafeteria','gym','library','office','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Vocabulario escolar','facil','What subject teaches about numbers?','math','art','music','PE','A',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preposiciones','facil','The ball is ___ the table.','under','is','be','at','A',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preposiciones','medio','We walked ___ the park.','through','is','be','at','A',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preposiciones','facil','The picture is ___ the wall.','on','at','be','to','A',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Adjetivos posesivos','medio','This is ___ book, not yours.','I','me','my','mine''s','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Adjetivos posesivos','medio','That is ___ dog over there.','they','them','their','theirs''re','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Adjetivos posesivos','medio','___ car is red.','He','Him','His','Himself','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preguntas con do/does','medio','___ you like pizza?','Do','Does','Is','Are','A',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preguntas con do/does','medio','___ she speak English?','Do','Does','Is','Are','B',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Preguntas con do/does','medio','___ they play soccer on Fridays?','Do','Does','Is','Are','A',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Analogías','medio','Libro es a leer como tenedor es a:','cortar','comer','cocinar','lavar','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Analogías','medio','Dedo es a mano como pétalo es a:','árbol','flor','raíz','hoja','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Analogías','medio','Profesor es a enseñar como doctor es a:','estudiar','curar','cocinar','construir','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Secuencias','medio','¿Qué número sigue: 5, 10, 20, 40, __?','50','60','70','80','D',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Secuencias','medio','¿Qué letra sigue: B, D, F, H, __?','I','J','K','L','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Secuencias','medio','¿Qué número sigue: 100, 90, 80, __?','60','65','70','75','C',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Clasificación','facil','¿Cuál de estos NO es un deporte?','fútbol','natación','silla','básquetbol','C',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Clasificación','dificil','¿Cuál de estos es un número primo?','4','6','7','9','C',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Clasificación','medio','¿Cuál de estos NO es un mamífero?','perro','ballena','serpiente','gato','C',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Silogismos','medio','Todos los estudiantes de la clase usan uniforme. María es estudiante de la clase. Por lo tanto, María:','usa uniforme','no usa uniforme','es maestra','no va a la escuela','A',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Silogismos','medio','Ningún anfibio vive solo en el agua. La rana es un anfibio. Por lo tanto, la rana:','vive solo en el agua','no vive solo en el agua','no existe','es un pez','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Silogismos','medio','Todos los triángulos tienen 3 lados. Esta figura tiene 3 lados. ¿Es necesariamente un triángulo?','sí, siempre','no, podría ser otra figura','nunca','solo a veces','A',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Razonamiento numérico','medio','Si x + 5 = 12, ¿cuál es el valor de x?','5','6','7','8','C',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Razonamiento numérico','dificil','¿Cuál número falta: 2, __, 8, 16, 32 (cada número es el doble del anterior)?','3','4','5','6','B',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Razonamiento numérico','medio','Si el doble de un número es 18, ¿cuál es el número?','6','9','36','20','B',NULL,NULL,'banco_1a11_original'),
-- ── 5° grado ──────────────────────────────────────────────────────────
(5,'matematicas','Porcentajes','medio','El 50% de 80 es:','20','30','40','50','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Porcentajes','medio','El 25% de 160 es:','30','40','45','50','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Porcentajes','dificil','Si el 10% de un número es 7, ¿cuál es el número?','17','70','700','7.7','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Decimales','medio','0.5 + 0.25 = ?','0.65','0.80','0.75','0.70','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Decimales','facil','¿Cuál decimal es mayor: 0.6 o 0.45?','0.6','0.45','son iguales','no se puede saber','A',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Decimales','medio','1.5 × 2 = ?','2.5','3','3.5','4','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Razonamiento proporcional','medio','Un autobús recorre 60 km en 1 hora. ¿Cuántos km recorrerá en 3 horas a la misma velocidad?','120','200','180','150','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Razonamiento proporcional','dificil','Si 4 lápices cuestan $16, ¿cuánto cuestan 7 lápices al mismo precio?','$24','$26','$28','$32','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Razonamiento proporcional','medio','Una receta para 4 personas usa 2 tazas de harina. ¿Cuántas tazas se necesitan para 8 personas?','3','4','5','6','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Divisores y múltiplos','dificil','¿Cuál es el máximo común divisor de 12 y 18?','2','9','3','6','D',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Divisores y múltiplos','medio','¿Cuál de estos números es múltiplo de 7?','27','30','35','40','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Divisores y múltiplos','dificil','¿Cuál es el mínimo común múltiplo de 4 y 6?','10','12','24','48','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Volumen básico','medio','¿Cuál es el volumen de un cubo de arista 2 cm?','4 cm³','6 cm³','8 cm³','12 cm³','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Volumen básico','dificil','Una caja mide 3 cm × 4 cm × 2 cm. ¿Cuál es su volumen?','9 cm³','24 cm³','20 cm³','18 cm³','B',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Volumen básico','facil','¿Cuántas caras tiene un cubo?','4','6','8','12','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Inferencia','medio','¿Qué se puede inferir de la lectura?','Mariana vive sola','Alguien pudo haber entrado a la casa','La casa estaba en reparación','Mariana olvidó apagar las luces','B','La puerta abierta','Cuando Mariana llegó a casa, encontró la puerta abierta y las luces encendidas, aunque recordaba haberlas apagado antes de salir.','banco_1a11_original'),
(5,'espanol','Inferencia','medio','¿Qué recordaba Mariana haber hecho antes de salir?','cerrar la puerta y apagar las luces','dejar la puerta abierta','encender las luces','nada en especial','A','La puerta abierta','Cuando Mariana llegó a casa, encontró la puerta abierta y las luces encendidas, aunque recordaba haberlas apagado antes de salir.','banco_1a11_original'),
(5,'espanol','Inferencia','dificil','¿Qué sentimiento transmite probablemente la situación a Mariana?','alegría','sorpresa o inquietud','aburrimiento','indiferencia','B','La puerta abierta','Cuando Mariana llegó a casa, encontró la puerta abierta y las luces encendidas, aunque recordaba haberlas apagado antes de salir.','banco_1a11_original'),
(5,'espanol','Sinónimos','medio','¿Cuál palabra podría sustituir a "encontró" sin cambiar el sentido?','perdió','compró','halló','rompió','C',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "recordaba"?','olvidaba','rememoraba','ignoraba','dudaba','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "apagar"?','encender','extinguir','prender','iluminar','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sujeto y predicado','medio','Identifica el sujeto de la oración: "Los estudiantes terminaron el examen temprano".','terminaron','el examen','temprano','los estudiantes','D',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sujeto y predicado','medio','Identifica el predicado de "El perro ladró toda la noche".','el perro','ladró toda la noche','toda la noche','el','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sujeto y predicado','dificil','¿Cuál es el sujeto tácito en "Fuimos al cine"?','él','ellos','nosotros','tú','C',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Puntuación','medio','¿Cuál oración usa correctamente la coma?','Compré, manzanas peras y uvas','Compré manzanas peras, y uvas','Compré manzanas, peras y uvas','Compré, manzanas, peras, y, uvas','C',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Puntuación','facil','¿Cuál oración usa correctamente los signos de interrogación?','Como te llamas?','¿Cómo te llamas?','¿Cómo te llamas','Cómo te llamas¿','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Puntuación','facil','¿Cuál oración necesita punto final?','El perro corre','¿Qué hora es?','¡Qué sorpresa!','Vamos a comer','D',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Figuras literarias','medio','"Sus ojos son dos luceros" es un ejemplo de:','símil','metáfora','hipérbole','onomatopeya','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Figuras literarias','medio','"Corría más rápido que el viento" es un ejemplo de:','metáfora','símil','personificación','onomatopeya','B',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Figuras literarias','dificil','"El viento susurraba entre los árboles" es un ejemplo de:','símil','metáfora','personificación','hipérbole','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Antónimos','medio','What is the opposite of "big"?','tall','wide','heavy','small','D',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Antónimos','facil','What is the opposite of "happy"?','glad','sad','excited','calm','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Antónimos','facil','What is the opposite of "fast"?','quick','slow','loud','early','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Comparativos y superlativos','medio','This is the ___ mountain in the world.','tall','taller','tallest','more tall','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Comparativos y superlativos','medio','My car is ___ than yours.','fast','faster','fastest','more fast','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Comparativos y superlativos','medio','She is the ___ student in class.','smart','smarter','smartest','more smart','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Pasado simple','medio','I ___ my homework last night.','finish','finishes','finished','finishing','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Pasado simple','medio','They ___ to the beach last summer.','go','goes','went','going','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Pasado simple','medio','She ___ a letter yesterday.','write','writes','wrote','writing','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Conectores','medio','I like tea ___ I don''t like coffee.','and','but','so','because','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Conectores','medio','She studied hard ___ she passed the test.','but','or','so','although','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Conectores','medio','I stayed home ___ it was raining.','but','because','so','and','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Vocabulario del clima','medio','What do you call frozen rain?','fog','hail','wind','mist','B',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Vocabulario del clima','facil','What season comes after winter?','summer','fall','spring','autumn','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Vocabulario del clima','facil','What do you need on a rainy day?','sunglasses','an umbrella','a swimsuit','sunscreen','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Lógica','medio','Si todos los círculos son azules y esta figura es un círculo, entonces esta figura es:','roja','verde','azul','no se puede saber','C',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Lógica','dificil','Si llueve, el suelo se moja. El suelo está mojado. ¿Llovió necesariamente?','sí, siempre','no, podría ser por otra razón','nunca','no se puede mojar el suelo','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Lógica','medio','Si todos los A son B, y todos los B son C, entonces todos los A son:','C','no C','ni A ni C','no se puede saber','A',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Analogías','medio','Termómetro es a temperatura como reloj es a:','fecha','tiempo','calor','distancia','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Analogías','medio','Pintor es a cuadro como escritor es a:','libro','pincel','música','escultura','A',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Analogías','facil','Llave es a abrir como candado es a:','cerrar','romper','pintar','cortar','A',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Secuencias','dificil','¿Qué número sigue: 1, 4, 9, 16, __? (cuadrados)','20','24','25','30','C',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Secuencias','dificil','¿Qué número sigue: 3, 9, 27, __?','54','63','81','90','C',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Secuencias','medio','¿Qué letra sigue: Z, X, V, T, __?','S','R','Q','P','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Silogismos','medio','Ningún número par es impar. 8 es un número par. Por lo tanto, 8:','es impar','no es impar','no es un número','es primo','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Silogismos','facil','Todos los rectángulos tienen 4 lados. Un cuadrado es un rectángulo. Por lo tanto, un cuadrado tiene:','3 lados','4 lados','5 lados','6 lados','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Silogismos','medio','Algunos estudiantes son atletas. Pedro es estudiante. ¿Es Pedro necesariamente atleta?','sí, siempre','no necesariamente','nunca','no se puede saber nada','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Razonamiento matemático','medio','Si 3x = 21, ¿cuál es el valor de x?','6','7','8','9','B',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Razonamiento matemático','dificil','¿Cuál es el siguiente número en 2, 6, 18, 54, __ (×3 cada vez)?','108','144','162','180','C',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Razonamiento matemático','medio','Si un número más 10 es igual a 25, ¿cuál es el número?','10','15','20','35','B',NULL,NULL,'banco_1a11_original'),
-- ── 6° grado ──────────────────────────────────────────────────────────
(6,'matematicas','Operaciones combinadas','medio','¿Cuál es el resultado de (3 + 5) × 2?','11','18','13','16','D',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Operaciones combinadas','medio','¿Cuánto es 20 − 4 × 3?','48','8','16','12','B',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Operaciones combinadas','medio','¿Cuánto es (10 + 2) ÷ 3?','3','4','5','6','B',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ecuaciones simples','medio','Si x + 7 = 15, ¿cuál es el valor de x?','6','9','7','8','D',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ecuaciones simples','medio','Si 2x = 18, ¿cuál es el valor de x?','7','8','9','10','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ecuaciones simples','medio','Si x − 5 = 10, ¿cuál es el valor de x?','5','10','15','20','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ángulos','medio','¿Cuántos grados mide un ángulo recto?','45','180','90','360','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ángulos','facil','¿Cuántos grados mide un ángulo llano?','90','180','270','360','B',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ángulos','dificil','Si dos ángulos son complementarios y uno mide 30°, ¿cuánto mide el otro?','60°','70°','90°','150°','A',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Razones y proporciones','medio','Si 2 manzanas cuestan $6, ¿cuánto cuestan 5 manzanas?','$10','$12','$15','$18','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Razones y proporciones','dificil','La razón de niños a niñas en un salón es 3:2. Si hay 15 niños, ¿cuántas niñas hay?','8','10','12','20','B',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Razones y proporciones','dificil','Un mapa tiene escala 1:1000. Si una distancia en el mapa es 5 cm, ¿cuántos cm es en la realidad?','500','1000','5000','10000','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Área de figuras','medio','¿Cuál es el área de un triángulo con base 8 cm y altura 5 cm?','13 cm²','20 cm²','40 cm²','26 cm²','B',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Área de figuras','dificil','¿Cuál es el área de un círculo de radio 3 cm (usa π≈3.14)?','9.42 cm²','18.84 cm²','28.26 cm²','6.28 cm²','C',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Área de figuras','medio','Un jardín rectangular mide 10 m × 6 m. ¿Cuál es su área?','16 m²','32 m²','60 m²','36 m²','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Comprensión lectora','medio','Según el texto, ¿qué beneficio tiene el reciclaje?','Aumenta la basura','Elimina el plástico','Reduce la basura en los vertederos','Crea más vertederos','C','El reciclaje','El reciclaje permite reutilizar materiales como el papel, el plástico y el vidrio, reduciendo así la cantidad de basura que llega a los vertederos.','banco_1a11_original'),
(6,'espanol','Comprensión lectora','medio','¿Qué materiales se mencionan como reciclables?','papel, metal y madera','papel, plástico y vidrio','plástico, madera y tela','vidrio, metal y tela','B','El reciclaje','El reciclaje permite reutilizar materiales como el papel, el plástico y el vidrio, reduciendo así la cantidad de basura que llega a los vertederos.','banco_1a11_original'),
(6,'espanol','Propósito del texto','medio','¿Cuál es el propósito principal del texto?','Narrar una historia','Informar sobre el reciclaje','Convencer de comprar plástico','Describir un vertedero','B','El reciclaje','El reciclaje permite reutilizar materiales como el papel, el plástico y el vidrio, reduciendo así la cantidad de basura que llega a los vertederos.','banco_1a11_original'),
(6,'espanol','Propósito del texto','facil','Un texto que busca convencer al lector de algo tiene propósito:','narrativo','descriptivo','argumentativo','informativo','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Propósito del texto','facil','Un texto que relata una historia con personajes y sucesos tiene propósito:','narrativo','argumentativo','expositivo','instructivo','A',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Propósito del texto','facil','Un manual de instrucciones tiene propósito:','narrativo','poético','instructivo','argumentativo','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Antónimos','medio','¿Cuál palabra es antónimo de "reducir"?','disminuir','reciclar','aumentar','eliminar','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Antónimos','medio','¿Cuál es el antónimo de "generoso"?','amable','tacaño','amigable','humilde','B',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Antónimos','medio','¿Cuál es el antónimo de "permitir"?','autorizar','prohibir','aceptar','dejar','B',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Clases de palabras','dificil','¿Cuál palabra es un adverbio en "Ella corre rápidamente"?','ella','corre','rápidamente','ninguna','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Clases de palabras','medio','¿Cuál palabra es una preposición?','con','correr','azul','feliz','A',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Clases de palabras','facil','¿Cuál palabra es un pronombre?','casa','ella','rápido','y','B',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Acentuación','medio','¿Cuál palabra es aguda?','árbol','camión','mesa','lápiz','B',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Acentuación','dificil','¿Cuál palabra es esdrújula?','camino','pájaro','reloj','feliz','B',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Acentuación','medio','¿Cuál palabra es grave (llana)?','canción','mesa','café','sofá','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preguntas','medio','Choose the correct question: ____ is your favorite subject?','Who','What','When','Where','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preguntas','medio','___ do you go to school?','What','How','Who','Whose','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preguntas','facil','___ is the capital of France?','What','Who','When','Why','A',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Verbos','medio','My brother ___ to school every day.','walk','walking','walks','walked','C',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Verbos','medio','We ___ a documentary last Friday.','watch','watches','watched','watching','C',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Verbos','medio','She usually ___ breakfast at 7 am.','have','has','having','had','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Adjetivos','facil','The movie was really ___.','boring','bore','bored','bores','A',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Adjetivos','medio','I am ___ about the trip.','excite','excited','exciting','excites','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Adjetivos','facil','The weather is ___ today.','sun','sunny','sunning','suns','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Pronombres','medio','___ is my best friend.','Her','She','Hers','Herself','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Pronombres','dificil','This book belongs to ___.','I','me','my','mine','D',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Pronombres','medio','___ gave us the homework.','He','Him','His','Himself','A',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preposiciones de tiempo','medio','The movie starts ___ 8 pm.','on','in','at','by','C',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preposiciones de tiempo','medio','We will meet ___ Monday.','on','in','at','by','A',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preposiciones de tiempo','medio','School starts ___ September.','on','in','at','by','B',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Analogías','medio','Mano es a guante como pie es a:','zapato','brazo','cabeza','dedo','A',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Analogías','medio','Autor es a libro como compositor es a:','pintura','canción','escultura','película','B',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Analogías','dificil','Termómetro es a calor como barómetro es a:','presión','luz','sonido','peso','A',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Secuencias','facil','¿Qué figura sigue en la secuencia: cuadrado, círculo, cuadrado, círculo, __?','triángulo','círculo','cuadrado','rectángulo','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Secuencias','medio','¿Qué número sigue: 7, 14, 21, 28, __?','30','32','35','42','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Secuencias','dificil','¿Qué número falta: 100, 81, 64, __, 36? (cuadrados)','49','50','54','45','A',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Silogismos','medio','Todos los mamíferos respiran aire. La ballena es un mamífero. Por lo tanto, la ballena:','respira aire','no respira aire','respira agua','no respira','A',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Silogismos','medio','Ningún triángulo tiene 4 lados. Esta figura tiene 4 lados. ¿Es un triángulo?','sí','no','a veces','no se puede saber','B',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Silogismos','medio','Todos los peces tienen branquias. Este animal no tiene branquias. ¿Es un pez?','sí','no','a veces','no se puede saber','B',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Clasificación','medio','¿Cuál de estos NO es un número primo?','7','11','15','13','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Clasificación','medio','¿Cuál de estos NO es un instrumento de cuerda?','guitarra','violín','tambor','arpa','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Clasificación','dificil','¿Cuál de estos es un poliedro?','esfera','cilindro','cubo','cono','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Razonamiento lógico','medio','Si todos los que estudian aprueban, y Carlos no aprobó, entonces Carlos:','estudió','no estudió','no se puede saber','aprobó','B',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Razonamiento lógico','medio','Si hoy es miércoles, ¿qué día será dentro de 3 días?','jueves','viernes','sábado','domingo','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Razonamiento lógico','facil','Ana es mayor que Beto. Beto es mayor que Carlos. ¿Quién es el mayor de los tres?','Ana','Beto','Carlos','no se puede saber','A',NULL,NULL,'banco_1a11_original'),
-- ── 7° grado ──────────────────────────────────────────────────────────
(7,'matematicas','Enteros','medio','−8 + 5 = ?','−13','3','−3','13','C',NULL,NULL,'banco_1a11_original'),
(7,'matematicas','Razones y proporciones','medio','Si 3 lápices cuestan $12, ¿cuánto cuestan 5 lápices al mismo precio por unidad?','$15','$24','$18','$20','D',NULL,NULL,'banco_1a11_original'),
(7,'matematicas','Álgebra básica','medio','Simplifica: 4x + 3x =','7','12x','x7','7x','D',NULL,NULL,'banco_1a11_original'),
(7,'matematicas','Porcentajes','medio','¿Cuál es el 25% de 200?','25','75','50','100','C',NULL,NULL,'banco_1a11_original'),
(7,'espanol','Prefijos','medio','¿Cuál es el prefijo en la palabra "desorden"?','des-','orden','-en','or-','A',NULL,NULL,'banco_1a11_original'),
(7,'espanol','Puntuación','dificil','¿Cuál opción usa correctamente los dos puntos?','Necesito: lápiz, goma y regla','Necesito lápiz, goma y regla:','Necesito, lápiz: goma y regla','Necesito lo siguiente: lápiz, goma y regla','D',NULL,NULL,'banco_1a11_original'),
(7,'espanol','Idea principal','dificil','¿Cuál es la idea principal?','El cambio climático solo afecta las costas','El nivel del mar está bajando','Las comunidades costeras no corren riesgo','El cambio climático afecta más severamente a las zonas costeras','D','El cambio climático','Aunque el cambio climático afecta a todo el planeta, sus consecuencias son más severas en las zonas costeras, donde el aumento del nivel del mar amenaza comunidades enteras.','banco_1a11_original'),
(7,'ingles','Presente perfecto','medio','She ___ finished her homework already.','have','having','has','had having','C',NULL,NULL,'banco_1a11_original'),
(7,'ingles','Sinónimos','facil','Which word is a synonym for "happy"?','sad','angry','tired','joyful','D',NULL,NULL,'banco_1a11_original'),
(7,'habilidad','Silogismos','medio','Todos los músicos saben leer partituras. Juan es músico. Por lo tanto:','Juan sabe leer partituras','Juan no sabe leer partituras','Juan es cantante','No se puede saber','A',NULL,NULL,'banco_1a11_original'),
-- ── 8° grado ──────────────────────────────────────────────────────────
(8,'matematicas','Ecuaciones','medio','Resuelve: 2x − 5 = 11','3','16','8','6','C',NULL,NULL,'banco_1a11_original'),
(8,'matematicas','Volumen','medio','El volumen de un cubo de arista 3 cm es:','9 cm³','36 cm³','18 cm³','27 cm³','D',NULL,NULL,'banco_1a11_original'),
(8,'matematicas','Porcentajes','dificil','Un artículo de $400 tiene un descuento del 15%. ¿Cuál es el precio final?','$360','$340','$385','$380','B',NULL,NULL,'banco_1a11_original'),
(8,'espanol','Propósito del texto','dificil','¿Cuál es el propósito del texto?','Narrar una anécdota','Describir un hospital','Argumentar a favor de dormir lo suficiente','Entretener al lector','C','Dormir bien','Muchos especialistas sostienen que dormir menos de siete horas por noche afecta la memoria y la concentración, por lo que recomiendan priorizar el descanso incluso en épocas de exámenes.','banco_1a11_original'),
(8,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "priorizar"?','ignorar','posponer','eliminar','anteponer','D',NULL,NULL,'banco_1a11_original'),
(8,'espanol','Voz pasiva','dificil','¿Cuál oración está en voz pasiva?','El estudiante escribió el ensayo','El estudiante escribe','Escribir es difícil','El ensayo fue escrito por el estudiante','D',NULL,NULL,'banco_1a11_original'),
(8,'ingles','Comparativos','medio','This book is ___ than that one.','interesting','most interesting','interestinger','more interesting','D',NULL,NULL,'banco_1a11_original'),
(8,'ingles','Pasado','medio','Choose the correct sentence.','They was at the park','They is at the park','They were at the park','They be at the park','C',NULL,NULL,'banco_1a11_original'),
(8,'habilidad','Silogismos','dificil','Si ningún reptil tiene plumas, y la serpiente es un reptil, entonces:','la serpiente tiene plumas','la serpiente es un ave','la serpiente no tiene plumas','no se puede saber','C',NULL,NULL,'banco_1a11_original'),
(8,'habilidad','Clasificación','facil','¿Cuál palabra no pertenece al grupo?','manzana','zanahoria','pera','uva','B',NULL,NULL,'banco_1a11_original'),
-- ── 9° grado ──────────────────────────────────────────────────────────
(9,'matematicas','Inecuaciones','dificil','¿Cuál es la solución de 3x + 2 > 11?','x>2','x<3','x>3','x<2','C',NULL,NULL,'banco_1a11_original'),
(9,'matematicas','Factorización','dificil','Factoriza: x² − 9','(x-3)(x-3)','(x+9)(x-1)','(x-9)(x+1)','(x+3)(x-3)','D',NULL,NULL,'banco_1a11_original'),
(9,'matematicas','Probabilidad','medio','Al lanzar un dado, ¿cuál es la probabilidad de obtener un número mayor que 4?','1/6','1/2','1/3','2/3','C',NULL,NULL,'banco_1a11_original'),
(9,'espanol','Inferencia','dificil','Según el texto, ¿qué se espera que siga siendo exclusivamente humano?','La automatización','Las tareas repetitivas','La inteligencia artificial','La creatividad y el juicio ético','D','La inteligencia artificial','Si bien la inteligencia artificial puede automatizar tareas repetitivas, numerosos especialistas insisten en que la creatividad y el juicio ético seguirán siendo habilidades exclusivamente humanas en el futuro cercano.','banco_1a11_original'),
(9,'espanol','Tono','dificil','¿Cuál es el tono del texto?','Humorístico','Analítico','Irónico','Nostálgico','B','La inteligencia artificial','Si bien la inteligencia artificial puede automatizar tareas repetitivas, numerosos especialistas insisten en que la creatividad y el juicio ético seguirán siendo habilidades exclusivamente humanas en el futuro cercano.','banco_1a11_original'),
(9,'espanol','Connotación','dificil','¿Cuál palabra tiene una connotación negativa en este contexto: "tareas repetitivas"?','tareas','repetitivas','especialistas','futuro','B','La inteligencia artificial','Si bien la inteligencia artificial puede automatizar tareas repetitivas, numerosos especialistas insisten en que la creatividad y el juicio ético seguirán siendo habilidades exclusivamente humanas en el futuro cercano.','banco_1a11_original'),
(9,'ingles','Condicionales','dificil','If it rains tomorrow, we ___ the picnic.','cancel','canceled','canceling','will cancel','D',NULL,NULL,'banco_1a11_original'),
(9,'ingles','Vocabulario','medio','Choose the word closest in meaning to "essential".','optional','unlikely','necessary','temporary','C',NULL,NULL,'banco_1a11_original'),
(9,'habilidad','Silogismos','dificil','Todos los poetas son sensibles. Algunos sensibles son tímidos. Por lo tanto:','todos los poetas son tímidos','ningún poeta es tímido','algunos poetas podrían ser tímidos','todos los tímidos son poetas','C',NULL,NULL,'banco_1a11_original'),
(9,'habilidad','Secuencias','medio','¿Cuál es el siguiente número: 1, 1, 2, 3, 5, 8, __?','10','11','12','13','D',NULL,NULL,'banco_1a11_original'),
-- ── 10° grado ─────────────────────────────────────────────────────────
(10,'matematicas','Sistemas de ecuaciones','dificil','Resuelve el sistema: x + y = 10, x − y = 2. ¿Cuál es el valor de x?','4','5','8','6','D',NULL,NULL,'banco_1a11_original'),
(10,'matematicas','Círculos','dificil','El área de un círculo de radio 4 cm es (usa π≈3.14):','12.56 cm²','100.48 cm²','50.24 cm²','25.12 cm²','C',NULL,NULL,'banco_1a11_original'),
(10,'matematicas','Funciones','medio','Si f(x) = 2x − 3, ¿cuánto es f(5)?','5','10','13','7','D',NULL,NULL,'banco_1a11_original'),
(10,'espanol','Inferencia','dificil','Según el texto, ¿por qué dos testigos pueden recordar un evento de forma distinta?','Porque mienten','Porque no estuvieron presentes','Porque la memoria reconstruye los recuerdos cada vez','Porque la memoria es una grabadora exacta','C','La memoria humana','La memoria humana no funciona como una grabadora que registra los hechos con exactitud; más bien, reconstruye los recuerdos cada vez que los evocamos, lo cual explica por qué dos testigos de un mismo evento pueden recordarlo de manera distinta.','banco_1a11_original'),
(10,'espanol','Vocabulario en contexto','dificil','La palabra "evocamos" significa MÁS CERCANAMENTE:','olvidamos','inventamos','grabamos','recordamos','D','La memoria humana','La memoria humana no funciona como una grabadora que registra los hechos con exactitud; más bien, reconstruye los recuerdos cada vez que los evocamos, lo cual explica por qué dos testigos de un mismo evento pueden recordarlo de manera distinta.','banco_1a11_original'),
(10,'espanol','Idea principal','dificil','¿Cuál opción resume MEJOR el texto?','Los testigos siempre mienten','La memoria es como una grabadora','Los recuerdos nunca cambian','La memoria reconstruye, no graba, los recuerdos','D','La memoria humana','La memoria humana no funciona como una grabadora que registra los hechos con exactitud; más bien, reconstruye los recuerdos cada vez que los evocamos, lo cual explica por qué dos testigos de un mismo evento pueden recordarlo de manera distinta.','banco_1a11_original'),
(10,'ingles','Voz pasiva','dificil','The bridge ___ by engineers last year.','built','builds','building','was built','D',NULL,NULL,'banco_1a11_original'),
(10,'ingles','Cláusulas relativas','medio','Choose the sentence with a relative clause.','The car is red','I bought a car','The car that I bought is red','Red is the car','C',NULL,NULL,'banco_1a11_original'),
(10,'habilidad','Lógica','dificil','En un grupo, todos los que tocan guitarra también cantan, y algunos que cantan también bailan. ¿Qué se puede concluir?','todos los que tocan guitarra bailan','nadie que toca guitarra baila','algunos que tocan guitarra podrían bailar','todos los que bailan tocan guitarra','C',NULL,NULL,'banco_1a11_original'),
(10,'habilidad','Secuencias','medio','¿Cuál es el siguiente término: 3, 6, 12, 24, __?','30','60','36','48','D',NULL,NULL,'banco_1a11_original'),
-- ── 11° grado ─────────────────────────────────────────────────────────
(11,'matematicas','Logaritmos','dificil','Si log₂(x) = 5, ¿cuál es el valor de x?','10','25','16','32','D',NULL,NULL,'banco_1a11_original'),
(11,'matematicas','Pendiente','dificil','¿Cuál es la pendiente de la recta que pasa por los puntos (1,2) y (3,8)?','2','4','3','6','C',NULL,NULL,'banco_1a11_original'),
(11,'matematicas','Perímetro','medio','El perímetro de un triángulo equilátero es 36 cm. ¿Cuánto mide cada lado?','9 cm','18 cm','6 cm','12 cm','D',NULL,NULL,'banco_1a11_original'),
(11,'espanol','Inferencia','dificil','Según el texto, ¿qué sostiene el estoicismo sobre la felicidad?','Depende únicamente de las circunstancias externas','Es imposible de alcanzar','Depende de la suerte','Es una elección cultivada internamente','D','La felicidad según el estoicismo','Durante siglos, los filósofos han discutido si la felicidad depende de circunstancias externas o de una disposición interna cultivada a través de hábitos y reflexión. Esta última postura, defendida por corrientes como el estoicismo, sostiene que el bienestar es, ante todo, una elección.','banco_1a11_original'),
(11,'espanol','Vocabulario en contexto','dificil','La palabra "disposición" en el texto significa MÁS CERCANAMENTE:','orden','ubicación','decoración','actitud','D','La felicidad según el estoicismo','Durante siglos, los filósofos han discutido si la felicidad depende de circunstancias externas o de una disposición interna cultivada a través de hábitos y reflexión. Esta última postura, defendida por corrientes como el estoicismo, sostiene que el bienestar es, ante todo, una elección.','banco_1a11_original'),
(11,'espanol','Propósito del texto','dificil','¿Cuál es el propósito principal del texto?','Narrar la vida de un filósofo','Describir un evento histórico','Contrastar dos posturas sobre el origen de la felicidad','Convencer al lector de ser estoico','C','La felicidad según el estoicismo','Durante siglos, los filósofos han discutido si la felicidad depende de circunstancias externas o de una disposición interna cultivada a través de hábitos y reflexión. Esta última postura, defendida por corrientes como el estoicismo, sostiene que el bienestar es, ante todo, una elección.','banco_1a11_original'),
(11,'ingles','Pasado perfecto','dificil','By the time we arrived, the movie ___ already started.','has','have','having','had','D',NULL,NULL,'banco_1a11_original'),
(11,'ingles','Antónimos','dificil','Choose the word that is MOST OPPOSITE in meaning to "reluctant".','hesitant','uncertain','tired','eager','D',NULL,NULL,'banco_1a11_original'),
(11,'habilidad','Silogismos','dificil','Ninguna persona meticulosa es descuidada. Algunos contadores son meticulosos. Por lo tanto:','ningún contador es descuidado','todos los contadores son descuidados','todos los descuidados son contadores','algunos contadores no son descuidados','D',NULL,NULL,'banco_1a11_original'),
(11,'habilidad','Analogías','medio','Microscopio es a diminuto como telescopio es a:','cercano','pequeño','oscuro','lejano','D',NULL,NULL,'banco_1a11_original');
