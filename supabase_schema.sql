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
INSERT INTO public.shop_items (slug, nombre, costo_puntos, disponible) VALUES
('mexico', 'México (Básica)', 0, true),
('oro', 'Playera de Oro', 100, true),
('diamante', 'Diamante Cósmico', 500, true)
ON CONFLICT (slug) DO NOTHING;

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
(1,'matematicas','Suma y resta','facil','3 + 2 = ?','4','5','6','7','B',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Suma y resta','facil','Si Ana tiene 4 globos y le regalan 3 más, ¿cuántos globos tiene en total?','5','6','7','8','C',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Conteo','facil','¿Qué número va después del 7?','6','9','8','5','C',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Suma y resta','facil','9 − 4 = ?','6','3','4','5','D',NULL,NULL,'banco_1a11_original'),
(1,'matematicas','Comparación de números','facil','¿Cuál de estos números es el mayor: 6, 9, 3, 7?','9','6','7','3','A',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Rimas','facil','¿Cuál palabra rima con "gato"?','perro','pato','casa','sol','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Letras','facil','¿Cuál es la primera letra de la palabra "luna"?','N','L','U','A','B',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Vocabulario','facil','¿Qué palabra nombra a un animal?','mesa','silla','perro','libro','C',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Sílabas','facil','¿Cuántas sílabas tiene la palabra "pelota"?','4','1','3','2','C',NULL,NULL,'banco_1a11_original'),
(1,'espanol','Gramática','facil','Completa: El sol _____ por las mañanas.','salgo','salen','sale','salir','C',NULL,NULL,'banco_1a11_original'),
-- ── 2° grado ──────────────────────────────────────────────────────────
(2,'matematicas','Suma y resta','facil','45 + 23 = ?','58','78','68','88','C',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Suma y resta','medio','Pedro tenía 50 pesos y gastó 20. ¿Cuánto le queda?','40','20','70','30','D',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Valor posicional','medio','¿Cuál es la decena más cercana a 38?','35','40','45','30','B',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Multiplicación básica','medio','Si una docena tiene 12 huevos, ¿cuántos huevos hay en 2 docenas?','20','22','26','24','D',NULL,NULL,'banco_1a11_original'),
(2,'matematicas','Suma y resta','medio','90 − 35 = ?','65','45','55','50','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Comprensión lectora','facil','¿Con quién fue Marta al parque?','su mamá','su amiga','su hermano','su perro','D','Marta y Toby','Marta fue al parque con su perro Toby. Jugaron con una pelota roja hasta que oscureció.','banco_1a11_original'),
(2,'espanol','Comprensión lectora','facil','¿De qué color era la pelota?','azul','roja','verde','amarilla','B','Marta y Toby','Marta fue al parque con su perro Toby. Jugaron con una pelota roja hasta que oscureció.','banco_1a11_original'),
(2,'espanol','Plural','facil','¿Cuál es el plural de "flor"?','flors','floras','flores','florrs','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Sinónimos','medio','¿Cuál palabra significa lo mismo que "contento"?','triste','cansado','feliz','enojado','C',NULL,NULL,'banco_1a11_original'),
(2,'espanol','Gramática','medio','¿Cuál oración está escrita correctamente?','los niños Juega en el parque','Los niños juegan en el parque','los Niños juegan en el Parque','Los niños Juegan En El parque','B',NULL,NULL,'banco_1a11_original'),
-- ── 3° grado ──────────────────────────────────────────────────────────
(3,'matematicas','Multiplicación','medio','6 × 4 = ?','20','22','26','24','D',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Fracciones','medio','¿Qué fracción representa "la mitad"?','1/3','1/4','1/2','2/3','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','División','medio','24 ÷ 6 = ?','3','6','4','5','C',NULL,NULL,'banco_1a11_original'),
(3,'matematicas','Geometría básica','facil','Un triángulo tiene ____ lados.','4','2','5','3','D',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Comprensión lectora','medio','¿Para qué usa su lengua el oso hormiguero?','para nadar','para atrapar hormigas','para trepar árboles','para dormir','B','El oso hormiguero','El oso hormiguero tiene una lengua muy larga y pegajosa que usa para atrapar hormigas dentro de los hormigueros.','banco_1a11_original'),
(3,'espanol','Antónimos','medio','¿Cuál es el antónimo de "largo"?','ancho','grueso','corto','alto','C',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Plural','facil','¿Cuál palabra está en plural?','mesa','libros','silla','pared','B',NULL,NULL,'banco_1a11_original'),
(3,'espanol','Ortografía','medio','Elige la opción con ortografía correcta.','ablar','havlar','hablar','ablarr','C',NULL,NULL,'banco_1a11_original'),
(3,'ingles','Vocabulario','facil','What is the English word for "perro"?','cat','bird','dog','fish','C',NULL,NULL,'banco_1a11_original'),
(3,'habilidad','Secuencias','medio','¿Qué número sigue en la secuencia 2, 4, 6, 8, __?','9','12','14','10','D',NULL,NULL,'banco_1a11_original'),
-- ── 4° grado ──────────────────────────────────────────────────────────
(4,'matematicas','Fracciones','medio','1/4 + 2/4 = ?','1/4','4/4','3/4','2/4','C',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Perímetro','medio','El perímetro de un cuadrado de lado 5 cm es:','15 cm','10 cm','25 cm','20 cm','D',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Multiplicación','medio','7 × 8 = ?','54','64','58','56','D',NULL,NULL,'banco_1a11_original'),
(4,'matematicas','Área','medio','¿Cuál es el área de un rectángulo de 4 cm de largo por 3 cm de ancho?','14 cm²','7 cm²','12 cm²','10 cm²','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Idea principal','medio','¿Cuál es la idea principal del texto?','Las flores producen néctar','Las abejas recolectan néctar y ayudan a las plantas','Las plantas se reproducen solas','Las abejas viven en colmenas','B','Las abejas','Las abejas recolectan el néctar de las flores y lo transforman en miel dentro de la colmena. Gracias a su trabajo, muchas plantas pueden reproducirse.','banco_1a11_original'),
(4,'espanol','Sinónimos','medio','¿Cuál palabra es sinónimo de "recolectar"?','tirar','perder','juntar','esconder','C',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Tiempos verbales','medio','En la oración "Las abejas volaron toda la tarde", el verbo está en tiempo:','futuro','presente','ninguno','pasado','D',NULL,NULL,'banco_1a11_original'),
(4,'espanol','Ortografía','medio','¿Cuál de las siguientes palabras está escrita correctamente?','arbol','arvol','árbol','hárbol','C',NULL,NULL,'banco_1a11_original'),
(4,'ingles','Gramática','medio','Choose the correct sentence.','She have a red bike','She haves a red bike','She having a red bike','She has a red bike','D',NULL,NULL,'banco_1a11_original'),
(4,'habilidad','Analogías','medio','Libro es a leer como tenedor es a:','cortar','comer','cocinar','lavar','B',NULL,NULL,'banco_1a11_original'),
-- ── 5° grado ──────────────────────────────────────────────────────────
(5,'matematicas','Porcentajes','medio','El 50% de 80 es:','20','30','40','50','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Decimales','medio','0.5 + 0.25 = ?','0.65','0.80','0.75','0.70','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Razonamiento proporcional','medio','Un autobús recorre 60 km en 1 hora. ¿Cuántos km recorrerá en 3 horas a la misma velocidad?','120','200','180','150','C',NULL,NULL,'banco_1a11_original'),
(5,'matematicas','Divisores','dificil','¿Cuál es el máximo común divisor de 12 y 18?','2','9','3','6','D',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Inferencia','medio','¿Qué se puede inferir de la lectura?','Mariana vive sola','Alguien pudo haber entrado a la casa','La casa estaba en reparación','Mariana olvidó apagar las luces','B','La puerta abierta','Cuando Mariana llegó a casa, encontró la puerta abierta y las luces encendidas, aunque recordaba haberlas apagado antes de salir.','banco_1a11_original'),
(5,'espanol','Sinónimos','medio','¿Cuál palabra podría sustituir a "encontró" sin cambiar el sentido?','perdió','compró','halló','rompió','C',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Sujeto','medio','Identifica el sujeto de la oración: "Los estudiantes terminaron el examen temprano".','terminaron','el examen','temprano','los estudiantes','D',NULL,NULL,'banco_1a11_original'),
(5,'espanol','Puntuación','medio','¿Cuál oración usa correctamente la coma?','Compré, manzanas peras y uvas','Compré manzanas peras, y uvas','Compré manzanas, peras y uvas','Compré, manzanas, peras, y, uvas','C',NULL,NULL,'banco_1a11_original'),
(5,'ingles','Antónimos','medio','What is the opposite of "big"?','tall','wide','heavy','small','D',NULL,NULL,'banco_1a11_original'),
(5,'habilidad','Lógica','medio','Si todos los círculos son azules y esta figura es un círculo, entonces esta figura es:','roja','verde','azul','no se puede saber','C',NULL,NULL,'banco_1a11_original'),
-- ── 6° grado ──────────────────────────────────────────────────────────
(6,'matematicas','Operaciones combinadas','medio','¿Cuál es el resultado de (3 + 5) × 2?','11','18','13','16','D',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ecuaciones simples','medio','Si x + 7 = 15, ¿cuál es el valor de x?','6','9','7','8','D',NULL,NULL,'banco_1a11_original'),
(6,'matematicas','Ángulos','medio','¿Cuántos grados mide un ángulo recto?','45','180','90','360','C',NULL,NULL,'banco_1a11_original'),
(6,'espanol','Comprensión lectora','medio','Según el texto, ¿qué beneficio tiene el reciclaje?','Aumenta la basura','Elimina el plástico','Reduce la basura en los vertederos','Crea más vertederos','C','El reciclaje','El reciclaje permite reutilizar materiales como el papel, el plástico y el vidrio, reduciendo así la cantidad de basura que llega a los vertederos.','banco_1a11_original'),
(6,'espanol','Propósito del texto','medio','¿Cuál es el propósito principal del texto?','Narrar una historia','Informar sobre el reciclaje','Convencer de comprar plástico','Describir un vertedero','B','El reciclaje','El reciclaje permite reutilizar materiales como el papel, el plástico y el vidrio, reduciendo así la cantidad de basura que llega a los vertederos.','banco_1a11_original'),
(6,'espanol','Antónimos','medio','¿Cuál palabra es antónimo de "reducir"?','disminuir','reciclar','aumentar','eliminar','C',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Preguntas','medio','Choose the correct question: ____ is your favorite subject?','Who','What','When','Where','B',NULL,NULL,'banco_1a11_original'),
(6,'ingles','Verbos','medio','My brother ___ to school every day.','walk','walking','walks','walked','C',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Analogías','medio','Mano es a guante como pie es a:','zapato','brazo','cabeza','dedo','A',NULL,NULL,'banco_1a11_original'),
(6,'habilidad','Secuencias','facil','¿Qué figura sigue en la secuencia: cuadrado, círculo, cuadrado, círculo, __?','triángulo','círculo','cuadrado','rectángulo','C',NULL,NULL,'banco_1a11_original'),
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
