-- Barangay delivery confirmation for Needs & Assistance.
-- "Received" is NOT a new status enum value: a donation is considered received
-- when received_at IS NOT NULL (status stays 'Delivered' for donor-side history).
ALTER TABLE evac_assistance
  ADD COLUMN received_at timestamp NULL DEFAULT NULL AFTER delivered_at,
  ADD COLUMN confirmed_by_user_id int(11) DEFAULT NULL AFTER received_at,
  ADD KEY idx_received (received_at);