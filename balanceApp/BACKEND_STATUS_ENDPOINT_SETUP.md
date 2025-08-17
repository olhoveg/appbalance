# Настройка эндпоинта /payments/status для YooKassa

## Проблема
В вашем бэкенде отсутствует эндпоинт `/payments/status`, который необходим для проверки статуса платежа после подтверждения (3DS/SBP).

## Текущее состояние
- ✅ `/payments/create` - работает отлично
- ❌ `/payments/status` - отсутствует (404)

## Решение

### 1. Добавьте новый маршрут в вашу функцию

В вашем handler добавьте следующий код:

```javascript
// Добавить в ваш handler новый маршрут
if (event.httpMethod === 'GET' && event.path === '/payments/status') {
    const paymentId = event.queryStringParameters?.payment_id;
    if (!paymentId) {
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'payment_id is required' })
        };
    }
    
    // Проксируем запрос к YooKassa API
    const response = await fetch(`https://api.yookassa.ru/v3/payments/${paymentId}`, {
        method: 'GET',
        headers: {
            'Authorization': `Basic ${Buffer.from(process.env.YK_SHOP_ID + ':' + process.env.YK_SECRET_KEY).toString('base64')}`,
            'Content-Type': 'application/json',
            'Idempotence-Key': uuid()
        }
    });
    
    const paymentData = await response.json();
    
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
            status: paymentData.status,
            payment_id: paymentId
        })
    };
}
```

### 2. Убедитесь, что у вас есть необходимые импорты

Если используете CommonJS:
```javascript
const { v4: uuid } = require('uuid');
```

Если используете ESM:
```javascript
import { v4 as uuid } from 'uuid';
```

### 3. Проверьте переменные окружения

Убедитесь, что в функции заданы переменные:
- `YK_SHOP_ID=773757`
- `YK_SECRET_KEY=<ваш_секретный_ключ>`

### 4. Тестирование

После добавления эндпоинта протестируйте его:

```bash
curl -i -X GET 'https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/payments/status?payment_id=30341352-000f-5000-8000-199eea528e7d'
```

Ожидаемый ответ:
```json
{
  "status": "pending",
  "payment_id": "30341352-000f-5000-8000-199eea528e7d"
}
```

## Временное решение в iOS

Пока вы добавляете эндпоинт, в iOS коде используется временное решение:
- Функция `fetchPaymentStatus` считает все платежи успешными
- Это позволяет тестировать основной функционал

## После добавления эндпоинта

1. Удалите временное решение из `YooKassaRealIntegration.swift`
2. Восстановите оригинальный код `fetchPaymentStatus`
3. Протестируйте полный цикл платежей

## Полный пример handler

```javascript
'use strict';
const { v4: uuid } = require('uuid');

exports.handler = async (event, context) => {
    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
    };

    // Handle OPTIONS request
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    // Handle GET /payments/status
    if (event.httpMethod === 'GET' && event.path === '/payments/status') {
        const paymentId = event.queryStringParameters?.payment_id;
        if (!paymentId) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'payment_id is required' })
            };
        }
        
        try {
            const response = await fetch(`https://api.yookassa.ru/v3/payments/${paymentId}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Basic ${Buffer.from(process.env.YK_SHOP_ID + ':' + process.env.YK_SECRET_KEY).toString('base64')}`,
                    'Content-Type': 'application/json',
                    'Idempotence-Key': uuid()
                }
            });
            
            const paymentData = await response.json();
            
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({
                    status: paymentData.status,
                    payment_id: paymentId
                })
            };
        } catch (error) {
            return {
                statusCode: 500,
                headers,
                body: JSON.stringify({ error: error.message })
            };
        }
    }

    // Handle POST /payments/create (ваш существующий код)
    if (event.httpMethod === 'POST' && event.path === '/payments/create') {
        // Ваш существующий код для создания платежа
    }

    return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ error: 'Not found' })
    };
};
```

## Проверка готовности

После добавления эндпоинта выполните:

```bash
# Тест создания платежа
curl -i -X POST 'https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/payments/create' \
  -H 'Content-Type: application/json' \
  -d '{"sdkToken":"test_token","amount":"10.00","description":"Test","returnUrl":"balanceapp://payment-return"}'

# Тест проверки статуса (используйте payment_id из предыдущего ответа)
curl -i -X GET 'https://d5dgl1ikvie8dgvombue.fary004x.apigw.yandexcloud.net/payments/status?payment_id=PAYMENT_ID_FROM_PREVIOUS_RESPONSE'
```

Если оба запроса возвращают 200, эндпоинт настроен правильно.
