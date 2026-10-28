import { getAdminClient, verifyAccessToken, setCors } from './_supabaseAdmin.js';

// Usado por el docente desde su panel para agregar un alumno directamente
// a su grupo (distinto del auto-registro del alumno). Crea la cuenta en
// Supabase Auth y la fila de negocio en un solo paso, con la contraseña
// que el docente eligió para ese alumno.
export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { accessToken, nombre, email, password, grado, groupId } = req.body || {};
    if (!accessToken || !nombre || !email || !password || !grado || !groupId) {
      return res.status(400).json({ error: 'Solicitud inválida' });
    }

    const admin = getAdminClient();
    const user = await verifyAccessToken(admin, accessToken);
    if (!user) return res.status(401).json({ error: 'Sesión inválida' });

    const { data: teacher } = await admin.from('teachers').select('id').eq('user_id', user.id).single();
    if (!teacher) return res.status(403).json({ error: 'Solo un docente puede agregar alumnos' });

    const { data: group } = await admin.from('groups').select('teacher_id').eq('id', groupId).single();
    if (!group || group.teacher_id !== teacher.id) {
      return res.status(403).json({ error: 'Ese grupo no te pertenece' });
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, app_metadata: { app_role: 'student' }
    });
    if (createError) {
      if (createError.message.toLowerCase().includes('already')) {
        return res.status(409).json({ error: { code: '23505', message: 'Ese correo ya está registrado' } });
      }
      console.error('create-student createUser error:', createError);
      return res.status(500).json({ error: 'No se pudo crear la cuenta' });
    }

    const { error: insertError } = await admin.from('students').insert({
      nombre, email, grado, group_id: groupId, puntos_totales: 0, user_id: created.user.id
    });
    if (insertError) {
      if (insertError.code === '23505') {
        return res.status(409).json({ error: { code: '23505', message: 'Ese correo ya está registrado' } });
      }
      console.error('create-student insert error:', insertError);
      return res.status(500).json({ error: 'No se pudo crear el alumno' });
    }

    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('create-student error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}
