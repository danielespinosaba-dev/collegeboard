// Script de un solo uso. Correr localmente:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/migrate-to-supabase-auth.js
//
// Requiere que supabase_auth_migration.sql ya se haya corrido (columna user_id
// debe existir). Es idempotente: las filas que ya tengan user_id se saltan,
// así que se puede volver a correr si se interrumpe o si hay que resolver un
// correo duplicado a mano y reintentar.
import { createClient } from '@supabase/supabase-js';
import crypto from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const APP_URL = process.env.APP_URL || 'https://collegeboard-nine.vercel.app';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('Faltan SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY en el entorno.');
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

function decodeBtoaPassword(passwordHash) {
  return Buffer.from(passwordHash, 'base64').toString('utf-8');
}

function randomPassword() {
  return crypto.randomBytes(18).toString('base64url');
}

async function migrateStudents() {
  const { data: students, error } = await admin
    .from('students')
    .select('id, email, password_hash')
    .is('user_id', null);
  if (error) throw error;

  console.log(`Alumnos a migrar: ${students.length}`);
  for (const student of students) {
    const password = decodeBtoaPassword(student.password_hash);
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: student.email,
      password,
      email_confirm: true,
      app_metadata: { app_role: 'student' }
    });
    if (createError) {
      console.error(`[alumno ${student.email}] no se pudo crear en Auth:`, createError.message);
      continue;
    }
    const { error: updateError } = await admin
      .from('students')
      .update({ user_id: created.user.id })
      .eq('id', student.id);
    if (updateError) {
      console.error(`[alumno ${student.email}] creado en Auth pero no se pudo enlazar:`, updateError.message);
      continue;
    }
    console.log(`[alumno ${student.email}] migrado OK`);
  }
}

async function migrateTeachers() {
  const { data: teachers, error } = await admin
    .from('teachers')
    .select('id, email')
    .is('user_id', null);
  if (error) throw error;

  console.log(`Docentes a migrar: ${teachers.length}`);
  for (const teacher of teachers) {
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: teacher.email,
      password: randomPassword(),
      email_confirm: true,
      app_metadata: { app_role: 'teacher' }
    });
    if (createError) {
      console.error(`[docente ${teacher.email}] no se pudo crear en Auth:`, createError.message);
      continue;
    }
    const { error: updateError } = await admin
      .from('teachers')
      .update({ user_id: created.user.id })
      .eq('id', teacher.id);
    if (updateError) {
      console.error(`[docente ${teacher.email}] creado en Auth pero no se pudo enlazar:`, updateError.message);
      continue;
    }
    const { error: resetError } = await admin.auth.resetPasswordForEmail(teacher.email, {
      redirectTo: `${APP_URL}/reset-password.html`
    });
    if (resetError) {
      console.error(`[docente ${teacher.email}] migrado pero falló el correo de reset:`, resetError.message);
      continue;
    }
    console.log(`[docente ${teacher.email}] migrado OK, correo de reset enviado`);
  }
}

async function main() {
  await migrateStudents();
  await migrateTeachers();
  console.log('Migración terminada.');
}

main().catch((err) => {
  console.error('Error fatal en la migración:', err);
  process.exit(1);
});
