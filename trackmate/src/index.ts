interface Env {
  DB: D1Database;
  API_ORIGIN?: string;
}

type AppRole = "client" | "driver";
type AuthUser = { id: string; full_name: string; email: string; phone: string | null; role: AppRole };

const encoder = new TextEncoder();
const SESSION_DAYS = 30;
const PASSWORD_ITERATIONS = 210_000;

function json(data: unknown, status = 200, request?: Request): Response {
  const origin = request?.headers.get("Origin") ?? "*";
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
      "Vary": "Origin",
      "Cache-Control": "no-store",
    },
  });
}

function fail(message: string, status = 400, request?: Request): Response {
  return json({ error: message }, status, request);
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function randomToken(byteLength = 32): string {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return bytesToBase64(new Uint8Array(digest));
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: PASSWORD_ITERATIONS, hash: "SHA-256" },
    key,
    256,
  );
  return `pbkdf2$${PASSWORD_ITERATIONS}$${bytesToBase64(salt)}$${bytesToBase64(new Uint8Array(bits))}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [algorithm, iterationsText, saltText, hashText] = stored.split("$");
  if (algorithm !== "pbkdf2" || !iterationsText || !saltText || !hashText) return false;
  const iterations = Number(iterationsText);
  if (!Number.isInteger(iterations) || iterations < 100_000 || iterations > 1_000_000) return false;
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt: base64ToBytes(saltText), iterations, hash: "SHA-256" },
    key,
    256,
  );
  const actual = new Uint8Array(bits);
  const expected = base64ToBytes(hashText);
  if (actual.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < actual.length; index++) difference |= actual[index] ^ expected[index];
  return difference === 0;
}

async function readBody<T>(request: Request): Promise<T | null> {
  try { return await request.json() as T; } catch { return null; }
}

async function authenticate(request: Request, env: Env): Promise<AuthUser | null> {
  const header = request.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) return null;
  const tokenHash = await sha256(token);
  const row = await env.DB.prepare(`
    SELECT u.id, u.full_name, u.email, u.phone, r.role
    FROM sessions s
    JOIN users u ON u.id = s.user_id
    JOIN user_roles r ON r.user_id = u.id
    WHERE s.token_hash = ? AND s.expires_at > datetime('now') AND u.is_active = 1
      AND r.role IN ('client', 'driver')
    LIMIT 1
  `).bind(tokenHash).first<AuthUser>();
  return row ?? null;
}

async function createSession(userId: string, env: Env): Promise<string> {
  const token = randomToken();
  const tokenHash = await sha256(token);
  const id = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO sessions (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, datetime('now', ?))",
  ).bind(id, userId, tokenHash, `+${SESSION_DAYS} days`).run();
  return token;
}

async function notifyDrivers(env: Env, orderId: string): Promise<void> {
  const drivers = await env.DB.prepare(
    "SELECT user_id FROM user_roles WHERE role = 'driver'",
  ).all<{ user_id: string }>();
  for (const driver of drivers.results) {
    await env.DB.prepare(
      "INSERT INTO notifications (id, user_id, title, message, type, is_read, created_at) VALUES (?, ?, ?, ?, ?, 0, datetime('now'))",
    ).bind(crypto.randomUUID(), driver.user_id, "Nouvelle livraison", `Une nouvelle commande ${orderId} est disponible.`, "new_order").run();
  }
}

async function handle(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  if (request.method === "OPTIONS") return json({}, 200, request);
  if (path === "/api/health" && request.method === "GET") return json({ ok: true, service: "trackmate-api" }, 200, request);

  if (path === "/api/auth/register" && request.method === "POST") {
    const body = await readBody<{ fullName?: string; email?: string; phone?: string; password?: string; role?: AppRole }>(request);
    if (!body) return fail("Invalid JSON body.", 400, request);
    const fullName = body.fullName?.trim() ?? "";
    const email = body.email?.trim().toLowerCase() ?? "";
    const phone = body.phone?.trim() || null;
    const password = body.password ?? "";
    const role = body.role;
    if (fullName.length < 2 || fullName.length > 100) return fail("Nom invalide.", 422, request);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 190) return fail("Adresse e-mail invalide.", 422, request);
    if (password.length < 10 || password.length > 128) return fail("Le mot de passe doit contenir au moins 10 caractères.", 422, request);
    if (role !== "client" && role !== "driver") return fail("Rôle non autorisé.", 422, request);
    const id = crypto.randomUUID();
    const passwordHash = await hashPassword(password);
    try {
      await env.DB.prepare(
        "INSERT INTO users (id, full_name, email, phone, password_hash, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, datetime('now'), datetime('now'))",
      ).bind(id, fullName, email, phone, passwordHash).run();
      await env.DB.prepare("INSERT INTO user_roles (user_id, role) VALUES (?, ?)").bind(id, role).run();
      return json({
        message: "Compte créé avec succès. Connectez-vous pour continuer.",
        user: { id, full_name: fullName, email, phone, role },
      }, 201, request);
    } catch (error) {
      const message = String(error);
      if (message.includes("UNIQUE")) return fail("Cet e-mail ou numéro est déjà utilisé.", 409, request);
      throw error;
    }
  }

  if (path === "/api/auth/login" && request.method === "POST") {
    const body = await readBody<{ email?: string; password?: string; role?: AppRole }>(request);
    if (!body?.email || !body.password) return fail("E-mail et mot de passe obligatoires.", 422, request);
    const row = await env.DB.prepare(`
      SELECT u.id, u.full_name, u.email, u.phone, u.password_hash, r.role
      FROM users u JOIN user_roles r ON r.user_id = u.id
      WHERE lower(u.email) = ? AND u.is_active = 1 AND r.role IN ('client', 'driver')
      LIMIT 1
    `).bind(body.email.trim().toLowerCase()).first<AuthUser & { password_hash: string }>();
    if (!row || (body.role && body.role !== row.role) || !(await verifyPassword(body.password, row.password_hash))) {
      return fail("Identifiants incorrects.", 401, request);
    }
    const token = await createSession(row.id, env);
    return json({ token, user: { id: row.id, full_name: row.full_name, email: row.email, phone: row.phone, role: row.role } }, 200, request);
  }

  const user = await authenticate(request, env);
  if (!user) return fail("Session invalide ou expirée.", 401, request);

  if (path === "/api/auth/me" && request.method === "GET") return json({ user }, 200, request);
  if (path === "/api/auth/logout" && request.method === "POST") {
    const token = (request.headers.get("Authorization") ?? "").slice(7).trim();
    await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await sha256(token)).run();
    return json({ ok: true }, 200, request);
  }

  if (path === "/api/orders" && request.method === "GET") {
    const rows = user.role === "client"
      ? await env.DB.prepare(`
          SELECT o.*, d.status AS delivery_status, d.driver_id
          FROM orders o LEFT JOIN deliveries d ON d.order_id = o.id
          WHERE o.client_id = ? ORDER BY o.created_at DESC LIMIT 100
        `).bind(user.id).all()
      : await env.DB.prepare(`
          SELECT o.*, d.status AS delivery_status, d.driver_id
          FROM orders o LEFT JOIN deliveries d ON d.order_id = o.id
          WHERE (o.status = 'pending' AND o.driver_id IS NULL) OR o.driver_id = ?
          ORDER BY o.created_at DESC LIMIT 100
        `).bind(user.id).all();
    return json({ orders: rows.results }, 200, request);
  }

  if (path === "/api/orders" && request.method === "POST") {
    if (user.role !== "client") return fail("Seul un client peut créer une commande.", 403, request);
    const body = await readBody<{
      itemDescription?: string; pickupAddress?: string; pickupLatitude?: number; pickupLongitude?: number;
      deliveryAddress?: string; deliveryLatitude?: number; deliveryLongitude?: number; deliveryFee?: number;
    }>(request);
    if (!body) return fail("Invalid JSON body.", 400, request);
    const pickupAddress = body.pickupAddress?.trim() ?? "";
    const deliveryAddress = body.deliveryAddress?.trim() ?? "";
    const itemDescription = body.itemDescription?.trim() ?? "";
    const coords = [body.pickupLatitude, body.pickupLongitude, body.deliveryLatitude, body.deliveryLongitude];
    if (!itemDescription || itemDescription.length > 500 || !pickupAddress || !deliveryAddress ||
        coords.some((value) => typeof value !== "number" || !Number.isFinite(value))) {
      return fail("Description, adresses et coordonnées GPS sont obligatoires.", 422, request);
    }
    const [pickupLat, pickupLng, deliveryLat, deliveryLng] = coords as number[];
    if (Math.abs(pickupLat) > 90 || Math.abs(deliveryLat) > 90 || Math.abs(pickupLng) > 180 || Math.abs(deliveryLng) > 180) {
      return fail("Coordonnées GPS invalides.", 422, request);
    }
    const fee = typeof body.deliveryFee === "number" && body.deliveryFee >= 0 && body.deliveryFee <= 1000 ? body.deliveryFee : 0;
    const id = `TM-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
    await env.DB.prepare(`
      INSERT INTO orders
        (id, client_id, merchant_id, driver_id, address_id, status, subtotal, delivery_fee, total_amount, notes,
         pickup_address, pickup_latitude, pickup_longitude, delivery_address, delivery_latitude, delivery_longitude,
         item_description, created_at, updated_at)
      VALUES (?, ?, 'trackmate-platform', NULL, NULL, 'pending', 0, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
    `).bind(id, user.id, fee, fee, pickupAddress, pickupLat, pickupLng, deliveryAddress, deliveryLat, deliveryLng, itemDescription).run();
    await env.DB.prepare(
      "INSERT INTO deliveries (id, order_id, driver_id, status, created_at, updated_at) VALUES (?, ?, NULL, 'waiting', datetime('now'), datetime('now'))",
    ).bind(crypto.randomUUID(), id).run();
    await notifyDrivers(env, id);
    return json({ order: { id, status: "pending", item_description: itemDescription } }, 201, request);
  }

  const acceptMatch = path.match(/^\/api\/orders\/([^/]+)\/accept$/);
  if (acceptMatch && request.method === "POST") {
    if (user.role !== "driver") return fail("Accès réservé aux livreurs.", 403, request);
    const orderId = decodeURIComponent(acceptMatch[1]);
    const result = await env.DB.prepare(
      "UPDATE orders SET driver_id = ?, status = 'assigned', updated_at = datetime('now') WHERE id = ? AND status = 'pending' AND driver_id IS NULL",
    ).bind(user.id, orderId).run();
    if (!result.meta.changes) return fail("Cette commande n'est plus disponible.", 409, request);
    await env.DB.prepare(
      "UPDATE deliveries SET driver_id = ?, status = 'assigned', updated_at = datetime('now') WHERE order_id = ?",
    ).bind(user.id, orderId).run();
    return json({ ok: true, status: "assigned" }, 200, request);
  }

  const statusMatch = path.match(/^\/api\/orders\/([^/]+)\/status$/);
  if (statusMatch && request.method === "PATCH") {
    if (user.role !== "driver") return fail("Accès réservé aux livreurs.", 403, request);
    const body = await readBody<{ status?: string }>(request);
    const next = body?.status;
    if (!["picked_up", "in_transit", "delivered"].includes(next ?? "")) return fail("Statut invalide.", 422, request);
    const orderId = decodeURIComponent(statusMatch[1]);
    const result = await env.DB.prepare(
      "UPDATE orders SET status = ?, updated_at = datetime('now') WHERE id = ? AND driver_id = ? AND status IN ('assigned', 'picked_up', 'in_transit')",
    ).bind(next, orderId, user.id).run();
    if (!result.meta.changes) return fail("Commande introuvable ou transition non autorisée.", 409, request);
    await env.DB.prepare(
      "UPDATE deliveries SET status = ?, picked_up_at = CASE WHEN ? = 'picked_up' THEN datetime('now') ELSE picked_up_at END, delivered_at = CASE WHEN ? = 'delivered' THEN datetime('now') ELSE delivered_at END, updated_at = datetime('now') WHERE order_id = ? AND driver_id = ?",
    ).bind(next, next, next, orderId, user.id).run();
    return json({ ok: true, status: next }, 200, request);
  }

  const locationMatch = path.match(/^\/api\/orders\/([^/]+)\/location$/);
  if (locationMatch && request.method === "POST") {
    if (user.role !== "driver") return fail("Accès réservé aux livreurs.", 403, request);
    const body = await readBody<{ latitude?: number; longitude?: number; heading?: number; speed?: number }>(request);
    if (typeof body?.latitude !== "number" || typeof body.longitude !== "number" ||
        !Number.isFinite(body.latitude) || !Number.isFinite(body.longitude) ||
        Math.abs(body.latitude) > 90 || Math.abs(body.longitude) > 180) return fail("Position GPS invalide.", 422, request);
    const orderId = decodeURIComponent(locationMatch[1]);
    const owned = await env.DB.prepare("SELECT id FROM orders WHERE id = ? AND driver_id = ? AND status IN ('assigned', 'picked_up', 'in_transit')").bind(orderId, user.id).first();
    if (!owned) return fail("Livraison active introuvable.", 404, request);
    const heading = typeof body.heading === "number" ? body.heading : null;
    const speed = typeof body.speed === "number" ? body.speed : null;
    await env.DB.prepare(`
      INSERT INTO driver_locations (driver_id, latitude, longitude, heading, speed, updated_at)
      VALUES (?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(driver_id) DO UPDATE SET latitude=excluded.latitude, longitude=excluded.longitude,
        heading=excluded.heading, speed=excluded.speed, updated_at=datetime('now')
    `).bind(user.id, body.latitude, body.longitude, heading, speed).run();
    await env.DB.prepare(
      "INSERT INTO driver_location_history (driver_id, latitude, longitude, recorded_at) VALUES (?, ?, ?, datetime('now'))",
    ).bind(user.id, body.latitude, body.longitude).run();
    return json({ ok: true }, 200, request);
  }

  const trackingMatch = path.match(/^\/api\/orders\/([^/]+)\/location$/);
  if (trackingMatch && request.method === "GET") {
    if (user.role !== "client") return fail("Accès réservé au client.", 403, request);
    const orderId = decodeURIComponent(trackingMatch[1]);
    const location = await env.DB.prepare(`
      SELECT l.latitude, l.longitude, l.heading, l.speed, l.updated_at, o.status
      FROM orders o JOIN driver_locations l ON l.driver_id = o.driver_id
      WHERE o.id = ? AND o.client_id = ?
    `).bind(orderId, user.id).first();
    if (!location) return fail("Position du livreur indisponible.", 404, request);
    return json({ location }, 200, request);
  }

  return fail("Route introuvable.", 404, request);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env);
    } catch (error) {
      console.error("Track-Mate API error:", error);
      return fail("Erreur interne du serveur.", 500, request);
    }
  },
} satisfies ExportedHandler<Env>;
