-- Production foundation for the two-role Client / Driver application.
-- The existing schema requires orders.merchant_id. Keep that legacy FK valid
-- through a non-login platform account; this account is never exposed by the API.
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

ALTER TABLE orders ADD COLUMN pickup_address TEXT;
ALTER TABLE orders ADD COLUMN pickup_latitude REAL;
ALTER TABLE orders ADD COLUMN pickup_longitude REAL;
ALTER TABLE orders ADD COLUMN delivery_address TEXT;
ALTER TABLE orders ADD COLUMN delivery_latitude REAL;
ALTER TABLE orders ADD COLUMN delivery_longitude REAL;
ALTER TABLE orders ADD COLUMN item_description TEXT;

INSERT OR IGNORE INTO users
  (id, full_name, email, phone, password_hash, is_active, created_at, updated_at)
VALUES
  ('trackmate-platform', 'Track-Mate Platform', 'platform@internal.trackmate', NULL,
   'LOGIN_DISABLED', 1, datetime('now'), datetime('now'));
INSERT OR IGNORE INTO user_roles (user_id, role)
VALUES ('trackmate-platform', 'merchant');
