import { getAdminClient, verifyAccessToken, setCors } from './_supabaseAdmin.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { accessToken, studentId, newPassword } = req.body || {};
    if (!accessToken || !studentId || !newPassword || newPassword.length < 4) {
      return res.status(400).json({ error: 'Solicitud inválida' });
    }

    const admin = getAdminClient();
    const user = await verifyAccessToken(admin, accessToken);
    if (!user) return res.status(401).json({ error: 'Sesión inválida' });

    const { data: teacher } = await admin.from('teachers').select('id').eq('user_id', user.id).single();
    if (!teacher) return res.status(403).json({ error: 'Solo un docente puede resetear contraseñas' });

    const { data: student } = await admin.from('students').select('user_id, group_id').eq('id', studentId).single();
    if (!student) return res.status(404).json({ error: 'Alumno no encontrado' });

    const { data: group } = await admin.from('groups').select('teacher_id').eq('id', student.group_id).single();
    if (!group || group.teacher_id !== teacher.id) {
      return res.status(403).json({ error: 'Ese alumno no pertenece a tu grupo' });
    }

    const { error } = await admin.auth.admin.updateUserById(student.user_id, { password: newPassword });
    if (error) {
      console.error('reset-student-password updateUserById error:', error);
      return res.status(500).json({ error: 'No se pudo actualizar la contraseña' });
    }

    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('reset-student-password error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}
