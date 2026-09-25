-- OBILAK — Ibajay Barangay Chairman Hotlines
-- Adds the 35 Ibajay barangay chairman emergency contacts (from
-- TODO/Ibajay_chairman_contacts.txt) as Barangay-scoped hotlines.
-- Run ONCE on the capstone database.

INSERT INTO `emergency_hotlines`
  (`hotline_scope`, `barangay_id`, `office_name`, `municipality`, `category`, `cellphone_numbers`, `status`)
VALUES
('Barangay', 32, 'Ibajay_Agbago - 09942047568', 'Ibajay', 'Barangay', '09942047568', 'Active'),
('Barangay', 29, 'Ibajay_Agdugayan - 09380118036', 'Ibajay', 'Barangay', '09380118036', 'Active'),
('Barangay', 44, 'Ibajay_Antipolo - 09274895236', 'Ibajay', 'Barangay', '09274895236', 'Active'),
('Barangay', 22, 'Ibajay_Aparicio - 09811569784', 'Ibajay', 'Barangay', '09811569784', 'Active'),
('Barangay', 19, 'Ibajay_Aquino - 09291872147', 'Ibajay', 'Barangay', '09291872147', 'Active'),
('Barangay', 20, 'Ibajay_Aslum - 09984566799', 'Ibajay', 'Barangay', '09984566799', 'Active'),
('Barangay', 48, 'Ibajay_Bagacay - 09073809785', 'Ibajay', 'Barangay', '09073809785', 'Active'),
('Barangay', 50, 'Ibajay_Batuan - 09088759273', 'Ibajay', 'Barangay', '09088759273', 'Active'),
('Barangay', 41, 'Ibajay_Buenavista - 09515871575', 'Ibajay', 'Barangay', '09515871575', 'Active'),
('Barangay', 17, 'Ibajay_Bugtong Bato - 09388210266', 'Ibajay', 'Barangay', '09388210266', 'Active'),
('Barangay', 27, 'Ibajay_Cabugao - 09466725377', 'Ibajay', 'Barangay', '09466725377', 'Active'),
('Barangay', 51, 'Ibajay_Capilijan - 09216621858', 'Ibajay', 'Barangay', '09216621858', 'Active'),
('Barangay', 34, 'Ibajay_Colongcolong - 09199650246', 'Ibajay', 'Barangay', '09199650246', 'Active'),
('Barangay', 42, 'Ibajay_Laguinbanwa - 09455511336', 'Ibajay', 'Barangay', '09455511336', 'Active'),
('Barangay', 31, 'Ibajay_Mabusao - 09814954894', 'Ibajay', 'Barangay', '09814954894', 'Active'),
('Barangay', 23, 'Ibajay_Malindog - 09517826101', 'Ibajay', 'Barangay', '09517826101', 'Active'),
('Barangay', 40, 'Ibajay_Maloco - 09818137699', 'Ibajay', 'Barangay', '09818137699', 'Active'),
('Barangay', 21, 'Ibajay_Mina-A - 09630360561', 'Ibajay', 'Barangay', '09630360561', 'Active'),
('Barangay', 24, 'Ibajay_Monalaque - 09237462676', 'Ibajay', 'Barangay', '09237462676', 'Active'),
('Barangay', 28, 'Ibajay_Naile - 09814978911', 'Ibajay', 'Barangay', '09814978911', 'Active'),
('Barangay', 35, 'Ibajay_Naisud - 09237473564', 'Ibajay', 'Barangay', '09237473564', 'Active'),
('Barangay', 45, 'Ibajay_Naligusan - 09382560613', 'Ibajay', 'Barangay', '09382560613', 'Active'),
('Barangay', 37, 'Ibajay_Ondoy - 09914769434', 'Ibajay', 'Barangay', '09914769434', 'Active'),
('Barangay', 33, 'Ibajay_Poblacion - 09484675060', 'Ibajay', 'Barangay', '09484675060', 'Active'),
('Barangay', 39, 'Ibajay_Polo - 09634634233', 'Ibajay', 'Barangay', '09634634233', 'Active'),
('Barangay', 30, 'Ibajay_Regador - 09237474759', 'Ibajay', 'Barangay', '09237474759', 'Active'),
('Barangay', 25, 'Ibajay_Rivera - 09622851602', 'Ibajay', 'Barangay', '09622851602', 'Active'),
('Barangay', 46, 'Ibajay_Rizal - 09999944982', 'Ibajay', 'Barangay', '09999944982', 'Active'),
('Barangay', 38, 'Ibajay_San Isidro - 09104724377', 'Ibajay', 'Barangay', '09104724377', 'Active'),
('Barangay', 26, 'Ibajay_San Jose - 09303333073', 'Ibajay', 'Barangay', '09303333073', 'Active'),
('Barangay', 49, 'Ibajay_Santa Cruz - 09461349769', 'Ibajay', 'Barangay', '09461349769', 'Active'),
('Barangay', 36, 'Ibajay_Tagbaya - 09123261032', 'Ibajay', 'Barangay', '09123261032', 'Active'),
('Barangay', 43, 'Ibajay_Tul-Ang - 09630352874', 'Ibajay', 'Barangay', '09630352874', 'Active'),
('Barangay', 47, 'Ibajay_Unat - 09123083555', 'Ibajay', 'Barangay', '09123083555', 'Active'),
('Barangay', 18, 'Ibajay_Yawan - 09667158570', 'Ibajay', 'Barangay', '09667158570', 'Active');
