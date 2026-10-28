// Da rol de admin a una cuenta que YA existe en Supabase Auth (ej. un
// docente que también va a ser coordinador). Actualiza su app_metadata a
// app_role: 'admin' (esto no le quita su acceso de docente: las políticas
// de docente se basan en teachers.user_id, no en el rol) y crea su fila en
// `admins` enlazada al mismo user_id.
// Uso: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/promote-to-admin.js "Nombre Apellido" correo@existente.com
import { createClient } from '@supabase/supabase-js';

const [, , nombre, email] = process.argv;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!nombre || !email) {
  console.error('Uso: node scripts/promote-to-admin.js "Nombre Apellido" correo@existente.com');
  process.exit(1);
}
if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('Faltan SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY en el entorno.');
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function main() {
  const { data: teacher, error: teacherError } = await admin
    .from('teachers')
    .select('user_id')
    .eq('email', email)
    .single();
  if (teacherError || !teacher?.user_id) {
    throw new Error(`No encontré una cuenta ya migrada con ese correo en teachers: ${teacherError?.message || 'sin user_id'}`);
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(teacher.user_id, {
    app_metadata: { app_role: 'admin' }
  });
  if (updateError) throw updateError;

  const { error: insertError } = await admin.from('admins').insert({
    nombre, email, user_id: teacher.user_id
  });
  if (insertError) throw insertError;

  console.log(`Listo: ${email} ahora también es admin (mismo login de siempre).`);
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});
