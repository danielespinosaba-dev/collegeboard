exports.handler = async (event) => {
  const { prompt } = JSON.parse(event.body);
  const GEMINI_KEY = 'AIzaSyBgs_CqmAeY3k81t5bOT2nONwyoNjh9zZA';

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] })
    }
  );

  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sin respuesta';

  return {
    statusCode: 200,
    headers: { 'Access-Control-Allow-Origin': '*' },
    body: JSON.stringify({ text })
  };
};
