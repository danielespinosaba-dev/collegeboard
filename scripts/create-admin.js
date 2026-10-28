// Crea una cuenta de admin (no hay registro propio en admin.html).
// Uso:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/create-admin.js "Nombre Apellido" correo@ejemplo.com "contraseña"
import { createClient } from '@supabase/supabase-js';

const [, , nombre, email, password] = process.argv;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!nombre || !email || !password) {
  console.error('Uso: node scripts/create-admin.js "Nombre Apellido" correo@ejemplo.com "contraseña"');
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
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, app_metadata: { app_role: 'admin' }
  });
  if (createError) throw createError;

  const { error: insertError } = await admin.from('admins').insert({
    nombre, email, user_id: created.user.id
  });
  if (insertError) throw insertError;

  console.log(`Admin creado: ${email}`);
}

main().catch((err) => {
  console.error('Error creando admin:', err);
  process.exit(1);
});
