// Configuration centralized
// This file should be used to manage environment-specific settings

// `process` solo existe en el entorno Node de las funciones serverless de Vercel;
// en el navegador no existe, así que lo protegemos para no reventar config.js ahí.
const env = typeof process !== 'undefined' ? process.env : {};

const CONFIG = {
  // Supabase Configuration
  SUPABASE_URL: env.SUPABASE_URL || 'https://euwsjtcvfwcivywpkyyn.supabase.co',
  SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1d3NqdGN2ZndjaXZ5d3BreXluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxMDUyMTgsImV4cCI6MjA5NDY4MTIxOH0.w2s8ZCaCKe_w25uuqKU5Io520SM_ecABdrTMQI95Swk',

  // OpenRouter API Configuration
  OPENROUTER_KEY: env.OPENROUTER_KEY,
  OPENROUTER_MODEL: 'nvidia/nemotron-3-ultra-550b-a55b:free',

  // App Configuration
  APP_NAME: 'PIENSE Mini-Examenes',
  APP_URL: env.VERCEL_URL
    ? `https://${env.VERCEL_URL}`
    : (typeof window !== 'undefined' ? window.location.origin : 'https://collegeboard-nine.vercel.app'),

  // Features
  EXAM_DURATION_MINUTES: 10,
  MAX_QUESTIONS_PER_EXAM: 10,

  // API Endpoints
  API_ENDPOINTS: {
    GEMINI: '/api/gemini'
  }
};

// For client-side usage
if (typeof window !== 'undefined') {
  window.CONFIG = CONFIG;
}

// For server-side usage (Node.js)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}

export default CONFIG;