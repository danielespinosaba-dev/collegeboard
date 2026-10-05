// Configuration centralized
// This file should be used to manage environment-specific settings

const CONFIG = {
  // Supabase Configuration
  SUPABASE_URL: process.env.SUPABASE_URL || 'https://gkekofjqyyxagpppsgyq.supabase.co',
  SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdrZWtvZmpxeXl4YWdwcHBzZ3lxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODIzNTEsImV4cCI6MjEwMzg1ODM1MX0.203A8GlOsV6-4bqqv1LqvV1RQti65YtayDUniMLRKLc',

  // OpenRouter API Configuration
  OPENROUTER_KEY: process.env.OPENROUTER_KEY,
  OPENROUTER_MODEL: 'nvidia/llama-3.1-nemotron-ultra-253b-v1:free',

  // App Configuration
  APP_NAME: 'PIENSE Mini-Examenes',
  APP_URL: process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
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