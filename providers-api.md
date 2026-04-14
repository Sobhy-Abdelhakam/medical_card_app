# Arabic & English Providers API Reference

This guide covers the endpoints that power name/type lookups and coordinate retrieval for both Arabic and English providers. All requests require a valid JWT access token unless your deployment explicitly allows public reads.

---

## Quickstart: Top Providers & Branch Lookup

### 1. Get Top Providers

Returns a lightweight list for the home screen cards.

**Endpoint**  
`GET https://providers.euro-assist.com/api/top-providers`

**Sample Response**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name_english": "AlBorg Labs",
      "name_arabic": "البرج",
      "type_en": "laboratory",
      "type_ar": "معامل التحاليل",
      "logo_url": "https://providers.euro-assist.com/uploads/logos/1753630875_البرج.png"
    },
    {
      "id": 2,
      "name_english": "Al-Mokhtabar",
      "name_arabic": "المختبر",
      "type_en": "laboratory",
      "type_ar": "معامل التحاليل",
      "logo_url": "https://providers.euro-assist.com/uploads/logos/1757333285_876a26cb-d50c-4dbb-931c-5d857e71a174.png"
    }
  ]
}
```

### 2. Get Specific Provider (Paginated)

Fetch a provider's branches by exact Arabic `searchName` plus optional `type`. When `paginate=1` the response wraps the payload with pagination metadata.

**Endpoint**  
`GET https://providers.euro-assist.com/api/arabic-providers?searchName=<NAME>&type=<TYPE>&paginate=1&page=<PAGE>&per_page=<LIMIT>`

**Sample Request**

```
https://providers.euro-assist.com/api/arabic-providers?searchName=المختبر&type=معمل%20تحاليل&paginate=1&page=1&per_page=10
```

**Sample Response**

```json
{
  "success": true,
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total": 7,
    "last_page": 1
  },
  "data": [
    {
      "id": 2,
      "name": "المختبر",
      "type": "معامل التحاليل",
      "address": "مدينة نصر - شارع الطيران",
      "district": "حي شرق مدينة نصر",
      "discount_pct": "خصم من 30% إلى 60%",
      "phone": "19014",
      "city": "القاهرة",
      "map_url": "https://www.google.com/maps/dir/?api=1&destination=30.061816,31.330077",
      "logo_path": "uploads/logos/1757333285_876a26cb-d50c-4dbb-931c-5d857e71a174.png",
      "specialization": null,
      "package": null
    }
  ]
}
```

### 3. Server-Side Filtering by Address / City / Phone

Add the `search` query parameter for fuzzy filtering (city, district, address, phone) before results reach the client. Works with pagination for larger datasets.

**Endpoint**  
`GET https://providers.euro-assist.com/api/arabic-providers?searchName=<NAME>&type=<TYPE>&search=<FILTER>&paginate=1&page=<PAGE>&per_page=<LIMIT>`

**Sample Request**

```
https://providers.euro-assist.com/api/arabic-providers?searchName=المختبر&type=معمل%20تحاليل&search=مدينة%20نصر&paginate=1&page=1&per_page=10
```

**Sample Response**

```json
{
  "success": true,
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total": 7,
    "last_page": 1
  },
  "data": [
    {
      "id": 301,
      "name": "المختبر",
      "type": "معامل التحاليل",
      "address": "مدينة نصر - النادي الاهلي",
      "city": "القاهرة الكبري",
      "district": "حي شرق مدينة نصر",
      "discount_pct": "خصم  من 30% الي 60%",
      "phone": "19014",
      "map_url": "https://www.google.com/maps/dir/?api=1&destination=30.0680414,31.3674293",
      "logo_path": "uploads/logos/laboratories.png"
    },
    {
      "id": 306,
      "name": "المختبر",
      "type": "معامل التحاليل",
      "address": "احمد الزمر - الحي العاشر - مدينة نصر - محافظة القاهرة",
      "city": "القاهرة الكبري",
      "district": "حي شرق مدينة نصر",
      "discount_pct": "خصم  من 30% الي 60%",
      "phone": "19014",
      "map_url": "https://www.google.com/maps/dir/?api=1&destination=30.047337,31.3638407",
      "logo_path": "uploads/logos/laboratories.png"
    },
    {
      "id": 307,
      "name": "المختبر",
      "type": "معامل التحاليل",
      "address": "63 شارع اسماء فهمي - ارض الجولف - مدينة نصر - القاهرة",
      "city": "القاهرة الكبري",
      "district": "حي شرق مدينة نصر",
      "discount_pct": "خصم  من 30% الي 60%",
      "phone": "19014",
      "map_url": "https://www.google.com/maps/dir/?api=1&destination=30.0794957,31.3359838",
      "logo_path": "uploads/logos/laboratories.png"
    }
  ]
}
```

**Implementation Notes**

- Call `/top-providers` for the summary grid.
- When a card is tapped, request `/arabic-providers` with `searchName`, `type`, `paginate`, `page`, and `per_page`.
- Optional `search` refines branches (city, area, phone) before the data hits the client.
- Branch objects use snake_case keys (`name`, `type`, `discount_pct`, `map_url`, `logo_path`, ...); keep client models aligned with these fields.
- Update the UI to handle pagination (`current_page`, `last_page`) and avoid duplicate refreshes to reduce `فشل تحميل البيانات` errors.

---

## 1. Retrieve All Providers with Coordinates

### Arabic Providers

**Endpoint**  
`GET /api/arabic-providers/all-latlng`

**Purpose**  
Returns every Arabic provider along with its type and latitude/longitude values—ideal for map markers.

**Headers**

- `Authorization: Bearer <access_token>`
- `Accept: application/json`

**Sample Request**

```http
GET https://providers.euro-assist.com/api/arabic-providers/all-latlng
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Success Response**

```json
{
  "data": [
    {
      "name": "مستشفى الياسمين",
      "type": "مستشفى",
      "latitude": 30.0532,
      "longitude": 31.2357
    },
    {
      "name": "معمل التحاليل الحديث",
      "type": "معامل التحاليل",
      "latitude": 29.9765,
      "longitude": 31.1313
    }
  ]
}
```

**Error Responses**

```json
// 401 – missing or invalid token
{
  "message": "Unauthenticated."
}
```

---

### English Providers

**Endpoint**  
`GET /api/providers/all-latlng`

**Purpose**  
Provides the same structure as the Arabic variant but for the English dataset.

**Headers**

- `Authorization: Bearer <access_token>`
- `Accept: application/json`

**Sample Request**

```http
GET https://providers.euro-assist.com/api/providers/all-latlng
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Success Response**

```json
{
  "data": [
    {
      "name": "Yasmine Hospital",
      "type": "hospital",
      "latitude": 30.0532,
      "longitude": 31.2357
    },
    {
      "name": "Modern Labs",
      "type": "laboratory",
      "latitude": 29.9765,
      "longitude": 31.1313
    }
  ]
}
```

**Error Responses**

```json
// 401 – missing or invalid token
{
  "message": "Unauthenticated."
}
```

**Notes (both endpoints)**

- No query parameters are supported; each call returns the full list.
- Latitude/longitude values are derived from the `lat_lng` column via controller logic.

---

## 2. Exact Name + Type Search (Branches Lookup)

Both Arabic and English provider lists expose the same filtering contract. Supply an exact `searchName` plus an optional `type` to narrow results to a single provider’s branches—as used by `top-providers.php` when opening the branch modal.

### Arabic Providers

**Endpoint**  
`GET /api/arabic-providers`

**Query Parameters**

- `searchName` _(required)_ – Exact match, whitespace-normalized server-side.
- `type` _(optional but recommended)_ – Partial match on provider type (`عيادة`, `مستشفى`, …).
- Other optional filters: `city`, `governorate`, `district`, `search`.
- `paginate` _(optional)_ – Set to `1` to receive paginated metadata.
- `page` & `per_page` _(optional, used with `paginate=1`)_ – Page number (default `1`) and results per page (default `25`, must be > 0).

**Sample Request**

```http
GET https://providers.euro-assist.com/api/arabic-providers?searchName=مستشفى%20الياسمين&type=مستشفى
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Paginated Example**

```http
GET https://providers.euro-assist.com/api/arabic-providers?searchName=مستشفى%20الياسمين&type=مستشفى&paginate=1&page=1&per_page=10
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Filter In-Place (No Pagination)**

```http
GET https://providers.euro-assist.com/api/arabic-providers?searchName=المختبر&type=معمل%20تحاليل&search=مدينة%20نصر
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

Omit `paginate` entirely to receive the full branch list as a plain array, then optionally use `search`, `city`, `district`, or `governorate` to narrow the results server-side. Any additional filtering (e.g., partial matches on phone numbers) can be done client-side after the array is returned.

**Sample Response**

```json
[
  {
    "id": 812,
    "name": "مستشفى الياسمين",
    "type": "مستشفى",
    "specialization": "باطنة",
    "city": "القاهرة",
    "district": "المعادى",
    "address": "شارع النصر، عمارة 12",
    "discount_pct": "10%",
    "hours": "24/7",
    "phone": "0100 123 4567 / 0120 765 4321",
    "email": "info@yasmine-hospital.eg",
    "website": "https://yasmine-hospital.eg",
    "map_url": "https://maps.google.com/?q=30.0532,31.2357",
    "package": "Premium",
    "latitude": 30.0532,
    "longitude": 31.2357,
    "created_at": "2025-08-12T09:41:25.000000Z",
    "updated_at": "2025-09-03T14:12:47.000000Z"
  }
]
```

**Error Responses**

```json
// 200 OK – no matches
[]

// 401 – missing or invalid token
{
    "message": "Unauthenticated."
}
```

---

### English Providers

**Endpoint**  
`GET /api/providers`

**Query Parameters**

- `searchName` _(required)_ – Exact match on the English provider name (spaces normalized).
- `type` _(optional)_ – Partial match on English type (`hospital`, `clinic`, etc.).
- Additional filters: `city`, `governorate`, `district`, `search`, `is_translated`.
- `paginate` _(optional)_ – Set to `1` to receive paginated metadata.
- `page` & `per_page` _(optional, used with `paginate=1`)_ – Page number (default `1`) and results per page (default `25`, must be > 0).

**Sample Request**

```http
GET https://providers.euro-assist.com/api/providers?searchName=Yasmine%20Hospital&type=hospital
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Paginated Example**

```http
GET https://providers.euro-assist.com/api/providers?searchName=Yasmine%20Hospital&type=hospital&paginate=1&page=1&per_page=10
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

**Filter In-Place (No Pagination)**

```http
GET https://providers.euro-assist.com/api/providers?searchName=AlBorg%20Labs&type=laboratory&search=Nasr%20City
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

As with the Arabic endpoint, omitting `paginate` returns the entire branch collection in one array. Combine `search`, `city`, `district`, `governorate`, and (for English data) `is_translated` to trim the list before it reaches the client; apply any remaining fine-grained filters locally.

**Sample Response**

```json
[
  {
    "id": 412,
    "name": "Yasmine Hospital",
    "type": "hospital",
    "specialization": "Internal Medicine",
    "city": "Cairo",
    "district": "Maadi",
    "address": "12 Al Nasr Street",
    "discount_pct": "10%",
    "hours": "24/7",
    "phone": "0100 123 4567 / 0120 765 4321",
    "email": "info@yasmine-hospital.com",
    "website": "https://yasmine-hospital.com",
    "map_url": "https://maps.google.com/?q=30.0532,31.2357",
    "package": "Premium",
    "latitude": 30.0532,
    "longitude": 31.2357,
    "created_at": "2025-08-12T09:41:25.000000Z",
    "updated_at": "2025-09-03T14:12:47.000000Z"
  }
]
```

**Error Responses**

```json
// 200 OK – no matches
[]

// 401 – missing or invalid token
{
    "message": "Unauthenticated."
}
```

**Shared Notes**

- `searchName` normalization collapses multiple spaces, ensuring `Yasmine  Hospital` matches `Yasmine Hospital`.
- Pairing `searchName` with `type` minimizes ambiguous hits when names span multiple categories.
- Responses default to the legacy plain array for backward compatibility; add `paginate=1` (plus optional `page`/`per_page`) to receive pagination metadata.

---

## 3. Free-Form Search (New)

Use these endpoints when you need fuzzy matching beyond an exact `searchName`. The `query` parameter searches across name, type, specialization, address, city, district, governorate, phone, email, website, package, and discount fields. Results are paginated just like the lookups above and accept the same optional filters (`type`, `city`, `district`, `governorate`, `is_translated`—English only) plus `page`/`per_page`.

### Arabic Providers

**Endpoint**  
`GET /api/arabic-providers/search`

```http
GET https://providers.euro-assist.com/api/arabic-providers/search?query=المعادى&type=مستشفى&page=1&per_page=25
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

```json
{
  "data": [
    {
      "id": 912,
      "name": "مستشفى السلام",
      "type": "مستشفى",
      "city": "القاهرة",
      "district": "المعادى",
      "address": "شارع اللاسلكى",
      "phone": "02-1234-5678",
      "latitude": 29.965,
      "longitude": 31.2801,
      "package": "Premium",
      "discount_pct": "15%",
      "created_at": "2025-07-22T10:15:44.000000Z",
      "updated_at": "2025-09-01T08:31:27.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 2,
    "per_page": 25,
    "total": 27,
    "from": 1,
    "to": 25
  },
  "links": {
    "self": "https://providers.euro-assist.com/api/arabic-providers/search?query=%D8%A7%D9%84%D9%85%D8%B9%D8%A7%D8%AF%D9%89&type=%D9%85%D8%B3%D8%AA%D8%B4%D9%81%D9%89&page=1&per_page=25",
    "next": "https://providers.euro-assist.com/api/arabic-providers/search?query=%D8%A7%D9%84%D9%85%D8%B9%D8%A7%D8%AF%D9%89&type=%D9%85%D8%B3%D8%AA%D8%B4%D9%81%D9%89&page=2&per_page=25",
    "prev": null
  }
}
```

**Validation Errors**

```json
// 422 – missing query parameter
{
  "message": "Validation error.",
  "errors": {
    "query": ["The query parameter is required."]
  }
}
```

### English Providers

**Endpoint**  
`GET /api/providers/search`

```http
GET https://providers.euro-assist.com/api/providers/search?query=Maadi&type=hospital&is_translated=1&page=1&per_page=50
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/json
```

```json
{
  "data": [
    {
      "id": 422,
      "name": "Yasmine Hospital",
      "type": "hospital",
      "city": "Cairo",
      "district": "Maadi",
      "address": "12 Al Nasr Street",
      "phone": "0100 123 4567",
      "email": "info@yasmine-hospital.com",
      "website": "https://yasmine-hospital.com",
      "package": "Premium",
      "discount_pct": "10%",
      "is_translated": 1,
      "latitude": 30.0532,
      "longitude": 31.2357,
      "created_at": "2025-08-12T09:41:25.000000Z",
      "updated_at": "2025-09-03T14:12:47.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 3,
    "per_page": 50,
    "total": 102,
    "from": 1,
    "to": 50
  },
  "links": {
    "self": "https://providers.euro-assist.com/api/providers/search?query=Maadi&type=hospital&is_translated=1&page=1&per_page=50",
    "next": "https://providers.euro-assist.com/api/providers/search?query=Maadi&type=hospital&is_translated=1&page=2&per_page=50",
    "prev": null
  }
}
```

**Validation Errors**

```json
// 422 – missing query parameter
{
  "message": "Validation error.",
  "errors": {
    "query": ["The query parameter is required."]
  }
}
```

---

### Quick Testing Checklist

1. Authenticate via `POST /api/login` and copy the `access_token`.
2. Include `Authorization: Bearer <token>` for every call.
3. Remove the header only if your deployment toggles public access.
4. Keep `Accept: application/json` to force JSON responses.
