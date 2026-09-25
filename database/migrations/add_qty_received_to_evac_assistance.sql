-- Actual quantity received at the evacuation center, captured when the
-- barangay confirms a Delivered donation. NULL until confirmed; afterwards
-- holds the counted amount (1 .. the donor's declared qty), which is what
-- reduces the need. A shortfall reopens the remaining need automatically.
ALTER TABLE `evac_assistance`
  ADD COLUMN `qty_received` int(11) DEFAULT NULL AFTER `qty`;