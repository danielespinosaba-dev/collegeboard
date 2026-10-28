import { getAdminClient, verifyAccessToken, setCors } from './_supabaseAdmin.js';

const ALLOWED_TABLES = {
  teachers: ['name', 'email'],
  students: ['nombre', 'email', 'grado', 'group_id', 'puntos_totales', 'playera_activa', 'playeras_desbloqueadas']
};

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { table, accessToken, profile } = req.body || {};
    const allowedFields = ALLOWED_TABLES[table];
    if (!allowedFields || !accessToken || !profile || typeof profile !== 'object') {
      return res.status(400).json({ error: 'Solicitud inválida' });
    }

    const admin = getAdminClient();
    const user = await verifyAccessToken(admin, accessToken);
    if (!user) return res.status(401).json({ error: 'Sesión inválida' });
    if (user.email !== profile.email) {
      return res.status(400).json({ error: 'El correo no coincide con la sesión' });
    }

    // Solo se insertan los campos permitidos para esa tabla: nunca password_hash,
    // nunca user_id distinto al del usuario ya verificado arriba.
    const row = { user_id: user.id };
    for (const field of allowedFields) {
      if (profile[field] !== undefined) row[field] = profile[field];
    }

    const { data, error } = await admin.from(table).insert(row).select().single();
    if (error) {
      if (error.code === '23505') {
        return res.status(409).json({ error: { code: '23505', message: 'Correo ya registrado' } });
      }
      console.error('complete-registration insert error:', error);
      return res.status(500).json({ error: 'No se pudo completar el registro' });
    }

    res.status(200).json({ data });
  } catch (err) {
    console.error('complete-registration error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}
