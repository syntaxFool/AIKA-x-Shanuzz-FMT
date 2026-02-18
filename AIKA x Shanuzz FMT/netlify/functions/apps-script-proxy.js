// Netlify Function to proxy requests to Google Apps Script with CORS support
const APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbwkkNNoLSvazoc_7z6M5-3MGh53Kb1GgavTlvnpg1RSpgBPrrkNlt721aX1sTPhW7zbCg/exec';

exports.handler = async (event) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Content-Type': 'application/json',
  };

  // Handle OPTIONS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: 'OK',
    };
  }

  try {
    let url = APPS_SCRIPT_URL;
    let options = {
      method: event.httpMethod,
      headers: { 'Content-Type': 'application/json' },
    };

    if (event.httpMethod === 'GET') {
      const queryString = event.rawQuery;
      if (queryString) {
        url += '?' + queryString;
      }
    } else if (event.httpMethod === 'POST') {
      options.body = event.body;
    }

    const response = await fetch(url, options);
    const data = await response.text();

    return {
      statusCode: 200,
      headers,
      body: data,
    };
  } catch (error) {
    console.error('Proxy error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        error: error.message,
      }),
    };
  }
};
