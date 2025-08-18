const SHOP_ID  = process.env.YK_SHOP_ID;      // напр. 773757
const SECRET   = process.env.YK_SECRET_KEY;   // секретный API-ключ из кабинета YooKassa
const API      = "https://api.yookassa.ru/v3";

// Firebase REST API (простой подход)
const FIREBASE_DATABASE_URL = process.env.FIREBASE_DATABASE_URL || "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app";

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

  const { amount, description, sdkToken, returnUrl, paymentMethodType } = body;
  if (!amount || !sdkToken) {
    return response(400, { error: "amount and sdkToken are required" });
  }

  const idem = idemKey();
  const auth = Buffer.from(`${SHOP_ID}:${SECRET}`).toString("base64");

  // Используем тип платежного метода, переданный из iOS, или определяем по токену
  let finalPaymentMethodType = paymentMethodType || "bank_card";
  if (!paymentMethodType) {
    if (sdkToken.includes("sbp")) {
      finalPaymentMethodType = "sbp";
    } else if (sdkToken.includes("sberbank") || sdkToken.includes("sber")) {
      finalPaymentMethodType = "sberbank";
    } else if (sdkToken.includes("tinkoff") || sdkToken.includes("tinkoff_bank")) {
      finalPaymentMethodType = "tinkoff_bank";
    }
  }
  
  console.log("Payment method type from iOS:", paymentMethodType);
  console.log("Final payment method type:", finalPaymentMethodType);
  console.log("SDK Token:", sdkToken);
  
  // Для разных типов используем соответствующие настройки
  let payload;
  if (finalPaymentMethodType === "sbp") {
    payload = {
      amount: { value: String(amount), currency: "RUB" },
      capture: true,
      description: description || "Покупка",
      payment_method_data: { type: "sbp", payment_token: sdkToken },
      confirmation: { type: "redirect", return_url: returnUrl || "balanceapp://payment-return" },
      save_payment_method: false
    };
  } else if (finalPaymentMethodType === "sberbank") {
    payload = {
      amount: { value: String(amount), currency: "RUB" },
      capture: true,
      description: description || "Покупка",
      payment_method_data: { type: "sberbank", payment_token: sdkToken },
      confirmation: { type: "redirect", return_url: returnUrl || "balanceapp://payment-return" },
      save_payment_method: false
    };
  } else if (finalPaymentMethodType === "tinkoff_bank") {
    payload = {
      amount: { value: String(amount), currency: "RUB" },
      capture: true,
      description: description || "Покупка",
      payment_method_data: { type: "tinkoff_bank", payment_token: sdkToken },
      confirmation: { type: "redirect", return_url: returnUrl || "balanceapp://payment-return" },
      save_payment_method: false
    };
  } else {
    // Для банковских карт используем redirect (требование YooKassa)
    payload = {
      amount: { value: String(amount), currency: "RUB" },
      capture: true,
      description: description || "Покупка",
      payment_method_data: { type: "bank_card", payment_token: sdkToken },
      confirmation: { 
        type: "redirect", 
        return_url: returnUrl || "balanceapp://payment-return" 
      },
      save_payment_method: false
    };
  }

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

  // Возвращаем только необходимые поля для iOS
  return response(200, {
    status: data.status,
    payment_id: paymentId
  });
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
      status: payment.status,
      amount: payment.amount,
      description: payment.description
    });
    
    // Отложенные покупки больше не нужны - покупки создаются сразу при успешной оплате
    console.log("Payment succeeded - no pending purchase needed");
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

// MARK: - Админские функции
