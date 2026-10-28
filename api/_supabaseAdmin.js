import { createClient } from '@supabase/supabase-js';
import CONFIG from '../config.js';

// Cliente con la service_role key: solo se usa server-side (funciones de /api),
// nunca debe llegar al navegador. Bypassea RLS, así que las verificaciones de
// autorización que necesitemos las hacemos a mano en cada endpoint.
export function getAdminClient() {
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY no está configurada');
  }
  return createClient(CONFIG.SUPABASE_URL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
}

// Confirma que un access token de Supabase Auth es válido y devuelve el usuario.
// Se usa en los endpoints que reciben el token del cliente y necesitan saber
// con certeza quién está llamando antes de tocar datos con la service_role key.
export async function verifyAccessToken(adminClient, accessToken) {
  if (!accessToken) return null;
  const { data, error } = await adminClient.auth.getUser(accessToken);
  if (error || !data?.user) return null;
  return data.user;
}

export function setCors(res) {
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}
