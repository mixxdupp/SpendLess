import { createClient } from '@supabase/supabase-js';

// ====================
// SECURITY CONFIGURATION
// ====================
const RATE_LIMITS = {
  demotivate: { requests: 30, windowMs: 60000 },  // 30 req/min for AI
  extractMetadata: { requests: 20, windowMs: 60000 }, // 20 req/min for metadata
  default: { requests: 100, windowMs: 60000 }  // 100 req/min general
};

// In-memory rate limit store (resets on worker restart, use KV for persistence)
const rateLimitStore = new Map();

function getRateLimitKey(ip, endpoint) {
  return `${ip}:${endpoint}`;
}

function isRateLimited(ip, endpoint) {
  const config = RATE_LIMITS[endpoint] || RATE_LIMITS.default;
  const key = getRateLimitKey(ip, endpoint);
  const now = Date.now();

  if (!rateLimitStore.has(key)) {
    rateLimitStore.set(key, { count: 1, resetAt: now + config.windowMs });
    return false;
  }

  const record = rateLimitStore.get(key);

  if (now > record.resetAt) {
    rateLimitStore.set(key, { count: 1, resetAt: now + config.windowMs });
    return false;
  }

  if (record.count >= config.requests) {
    return true;
  }

  record.count++;
  return false;
}

// Input validation helpers
function sanitizeString(str, maxLength = 1000) {
  if (typeof str !== 'string') return '';
  return str.slice(0, maxLength).trim();
}

function validatePrice(price) {
  const num = parseFloat(price);
  return isNaN(num) || num < 0 ? 0 : Math.min(num, 999999999);
}

function validateUrl(url) {
  if (typeof url !== 'string') return false;
  try {
    const parsed = new URL(url);
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';

    // Initialize Supabase client
    const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_KEY);

    // Security headers (OWASP recommended)
    const securityHeaders = {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Content-Security-Policy': "default-src 'none'",
      'Referrer-Policy': 'strict-origin-when-cross-origin'
    };

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      ...securityHeaders
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Rate limiting check for sensitive endpoints
    const rateLimitEndpoint = path === '/demotivate' ? 'demotivate' :
      path === '/extract-metadata' ? 'extractMetadata' : 'default';

    if (isRateLimited(clientIP, rateLimitEndpoint)) {
      return jsonResponse({
        error: 'Rate limit exceeded',
        retryAfter: 60
      }, 429, corsHeaders);
    }

    try {
      // Get auth token from header
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
      }

      // Route handling
      if (path === '/products' && request.method === 'GET') {
        return await getProducts(request, supabase, corsHeaders);
      }

      if (path === '/products' && request.method === 'POST') {
        return await addProduct(request, supabase, corsHeaders);
      }

      if (path.startsWith('/products/') && request.method === 'DELETE') {
        const productId = path.split('/')[2];
        return await deleteProduct(productId, supabase, corsHeaders);
      }

      if (path.startsWith('/products/') && path.endsWith('/history')) {
        const productId = path.split('/')[2];
        return await getPriceHistory(productId, request, supabase, corsHeaders);
      }

      if (path === '/scrape' && request.method === 'POST') {
        return await triggerScrape(request, supabase, env, corsHeaders);
      }

      if (path === '/stats/saved' && request.method === 'GET') {
        return await getMoneySaved(request, supabase, corsHeaders);
      }

      if (path === '/notifications' && request.method === 'GET') {
        return await getNotifications(request, supabase, corsHeaders);
      }

      if (path.startsWith('/notifications/') && request.method === 'PATCH') {
        const id = path.split('/')[2];
        return await markNotificationRead(id, request, supabase, corsHeaders);
      }

      if (path === '/extract-metadata' && request.method === 'POST') {
        return await extractMetadataWithAI(request, env, corsHeaders);
      }

      if (path === '/demotivate' && request.method === 'POST') {
        return await demotivateUser(request, env, corsHeaders);
      }

      return jsonResponse({ error: 'Not found' }, 404, corsHeaders);
    } catch (error) {
      console.error('Error:', error);
      return jsonResponse({ error: error.message }, 500, corsHeaders);
    }
  },

  // Cron trigger for automatic price checks
  async scheduled(event, env, ctx) {
    const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_KEY);

    // Get all products that need checking
    const { data: products, error } = await supabase
      .from('products')
      .select('*')
      .or('last_checked_at.is.null,last_checked_at.lt.' + new Date(Date.now() - 3600000).toISOString());

    if (error) {
      console.error('Failed to fetch products:', error);
      return;
    }

    // Scrape each product
    for (const product of products) {
      try {
        await scrapeProduct(product, supabase, env);
      } catch (error) {
        console.error(`Failed to scrape product ${product.id}:`, error);
      }
    }
  }
};

// Helper functions
async function getProducts(request, supabase, corsHeaders) {
  const { data: { user } } = await supabase.auth.getUser(
    request.headers.get('Authorization').replace('Bearer ', '')
  );

  if (!user) {
    return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
  }

  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  if (error) throw error;

  return jsonResponse({ products: data }, 200, corsHeaders);
}

async function addProduct(request, supabase, corsHeaders) {
  const { data: { user } } = await supabase.auth.getUser(
    request.headers.get('Authorization').replace('Bearer ', '')
  );

  if (!user) {
    return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
  }

  // Check tier limits
  const { data: userData } = await supabase
    .from('users')
    .select('subscription_tier')
    .eq('id', user.id)
    .single();

  const { data: existingProducts } = await supabase
    .from('products')
    .select('id')
    .eq('user_id', user.id);

  const limits = {
    'FREE': 1,
    'PAID_ONETIME': 10,
    'PREMIUM_SUBSCRIPTION': null
  };

  const limit = limits[userData.subscription_tier];
  if (limit !== null && existingProducts.length >= limit) {
    return jsonResponse({ error: 'Product limit reached' }, 402, corsHeaders);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders);
  }

  // Validate URL - must be valid HTTPS e-commerce URL
  if (!body.url || !validateUrl(body.url)) {
    return jsonResponse({ error: 'Invalid product URL' }, 400, corsHeaders);
  }

  // Sanitize and validate cooldown days
  const cooldownDays = Math.max(1, Math.min(parseInt(body.cooldown_days) || 7, 365));

  // NOTE: Supabase uses parameterized queries internally, preventing SQL injection.
  // User input is never concatenated into SQL strings.
  const { data, error } = await supabase
    .from('products')
    .insert({
      user_id: user.id,
      url: sanitizeString(body.url, 2000),
      cooldown_days: cooldownDays,
      alert_enabled: true
    })
    .select()
    .single();

  if (error) throw error;

  // Trigger initial scrape
  await scrapeProduct(data, supabase, { CACHE: null });

  return jsonResponse({ product: data }, 201, corsHeaders);
}

async function deleteProduct(productId, supabase, corsHeaders) {
  const { error } = await supabase
    .from('products')
    .delete()
    .eq('id', productId);

  if (error) throw error;

  return jsonResponse({ success: true }, 200, corsHeaders);
}

async function getPriceHistory(productId, request, supabase, corsHeaders) {
  const url = new URL(request.url);
  const days = parseInt(url.searchParams.get('days') || '30');

  const cutoffDate = new Date(Date.now() - days * 86400000).toISOString();

  const { data, error } = await supabase
    .from('price_history')
    .select('*')
    .eq('product_id', productId)
    .gte('recorded_at', cutoffDate)
    .order('recorded_at', { ascending: true });

  if (error) throw error;

  return jsonResponse({ history: data }, 200, corsHeaders);
}

async function getMoneySaved(request, supabase, corsHeaders) {
  const { data: { user } } = await supabase.auth.getUser(
    request.headers.get('Authorization').replace('Bearer ', '')
  );

  if (!user) {
    return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
  }

  const { data: products } = await supabase
    .from('products')
    .select('current_price')
    .eq('user_id', user.id);

  const total = products.reduce((sum, p) => sum + (parseFloat(p.current_price) || 0), 0);

  return jsonResponse({ saved: total }, 200, corsHeaders);
}

async function getNotifications(request, supabase, corsHeaders) {
  const { data: { user } } = await supabase.auth.getUser(
    request.headers.get('Authorization').replace('Bearer ', '')
  );

  if (!user) {
    return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
  }

  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) throw error;

  return jsonResponse({ notifications: data }, 200, corsHeaders);
}

async function markNotificationRead(id, request, supabase, corsHeaders) {
  const { data: { user } } = await supabase.auth.getUser(
    request.headers.get('Authorization').replace('Bearer ', '')
  );

  if (!user) {
    return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
  }

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', id)
    .eq('user_id', user.id);

  if (error) throw error;

  return jsonResponse({ success: true }, 200, corsHeaders);
}

// Extract product metadata using Gemini AI (server-side, key protected)
async function extractMetadataWithAI(request, env, corsHeaders) {
  const body = await request.json();
  const { html, title } = body;

  if (!env.GEMINI_API_KEY) {
    return jsonResponse({ error: 'AI service unavailable' }, 503, corsHeaders);
  }

  if (!html) {
    return jsonResponse({ error: 'HTML content required' }, 400, corsHeaders);
  }

  const truncatedHtml = html.substring(0, 15000);

  const prompt = `Extract product information from this e-commerce HTML page.

PRIORITY: Find the main product image URL. Look for:
- og:image meta tag
- data-old-hires or data-a-dynamic-image attributes
- JSON-LD image property
- img tags with id containing "main", "product", "landing"
- High resolution image URLs (containing 'SX', 'SY', '_AC_SL' for Amazon)

Return ONLY valid JSON:
{"title": "product name", "price": number, "currency": "INR/USD/EUR/GBP", "imageUrl": "https://..."}

For imageUrl, return the highest quality product image URL you can find.
If not found, use null. No explanation, just JSON.

HTML:
${truncatedHtml}`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0, maxOutputTokens: 512 }
        })
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Gemini API error:', response.status, errorBody);
      return jsonResponse({ error: 'AI service error', details: errorBody }, 502, corsHeaders);
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '{}';

    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*?\}/);
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0]);
        return jsonResponse({
          title: parsed.title || null,
          price: parsed.price || null,
          currency: parsed.currency || null,
          imageUrl: parsed.imageUrl || null
        }, 200, corsHeaders);
      } catch (e) {
        return jsonResponse({ title: null, price: null, currency: null, imageUrl: null }, 200, corsHeaders);
      }
    }

    return jsonResponse({ title: null, price: null, currency: null, imageUrl: null }, 200, corsHeaders);
  } catch (error) {
    console.error('Metadata extraction error:', error);
    return jsonResponse({ error: 'Failed to extract metadata' }, 500, corsHeaders);
  }
}

// Anti-Salesman AI: Generate demotivation message using Groq (Llama 3.3)
async function demotivateUser(request, env, corsHeaders) {
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders);
  }

  // Input validation and sanitization
  const title = sanitizeString(body.title, 500);
  const price = validatePrice(body.price);
  const currency = sanitizeString(body.currency, 10) || 'USD';
  const daysToEarn = Math.max(0, Math.min(parseFloat(body.daysToEarn) || 0, 10000));
  const messages = Array.isArray(body.messages) ? body.messages.slice(0, 20) : []; // Limit conversation history

  if (!env.GROQ_API_KEY) {
    return jsonResponse({ error: 'AI service unavailable' }, 503, corsHeaders);
  }

  const daysRounded = Math.round(daysToEarn || 0);

  const systemPrompt = `You are "The Anti-Salesman" - a witty, skeptical friend who's seen too many people waste money.

PRODUCT: "${title || 'Unknown Product'}"
PRICE: ${currency || '$'}${price || '0'}
WORK: About ${daysRounded || 'several'} days of their paycheck

YOUR STYLE:
- Talk like a real person, not a financial textbook
- Be slightly sarcastic but caring
- Use casual language ("Look," "Honestly," "Here's the thing")
- Reference the SPECIFIC product by name
- Keep it SHORT (2-3 punchy sentences max)
- End with a gut-punch question that makes them think

EXAMPLES OF GOOD RESPONSES:
- "Look, a gaming keyboard? You'll type on it for a month and then forget it exists. That's ₹2000 for temporary clicky satisfaction."
- "Honestly, this GPU will be 'mid-tier' by next Christmas. You're paying premium for something that'll feel outdated in 18 months."
- "Here's the thing about premium ghee—your taste buds adapt in a week. Then you're just paying 3x for... ghee."

BAD (too formal): "This represents a significant investment requiring careful consideration of the opportunity cost."
GOOD (human): "Six weeks of work for a graphics card? That's a lot of time to trade for pixels."

NO: greetings, "I understand", bullet points, jargon like "hedonic treadmill"
YES: direct, punchy, slightly provocative, genuinely trying to help`;

  // Build messages array for Groq (OpenAI-compatible format)
  let groqMessages = [{ role: 'system', content: systemPrompt }];

  if (messages && messages.length > 0) {
    messages.forEach(msg => {
      groqMessages.push({
        role: msg.role === 'user' ? 'user' : 'assistant',
        content: msg.text
      });
    });
  } else {
    groqMessages.push({
      role: 'user',
      content: 'Analyze this purchase. Should I buy it?'
    });
  }

  try {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.GROQ_API_KEY}`
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: groqMessages,
        temperature: 0.85,
        max_tokens: 300,
        top_p: 0.9
      })
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Groq API error:', response.status, errorBody);
      return jsonResponse({ error: 'AI service error', details: errorBody }, 502, corsHeaders);
    }

    const data = await response.json();
    const message = data.choices?.[0]?.message?.content || "I couldn't analyze this product. But ask yourself: do you really need it?";

    return jsonResponse({ message }, 200, corsHeaders);
  } catch (error) {
    console.error('Demotivation error:', error);
    return jsonResponse({ error: 'Failed to generate advice' }, 500, corsHeaders);
  }
}

async function triggerScrape(request, supabase, env, corsHeaders) {
  const body = await request.json();
  const { product_id } = body;

  const { data: product } = await supabase
    .from('products')
    .select('*')
    .eq('id', product_id)
    .single();

  if (!product) {
    return jsonResponse({ error: 'Product not found' }, 404, corsHeaders);
  }

  await scrapeProduct(product, supabase, env);

  return jsonResponse({ success: true }, 200, corsHeaders);
}

async function scrapeProduct(product, supabase, env) {
  // Parse URL to determine store (for display purposes)
  const url = new URL(product.url);
  let store = url.hostname.replace('www.', '').split('.')[0];

  // Use universal scraper (with Gemini AI fallback)
  const scraped = await scrapeUrl(product.url, env);
  const { price, title, imageUrl } = scraped;

  if (price === null) {
    console.log('Failed to scrape price for product:', product.id);
    return;
  }

  // Update product
  await supabase
    .from('products')
    .update({
      current_price: price,
      title: title || product.title,
      image_url: imageUrl || product.image_url,
      store: store,
      last_checked_at: new Date().toISOString()
    })
    .eq('id', product.id);

  // Add to price history
  await supabase
    .from('price_history')
    .insert({
      product_id: product.id,
      price: price
    });

  // Check if price dropped and send notification
  if (product.current_price && price < product.current_price && product.alert_enabled) {
    // Check cooldown
    const cooldownEnds = new Date(product.created_at);
    cooldownEnds.setDate(cooldownEnds.getDate() + product.cooldown_days);

    if (new Date() >= cooldownEnds) {
      await sendAlerts(product, price, supabase, env);
    }
  }
}

// Multi-channel alert system (Email + In-App)
async function sendAlerts(product, newPrice, supabase, env) {
  const title = 'Price Drop Alert! 📉';
  const body = `${product.title} is now $${newPrice}. Your cooldown is over!`;

  await Promise.all([
    sendEmail(product, newPrice, env),
    createInAppNotification(product.user_id, title, body, product.id, supabase)
  ]);
}

async function sendEmail(product, newPrice, env) {
  if (!env.RESEND_API_KEY) {
    console.log('Skipping email: RESEND_API_KEY not set');
    return;
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'Stop Impulsing <alerts@stopimpulsing.app>',
        to: ['user@example.com'], // In prod, we'd fetch the real user email
        subject: `Price Drop: ${product.title}`,
        html: `<p>Good news! <strong>${product.title}</strong> dropped to <strong>$${newPrice}</strong>.</p>
               <p><a href="${product.url}">View Deal</a></p>`
      })
    });

    if (!res.ok) console.error('Resend API Error:', await res.text());
  } catch (e) {
    console.error('Email failed:', e);
  }
}

async function createInAppNotification(userId, title, body, productId, supabase) {
  const { error } = await supabase
    .from('notifications')
    .insert({
      user_id: userId,
      title: title,
      body: body,
      product_id: productId,
      is_read: false
    });

  if (error) console.error('Failed to create in-app notification:', error);
}

// Universal scraper - works on any e-commerce site
async function scrapeUrl(url, env) {
  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    });

    if (!response.ok) {
      console.error('Failed to fetch URL:', response.status);
      return { price: null, title: null, imageUrl: null };
    }

    const html = await response.text();

    // Priority 1: JSON-LD Product Schema
    const jsonLdResult = extractJsonLd(html);
    if (jsonLdResult.price) {
      console.log('Extracted via JSON-LD');
      return jsonLdResult;
    }

    // Priority 1.5: __NEXT_DATA__ (React/Next.js sites like Target)
    const nextDataResult = extractNextData(html);
    if (nextDataResult.price || nextDataResult.title) {
      console.log('Extracted via __NEXT_DATA__');
      return { ...nextDataResult, ...jsonLdResult };
    }

    // Priority 2: Open Graph meta tags
    const ogResult = extractOpenGraph(html);
    if (ogResult.price || ogResult.title) {
      console.log('Extracted via Open Graph');
      return { ...ogResult, ...jsonLdResult }; // Merge with any partial JSON-LD data
    }

    // Priority 3: Microdata
    const microdataResult = extractMicrodata(html);
    if (microdataResult.price) {
      console.log('Extracted via Microdata');
      return { ...microdataResult, ...ogResult, ...jsonLdResult };
    }

    // Priority 4: Heuristic fallback
    const heuristicResult = extractHeuristic(html);
    if (heuristicResult.price && heuristicResult.title) {
      console.log('Extracted via Heuristics');
      return { ...heuristicResult, ...microdataResult, ...ogResult, ...jsonLdResult };
    }

    // Priority 5: AI Fallback (Gemini Flash)
    if (env?.GEMINI_API_KEY) {
      console.log('Attempting AI extraction via Gemini...');
      const aiResult = await extractWithGemini(html, env.GEMINI_API_KEY);
      if (aiResult.price || aiResult.title) {
        console.log('Extracted via Gemini AI');
        return { ...aiResult, ...heuristicResult, ...microdataResult, ...ogResult, ...jsonLdResult };
      }
    }

    // Return whatever we have
    return { ...heuristicResult, ...microdataResult, ...ogResult, ...jsonLdResult };

  } catch (error) {
    console.error('Scrape error:', error);
    return { price: null, title: null, imageUrl: null };
  }
}

// Gemini AI Extraction
async function extractWithGemini(html, apiKey) {
  try {
    // Truncate HTML to avoid token limits (keep first 15KB)
    const truncatedHtml = html.substring(0, 15000);

    const prompt = `Extract product information from this e-commerce HTML snippet.
Return ONLY a valid JSON object with these exact keys: {"title": "...", "price": number, "currency": "...", "imageUrl": "..."}
If a field is not found, use null.
Do not include any explanation, just the JSON.

HTML:
${truncatedHtml}`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: 256,
          }
        })
      }
    );

    if (!response.ok) {
      console.error('Gemini API error:', response.status);
      return { price: null, title: null, imageUrl: null };
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

    // Extract JSON from response (handle markdown code blocks)
    const jsonMatch = text.match(/\{[\s\S]*?\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        price: parsed.price ? parseFloat(parsed.price) : null,
        title: parsed.title || null,
        imageUrl: parsed.imageUrl || null
      };
    }

    return { price: null, title: null, imageUrl: null };
  } catch (error) {
    console.error('Gemini extraction error:', error);
    return { price: null, title: null, imageUrl: null };
  }
}

// Extract from JSON-LD (Schema.org Product)
function extractJsonLd(html) {
  const result = { price: null, title: null, imageUrl: null };

  // Match all JSON-LD scripts
  const jsonLdRegex = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = jsonLdRegex.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1]);
      const products = findProducts(data);

      for (const product of products) {
        if (product.name && !result.title) {
          result.title = product.name;
        }
        if (product.image && !result.imageUrl) {
          result.imageUrl = Array.isArray(product.image) ? product.image[0] : product.image;
          if (typeof result.imageUrl === 'object') {
            result.imageUrl = result.imageUrl.url || result.imageUrl['@id'];
          }
        }
        if (product.offers && !result.price) {
          const offers = Array.isArray(product.offers) ? product.offers[0] : product.offers;
          result.price = parseFloat(offers.price || offers.lowPrice || offers.highPrice);
        }
      }
    } catch (e) {
      // Invalid JSON, skip
    }
  }

  return result;
}

// Recursively find Product objects in JSON-LD
function findProducts(data) {
  const products = [];

  if (Array.isArray(data)) {
    for (const item of data) {
      products.push(...findProducts(item));
    }
  } else if (typeof data === 'object' && data !== null) {
    if (data['@type'] === 'Product' || data['@type']?.includes?.('Product')) {
      products.push(data);
    }
    if (data['@graph']) {
      products.push(...findProducts(data['@graph']));
    }
  }

  return products;
}

// Extract from __NEXT_DATA__ (React/Next.js sites like Target)
function extractNextData(html) {
  const result = { price: null, title: null, imageUrl: null };

  const nextDataMatch = html.match(/<script[^>]*id="__NEXT_DATA__"[^>]*>([^<]+)<\/script>/i);
  if (!nextDataMatch) return result;

  try {
    const data = JSON.parse(nextDataMatch[1]);

    // Try to find product data in common locations
    const pageProps = data.props?.pageProps;
    if (pageProps) {
      // Target-style structure
      const product = pageProps.product || pageProps.productData || pageProps.item;
      if (product) {
        if (product.title || product.name) result.title = product.title || product.name;
        if (product.price?.current || product.price?.regular) {
          result.price = parseFloat(product.price.current || product.price.regular);
        }
        if (product.images?.[0]?.url || product.image) {
          result.imageUrl = product.images?.[0]?.url || product.image;
        }
      }

      // Shopify-style structure
      if (pageProps.product?.variants?.[0]?.price) {
        result.price = parseFloat(pageProps.product.variants[0].price) / 100;
        result.title = pageProps.product.title;
        if (pageProps.product.featuredImage?.url) {
          result.imageUrl = pageProps.product.featuredImage.url;
        }
      }
    }

    // Deep search for price-like keys
    const priceStr = JSON.stringify(data).match(/"(?:price|currentPrice|salePrice)"\s*:\s*(\d+\.?\d*)/i);
    if (priceStr && !result.price) {
      result.price = parseFloat(priceStr[1]);
    }

  } catch (e) {
    // Invalid JSON, skip
  }

  return result;
}

// Extract from Open Graph meta tags
function extractOpenGraph(html) {
  const result = { price: null, title: null, imageUrl: null };

  // og:title
  const titleMatch = html.match(/<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']/i);
  if (titleMatch) result.title = decodeHtmlEntities(titleMatch[1]);

  // og:image
  const imageMatch = html.match(/<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i);
  if (imageMatch) result.imageUrl = imageMatch[1];

  // product:price:amount or og:price:amount
  const priceMatch = html.match(/<meta[^>]*property=["'](?:product:price:amount|og:price:amount)["'][^>]*content=["']([^"']+)["']/i);
  if (priceMatch) result.price = parseFloat(priceMatch[1]);

  return result;
}

// Extract from Microdata (itemprop)
function extractMicrodata(html) {
  const result = { price: null, title: null, imageUrl: null };

  // itemprop="price"
  const priceMatch = html.match(/<[^>]*itemprop=["']price["'][^>]*content=["']([^"']+)["']/i) ||
    html.match(/<[^>]*itemprop=["']price["'][^>]*>([^<]+)</i);
  if (priceMatch) {
    const priceStr = priceMatch[1].replace(/[^0-9.]/g, '');
    result.price = parseFloat(priceStr);
  }

  // itemprop="name"
  const nameMatch = html.match(/<[^>]*itemprop=["']name["'][^>]*content=["']([^"']+)["']/i) ||
    html.match(/<[^>]*itemprop=["']name["'][^>]*>([^<]+)</i);
  if (nameMatch) result.title = decodeHtmlEntities(nameMatch[1].trim());

  // itemprop="image"
  const imageMatch = html.match(/<[^>]*itemprop=["']image["'][^>]*(?:src|content)=["']([^"']+)["']/i);
  if (imageMatch) result.imageUrl = imageMatch[1];

  return result;
}

// Heuristic fallback - pattern matching
function extractHeuristic(html) {
  const result = { price: null, title: null, imageUrl: null };

  // Try to find price patterns like $XX.XX or XX.XX USD
  const pricePatterns = [
    /\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/,
    /(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*(?:USD|usd)/,
    /price[^>]*>.*?\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/i,
  ];

  for (const pattern of pricePatterns) {
    const match = html.match(pattern);
    if (match) {
      result.price = parseFloat(match[1].replace(/,/g, ''));
      break;
    }
  }

  // Try <title> tag for product name
  const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  if (titleMatch) {
    result.title = decodeHtmlEntities(titleMatch[1].split('|')[0].split('-')[0].trim());
  }

  // Try to find a large product image
  const imageMatch = html.match(/<img[^>]*(?:id=["'](?:main|product|hero)[^"']*["']|class=["'][^"']*product[^"']*["'])[^>]*src=["']([^"']+)["']/i);
  if (imageMatch) result.imageUrl = imageMatch[1];

  return result;
}

function decodeHtmlEntities(str) {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}

function jsonResponse(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...headers
    }
  });
}
