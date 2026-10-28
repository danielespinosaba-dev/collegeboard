// Envía el correo de "restablece tu contraseña" a los docentes que ya tengan
// user_id. Lleva un registro local (scripts/.reset-sent.json) de a quién ya
// le llegó bien, para NO reenviarle de nuevo en corridas posteriores (varios
// correos duplicados confunden, aunque no sean inseguros).
// Uso: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... APP_URL=... node scripts/send-teacher-resets.js
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LOG_PATH = path.join(__dirname, '.reset-sent.json');

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

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function loadSent() {
  try {
    return new Set(JSON.parse(fs.readFileSync(LOG_PATH, 'utf-8')));
  } catch {
    return new Set();
  }
}

function saveSent(sent) {
  fs.writeFileSync(LOG_PATH, JSON.stringify([...sent], null, 2));
}

async function main() {
  const sent = loadSent();

  const { data: teachers, error } = await admin
    .from('teachers')
    .select('email')
    .not('user_id', 'is', null);
  if (error) throw error;

  const pendientes = teachers.filter((t) => !sent.has(t.email));
  console.log(`Docentes con user_id: ${teachers.length}. Ya confirmados antes: ${sent.size}. Pendientes hoy: ${pendientes.length}.`);

  let fallidos = 0;
  for (const teacher of pendientes) {
    const { error: resetError } = await admin.auth.resetPasswordForEmail(teacher.email, {
      redirectTo: `${APP_URL}/reset-password.html`
    });
    if (resetError) {
      console.error(`[${teacher.email}] falló el envío:`, resetError.message);
      fallidos++;
      await sleep(3000);
      continue;
    }
    console.log(`[${teacher.email}] correo enviado`);
    sent.add(teacher.email);
    saveSent(sent);
    await sleep(1500);
  }
  console.log(`Listo. Fallidos esta corrida: ${fallidos}/${pendientes.length}. Confirmados en total: ${sent.size}/${teachers.length}.`);
}

main().catch((err) => {
  console.error('Error fatal:', err);
  process.exit(1);
});
