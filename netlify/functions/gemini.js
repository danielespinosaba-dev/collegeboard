exports.handler = async (event) => {
  try {
    const { prompt } = JSON.parse(event.body);

    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer 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',
        'HTTP-Referer': 'https://college-board.netlify.app',
        'X-Title': 'PIENSE Mini-Examenes'
      },
      body: JSON.stringify({
        model: 'google/gemma-3-4b-it:free',
        messages: [{ role: 'user', content: prompt }]
      })
    });

    const data = await res.json();
    const text = JSON.stringify(data);

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ text })
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ text: 'Error: ' + err.message })
    };
  }
};
