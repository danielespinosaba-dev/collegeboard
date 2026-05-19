exports.handler = async (event) => {
  try {
    const { prompt } = JSON.parse(event.body);
    const GEMINI_KEY = 'AIzaSyBgs_CqmAeY3k81t5bOT2nONwyoNjh9zZA';

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }]
        })
      }
    );

    const data = await res.json();

    return {
      statusCode: 200,
      headers: { 
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ text: JSON.stringify(data) })
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ text: 'Error: ' + err.message })
    };
  }
};
