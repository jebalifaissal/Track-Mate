-- Ensure the internal legacy merchant FK has a valid profile.
INSERT OR IGNORE INTO merchant_profiles (user_id, store_name, description, address, latitude, longitude, is_open)
VALUES ('trackmate-platform', 'Track-Mate Platform', 'Internal system account', 'Tunisie', 0, 0, 0);
