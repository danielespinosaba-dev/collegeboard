export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { prompt } = req.body;

    // Validate input
    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({ error: 'Invalid prompt provided' });
    }

    // Check API key
    const key = process.env.OPENROUTER_KEY;
    if (!key) {
      console.error('OPENROUTER_KEY environment variable not set');
      return res.status(503).json({ error: 'Service temporarily unavailable' });
    }

    // Get current domain for referer
    const referer = req.headers.host
      ? `https://${req.headers.host}`
      : 'https://collegeboard-nine.vercel.app';

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${key}`,
        'HTTP-Referer': referer,
        'X-Title': 'PIENSE Mini-Examenes'
      },
      body: JSON.stringify({
        model: 'nvidia/llama-3.1-nemotron-ultra-253b-v1:free', // Unified model
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: 1000
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('OpenRouter API error:', response.status, errorText);
      return res.status(502).json({ error: 'External service error' });
    }

    const data = await response.json();
    const text = data?.choices?.[0]?.message?.content || 'No response generated';

    res.status(200).json({ text });

  } catch (err) {
    console.error('API error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}
