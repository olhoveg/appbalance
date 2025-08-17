const SHOP_ID  = process.env.YK_SHOP_ID;      // напр. 773757
const SECRET   = process.env.YK_SECRET_KEY;   // секретный API-ключ из кабинета YooKassa
const API      = "https://api.yookassa.ru/v3";

function response(statusCode, body, extraHeaders = {}) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
      ...extraHeaders
    },
    body: JSON.stringify(body)
  };
}

// Поддержка форматов события 1.0 и 2.0 от API Gateway
function getMethod(event) {
  return event.httpMethod || event.requestContext?.http?.method || "GET";
}
function getPath(event) {
  return event.path || event.rawPath || "/";
}
function getBody(event) {
  return typeof event.body === "string" ? event.body : JSON.stringify(event.body || "{}");
}
function getQueryParams(event) {
  return event.queryStringParameters || {};
}
function idemKey() {
  return (typeof crypto !== "undefined" && crypto.randomUUID) ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`;
}

export async function handler(event, context) {
  try {
    const method = getMethod(event);
    if (method === "OPTIONS") return response(200, { ok: true });

    const path = getPath(event);

    if (path.endsWith("/payments/create")) {
      if (method !== "POST") return response(405, { error: "Method not allowed" });
      return await createPayment(event);
    }

    if (path.endsWith("/payments/status")) {
      if (method !== "GET") return response(405, { error: "Method not allowed" });
      return await getPaymentStatus(event);
    }

    if (path.endsWith("/payments/pending")) {
      if (method !== "GET") return response(405, { error: "Method not allowed" });
      return await getPendingPurchases(event);
    }

    if (path.endsWith("/webhooks/yookassa")) {
      if (method !== "POST") return response(405, { error: "Method not allowed" });
      return await yookassaWebhook(event);
    }

    return response(404, { error: "Not found", path, method });
  } catch (e) {
    console.error("Handler error:", e);
    return response(500, { error: "Internal error", message: String(e) });
  }
}

async function createPayment(event) {
  if (!SHOP_ID || !SECRET) {
    return response(500, { error: "Server not configured" });
  }

  let body;
  try {
    body = JSON.parse(getBody(event) || "{}");
  } catch {
    return response(400, { error: "Invalid JSON" });
  }

  const { amount, description, sdkToken, returnUrl } = body;
  if (!amount || !sdkToken) {
    return response(400, { error: "amount and sdkToken are required" });
  }

  const idem = idemKey();
  const auth = Buffer.from(`${SHOP_ID}:${SECRET}`).toString("base64");

  const payload = {
    amount: { value: String(amount), currency: "RUB" },
    capture: true,
    description: description || "Покупка",
    payment_method_data: { type: "bank_card", payment_token: sdkToken },
    confirmation: { type: "redirect", return_url: returnUrl || "balanceapp://payment-return" },
    save_payment_method: false
  };

  let r, data;
  try {
    r = await fetch(`${API}/payments`, {
      method: "POST",
      headers: {
        "Idempotence-Key": idem,
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });
    data = await r.json();
  } catch (e) {
    console.error("Fetch error:", e);
    return response(502, { error: "Upstream fetch failed", message: String(e) });
  }

  if (!r.ok) {
    console.error("YooKassa error:", data);
    return response(400, data);
  }
  return response(200, data);
}

async function getPaymentStatus(event) {
  if (!SHOP_ID || !SECRET) {
    return response(500, { error: "Server not configured" });
  }

  const queryParams = getQueryParams(event);
  const paymentId = queryParams.payment_id;

  if (!paymentId) {
    return response(400, { error: "payment_id is required" });
  }

  const auth = Buffer.from(`${SHOP_ID}:${SECRET}`).toString("base64");

  let r, data;
  try {
    r = await fetch(`${API}/payments/${paymentId}`, {
      method: "GET",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json"
      }
    });
    data = await r.json();
  } catch (e) {
    console.error("Fetch error:", e);
    return response(502, { error: "Upstream fetch failed", message: String(e) });
  }

  if (!r.ok) {
    console.error("YooKassa error:", data);
    return response(400, data);
  }

  return response(200, {
    status: data.status,
    payment_id: paymentId
  });
}

async function getPendingPurchases(event) {
  const queryParams = getQueryParams(event);
  const userPhone = queryParams.user_phone;

  if (!userPhone) {
    return response(400, { error: "user_phone is required" });
  }

  try {
    const pendingPurchases = await getPendingPurchasesFromFirebase(userPhone);
    
    return response(200, {
      pending_purchases: pendingPurchases
    });
  } catch (error) {
    console.error("Error getting pending purchases:", error);
    return response(500, { error: "Internal server error" });
  }
}

async function yookassaWebhook(event) {
  let body;
  try {
    body = JSON.parse(getBody(event) || "{}");
  } catch {
    return response(400, { error: "Invalid JSON" });
  }

  console.log("Webhook:", JSON.stringify(body));

  if (body.event === "payment.succeeded") {
    const payment = body.object;
    console.log("Payment succeeded:", {
      id: payment.id,
      amount: payment.amount,
      status: payment.status,
      metadata: payment.metadata
    });
    
    try {
      const purchaseData = {
        paymentId: payment.id,
        amount: payment.amount.value,
        currency: payment.amount.currency,
        description: payment.description,
        status: payment.status,
        createdAt: new Date().toISOString(),
        userPhone: extractUserPhoneFromDescription(payment.description),
        videoLessonId: extractVideoLessonIdFromDescription(payment.description)
      };
      
      await savePendingPurchase(purchaseData);
      console.log("Pending purchase saved:", purchaseData);
    } catch (error) {
      console.error("Error saving pending purchase:", error);
    }
  }

  if (body.event === "payment.canceled") {
    const payment = body.object;
    console.log("Payment canceled:", {
      id: payment.id,
      status: payment.status
    });
  }

  return response(200, { ok: true });
}

function extractUserPhoneFromDescription(description) {
  const phoneMatch = description.match(/телефон:\s*(\+?\d+)/);
  return phoneMatch ? phoneMatch[1] : null;
}

function extractVideoLessonIdFromDescription(description) {
  const idMatch = description.match(/ID:\s*(\w+)/);
  return idMatch ? idMatch[1] : null;
}

async function savePendingPurchase(purchaseData) {
  const firebaseUrl = process.env.FIREBASE_DATABASE_URL;
  if (!firebaseUrl) {
    console.error("FIREBASE_DATABASE_URL not configured");
    return;
  }
  
  try {
    const response = await fetch(`${firebaseUrl}/pendingPurchases/${purchaseData.paymentId}.json`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(purchaseData)
    });
    
    if (!response.ok) {
      throw new Error(`Failed to save to Firebase: ${response.status}`);
    }
    
    console.log("Pending purchase saved to Firebase:", purchaseData.paymentId);
  } catch (error) {
    console.error("Error saving to Firebase:", error);
    throw error;
  }
}

async function getPendingPurchasesFromFirebase(userPhone) {
  const firebaseUrl = process.env.FIREBASE_DATABASE_URL;
  if (!firebaseUrl) {
    console.error("FIREBASE_DATABASE_URL not configured");
    return [];
  }
  
  try {
    const response = await fetch(`${firebaseUrl}/pendingPurchases.json?orderBy="userPhone"&equalTo="${userPhone}"`);
    
    if (response.ok) {
      const data = await response.json();
      const purchases = [];
      
      if (data) {
        for (const [key, value] of Object.entries(data)) {
          if (value && value.status === 'succeeded') {
            purchases.push({
              paymentId: key,
              ...value
            });
          }
        }
      }
      
      console.log(`Found ${purchases.length} pending purchases for user ${userPhone}`);
      return purchases;
    } else {
      console.error("Firebase response error:", response.status);
      return [];
    }
  } catch (error) {
    console.error("Error getting pending purchases from Firebase:", error);
    return [];
  }
}
