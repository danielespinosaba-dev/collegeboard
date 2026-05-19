export default async function handler(req, res) {
  try {
    const { prompt } = req.body;
    const key = process.env.OPENROUTER_KEY;

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${key}`,
        'HTTP-Referer': 'https://collegeboard-nine.vercel.app',
        'X-Title': 'PIENSE Mini-Examenes'
      },
      body: JSON.stringify({
        model: 'nvidia/llama-3.1-nemotron-ultra-253b-v1:free',
        messages: [{ role: 'user', content: prompt }]
      })
    });

    const data = await response.json();
    const text = data?.choices?.[0]?.message?.content || JSON.stringify(data);

    res.status(200).json({ text });
  } catch (err) {
    res.status(500).json({ text: 'Error: ' + err.message });
  }
}
