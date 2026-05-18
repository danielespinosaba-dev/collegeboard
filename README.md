# PIENSE Mini-Exámenes · Guía de despliegue

Plataforma de mini-exámenes cronometrados para 6to grado, alineada al PIENSE I.

---

## Archivos del proyecto

```
piense-app/
├── index.html          ← Vista docente (login, grupos, banco, dashboard)
├── alumno.html         ← Vista alumno (entrada con código, examen, resultados)
├── supabase_schema.sql ← Schema de base de datos + banco de reactivos
└── netlify.toml        ← Configuración de despliegue
```

---

## PASO 1: Configurar Supabase

1. Ve a [supabase.com](https://supabase.com) → crea un proyecto nuevo
2. En el panel izquierdo: **SQL Editor** → clic en **New query**
3. Pega todo el contenido de `supabase_schema.sql` y ejecuta (clic en **Run**)
4. Esto crea todas las tablas y carga el banco de reactivos automáticamente (~60 preguntas)
5. Ve a **Project Settings → API** y copia:
   - **Project URL** (ej: `https://xxxxx.supabase.co`)
   - **anon public key** (clave larga que empieza con `eyJ...`)

### Agregar columna de contraseña a teachers
En el SQL Editor, ejecuta también:
```sql
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS password_hash text;
```

---

## PASO 2: Pegar credenciales en el código

Abre `index.html` y `alumno.html`. Busca estas dos líneas en cada archivo:

```javascript
const SUPABASE_URL = 'TU_SUPABASE_URL';
const SUPABASE_KEY = 'TU_SUPABASE_ANON_KEY';
```

Reemplaza con tus valores reales:

```javascript
const SUPABASE_URL = 'https://tuproyecto.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

---

## PASO 3: Desplegar en Netlify

### Opción A — Drag & Drop (más rápido)
1. Ve a [netlify.com](https://netlify.com) → login con GitHub
2. En el panel: **Sites → Add new site → Deploy manually**
3. Arrastra la carpeta `piense-app/` completa al área de deploy
4. ¡Listo! Netlify te da una URL como `https://random-name.netlify.app`

### Opción B — Desde GitHub (recomendado para actualizaciones)
1. Sube la carpeta a un repo en GitHub
2. En Netlify: **Add new site → Import from Git**
3. Conecta el repo → deploy automático

---

## PASO 4: Crear cuentas de docentes

Las cuentas se crean directamente desde la pantalla de login de `index.html`:
- Clic en **"Crear cuenta"**
- Nombre, correo y contraseña (mínimo 6 caracteres)
- Crear una cuenta para cada maestra (Grupo A y Grupo B)

---

## PASO 5: Flujo de uso

### La docente:
1. Entra a `tuapp.netlify.app` → login
2. **Mis grupos** → crea sus grupos (ej. "6A Mañana", "6B Tarde")
3. El sistema genera un **código de grupo** (de 6 letras) — compártelo con los alumnos
4. **Banco de reactivos** → filtra por materia/tema → selecciona hasta 10 preguntas
5. Clic en **"Crear examen con estos reactivos"** → asigna nombre y grupo
6. El sistema genera un **código de examen** (8 letras)
7. Comparte el código con los alumnos → clic en **"Activar examen"**
8. Al terminar: **"Cerrar examen"** → ve resultados en **Resultados**

### El alumno:
1. Entra a `tuapp.netlify.app/alumno.html`
2. Ingresa el **código del examen** (8 letras)
3. Escribe su nombre
4. Espera en la sala de espera (se actualiza automáticamente cada 3 seg)
5. Cuando la maestra activa → comienza el examen (10 min por defecto)
6. Responde y entrega → ve sus resultados y revisión inmediatamente

---

## Banco de reactivos incluido

### Matemáticas (~35 preguntas)
- Fracciones en recta numérica
- Porcentajes
- Plano cartesiano
- Ángulos
- Circunferencia
- Volumen
- Perímetro y área de triángulos
- Conversión de medidas de longitud
- Probabilidad
- Medidas de tendencia central (media, mediana)
- Álgebra básica
- Secuencias numéricas

### Español (~25 preguntas)
- Sinónimos y antónimos
- Diptongos e hiatos
- Clasificación por acento (agudas, graves, esdrújulas)
- Diéresis
- Sentido despectivo
- Sujeto de la oración
- Inferencia lectora
- Pronombres
- Acentuación y ortografía
- Tipos de texto

### Habilidad Cognoscitiva (~15 preguntas)
- Razonamiento lógico
- Analogías
- Secuencias
- Diagramas de Venn
- Orden y clasificación espacial

---

## Agregar más reactivos

En el SQL Editor de Supabase:

```sql
INSERT INTO questions (subject, topic, stem, option_a, option_b, option_c, option_d, correct_answer, difficulty, source)
VALUES (
  'matematicas',           -- 'matematicas', 'espanol', o 'habilidad'
  'Fracciones',            -- tema
  '¿Cuánto es 1/2 + 1/4?', -- pregunta
  '1/6', '3/4', '2/6', '1/3', -- opciones A, B, C, D
  'B',                     -- respuesta correcta
  'medio',                 -- 'facil', 'medio', 'dificil'
  'banco_propio'           -- fuente
);
```

---

## Soporte

Preguntas al canal de la plataforma Aula Invertida · contacto@aulainvertida.lat
