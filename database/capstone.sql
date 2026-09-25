-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Sep 24, 2026 at 06:37 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `capstone`
--

-- --------------------------------------------------------

--
-- Table structure for table `alerts`
--

CREATE TABLE `alerts` (
  `id` int(11) NOT NULL,
  `title` varchar(150) NOT NULL,
  `alert_type` varchar(100) NOT NULL,
  `severity` enum('Low','Moderate','High','Critical') DEFAULT 'Low',
  `message` text NOT NULL,
  `instructions` text DEFAULT NULL,
  `status` enum('Active','Inactive','Expired') DEFAULT 'Active',
  `start_datetime` datetime DEFAULT NULL,
  `end_datetime` datetime DEFAULT NULL,
  `target_type` varchar(30) NOT NULL DEFAULT 'all',
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `alert_barangays`
--

CREATE TABLE `alert_barangays` (
  `id` int(11) NOT NULL,
  `alert_id` int(11) NOT NULL,
  `barangay_id` int(11) NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `read_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `alert_reads`
--

CREATE TABLE `alert_reads` (
  `id` int(11) NOT NULL,
  `alert_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `barangay_id` int(11) NOT NULL,
  `read_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `barangays`
--

CREATE TABLE `barangays` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `municipality` varchar(100) DEFAULT 'Kalibo',
  `province` varchar(100) DEFAULT 'Aklan',
  `status` enum('Active','Inactive') DEFAULT 'Active',
  `latitude` decimal(12,9) DEFAULT NULL,
  `longitude` decimal(12,9) DEFAULT NULL,
  `population` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `barangays`
--

INSERT INTO `barangays` (`id`, `name`, `municipality`, `province`, `status`, `latitude`, `longitude`, `population`) VALUES
(1, 'Andagaw', 'Kalibo', 'Aklan', 'Active', 11.704276032, 122.375618950, 0),
(2, 'Bachaw Norte', 'Kalibo', 'Aklan', 'Active', 11.726927701, 122.368680476, 0),
(3, 'Bachaw Sur', 'Kalibo', 'Aklan', 'Active', 11.721959822, 122.374501481, 0),
(4, 'Briones', 'Kalibo', 'Aklan', 'Active', 11.670115328, 122.401951625, 0),
(5, 'Buswang New', 'Kalibo', 'Aklan', 'Active', 11.712092184, 122.380927039, 0),
(6, 'Buswang Old', 'Kalibo', 'Aklan', 'Active', 11.717329110, 122.376725627, 0),
(7, 'Caano', 'Kalibo', 'Aklan', 'Active', 11.679922720, 122.391350090, 0),
(8, 'Estancia', 'Kalibo', 'Aklan', 'Active', 11.687240525, 122.366352744, 0),
(9, 'Linabuan Norte', 'Kalibo', 'Aklan', 'Active', 11.667038891, 122.352282051, 0),
(10, 'Mabilo', 'Kalibo', 'Aklan', 'Active', 11.674876539, 122.405989822, 0),
(11, 'Mobo', 'Kalibo', 'Aklan', 'Active', 11.699813572, 122.358822912, 0),
(12, 'Nalook', 'Kalibo', 'Aklan', 'Active', 11.670215186, 122.381704965, 0),
(13, 'Poblacion', 'Kalibo', 'Aklan', 'Active', 11.706766247, 122.366301993, 0),
(14, 'Pook', 'Kalibo', 'Aklan', 'Active', 11.693186666, 122.384826952, 0),
(15, 'Tigayon', 'Kalibo', 'Aklan', 'Active', 11.673817070, 122.360510273, 0),
(16, 'Tinigaw', 'Kalibo', 'Aklan', 'Active', 11.708725490, 122.361911974, 0),
(17, 'Bugtong Bato', 'Ibajay', 'Aklan', 'Active', 11.803643579, 122.213054745, 0),
(18, 'Yawan', 'Ibajay', 'Aklan', 'Active', 11.647790723, 122.170712533, 324),
(19, 'Aquino', 'Ibajay', 'Aklan', 'Active', 11.809174975, 122.111607943, 0),
(20, 'Aslum', 'Ibajay', 'Aklan', 'Active', 11.823705844, 122.156864379, 1665),
(21, 'Mina-A', 'Ibajay', 'Aklan', 'Active', 11.665249724, 122.180532735, 0),
(22, 'Aparicio', 'Ibajay', 'Aklan', 'Active', 11.685963259, 122.183594631, 0),
(23, 'Malindog', 'Ibajay', 'Aklan', 'Active', 11.700985420, 122.184863756, 0),
(24, 'Monalaque', 'Ibajay', 'Aklan', 'Active', 11.712397399, 122.192085536, 0),
(25, 'Rivera', 'Ibajay', 'Aklan', 'Active', 11.731201977, 122.197606772, 300),
(26, 'San Jose', 'Ibajay', 'Aklan', 'Active', 11.731207024, 122.179103876, 0),
(27, 'Cabugao', 'Ibajay', 'Aklan', 'Active', 11.750203836, 122.195681197, 0),
(28, 'Naile', 'Ibajay', 'Aklan', 'Active', 11.757433426, 122.174797369, 0),
(29, 'Agdugayan', 'Ibajay', 'Aklan', 'Active', 11.766122360, 122.156239665, 0),
(30, 'Regador', 'Ibajay', 'Aklan', 'Active', 11.774045691, 122.201943573, 0),
(31, 'Mabusao', 'Ibajay', 'Aklan', 'Active', 11.773314895, 122.136538562, 0),
(32, 'Agbago', 'Ibajay', 'Aklan', 'Active', 11.816222345, 122.149421729, 2139),
(33, 'Poblacion', 'Ibajay', 'Aklan', 'Active', 11.819840997, 122.160104299, 3041),
(34, 'Colongcolong', 'Ibajay', 'Aklan', 'Active', 11.816952427, 122.172484307, 0),
(35, 'Naisud', 'Ibajay', 'Aklan', 'Active', 11.792490343, 122.191828529, 3205),
(36, 'Tagbaya', 'Ibajay', 'Aklan', 'Active', 11.813236549, 122.140900547, 0),
(37, 'Ondoy', 'Ibajay', 'Aklan', 'Active', 11.814028599, 122.130622379, 2692),
(38, 'San Isidro', 'Ibajay', 'Aklan', 'Active', 11.811089957, 122.179061945, 0),
(39, 'Polo', 'Ibajay', 'Aklan', 'Active', 11.814855581, 122.164394649, 1250),
(40, 'Maloco', 'Ibajay', 'Aklan', 'Active', 11.778166403, 122.151197584, 2628),
(41, 'Buenavista', 'Ibajay', 'Aklan', 'Active', 11.801025098, 122.176488383, 556),
(42, 'Laguinbanwa', 'Ibajay', 'Aklan', 'Active', 11.804508292, 122.160509417, 0),
(43, 'Tul-Ang', 'Ibajay', 'Aklan', 'Active', 11.807200065, 122.167130584, 992),
(44, 'Antipolo', 'Ibajay', 'Aklan', 'Active', 11.792260264, 122.124679778, 831),
(45, 'Naligusan', 'Ibajay', 'Aklan', 'Active', 11.774467105, 122.172218418, 0),
(46, 'Rizal', 'Ibajay', 'Aklan', 'Active', 11.786664305, 122.172012939, 1445),
(47, 'Unat', 'Ibajay', 'Aklan', 'Active', 11.780564794, 122.163677608, 9999),
(48, 'Bagacay', 'Ibajay', 'Aklan', 'Active', 11.790111472, 122.166652438, 0),
(49, 'Santa Cruz', 'Ibajay', 'Aklan', 'Active', 11.795474885, 122.137342717, 1179),
(50, 'Batuan', 'Ibajay', 'Aklan', 'Active', 11.794303247, 122.149889738, 0),
(51, 'Capilijan', 'Ibajay', 'Aklan', 'Active', 11.789663758, 122.160100676, 0);

-- --------------------------------------------------------

--
-- Table structure for table `disaster_types`
--

CREATE TABLE `disaster_types` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `status` enum('Active','Inactive') DEFAULT 'Active',
  `is_natural` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `disaster_types`
--

INSERT INTO `disaster_types` (`id`, `name`, `status`, `is_natural`) VALUES
(1, 'Typhoon', 'Active', 1),
(2, 'Flood', 'Active', 1),
(3, 'Storm Surge', 'Active', 1),
(4, 'Earthquake', 'Active', 1),
(5, 'Landslide', 'Active', 1),
(6, 'Fire', 'Active', 1),
(7, 'Drought / El Niño', 'Active', 1),
(8, 'Disease Outbreak', 'Active', 1),
(9, 'Accident / Mass Casualty Incident', 'Active', 0),
(10, 'Others', 'Active', 0);

-- --------------------------------------------------------

--
-- Table structure for table `emergency_hotlines`
--

CREATE TABLE `emergency_hotlines` (
  `id` int(11) NOT NULL,
  `hotline_scope` enum('Municipal','Barangay') NOT NULL DEFAULT 'Municipal',
  `barangay_id` int(11) DEFAULT NULL,
  `office_name` varchar(150) NOT NULL,
  `municipality` varchar(100) DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `telephone_numbers` text DEFAULT NULL,
  `cellphone_numbers` text DEFAULT NULL,
  `hotline_number` varchar(50) DEFAULT NULL,
  `remarks` text DEFAULT NULL,
  `status` enum('Active','Inactive') DEFAULT 'Active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `emergency_hotlines`
--

INSERT INTO `emergency_hotlines` (`id`, `hotline_scope`, `barangay_id`, `office_name`, `municipality`, `category`, `telephone_numbers`, `cellphone_numbers`, `hotline_number`, `remarks`, `status`, `created_at`) VALUES
(1, 'Municipal', NULL, 'Altavas Emergency Hotline', 'Altavas', 'Municipal Emergency Hotline', '269-1385', '09201265030 , 09178375341 , 09388831620', '', '', 'Active', '2026-05-27 12:53:34'),
(2, 'Municipal', NULL, 'Balete Emergency Hotline', 'Balete', 'Municipal Emergency Hotline', '272-3861', '09399241730', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(3, 'Municipal', NULL, 'Banga Emergency Hotline', 'Banga', 'Municipal Emergency Hotline', '267-7261', '09395307666', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(4, 'Municipal', NULL, 'Batan Emergency Hotline', 'Batan', 'Municipal Emergency Hotline', '272-4500 , 272-3494', '09194236851', '', '', 'Active', '2026-05-27 12:53:34'),
(5, 'Municipal', NULL, 'Buruanga Emergency Hotline', 'Buruanga', 'Municipal Emergency Hotline', '', '09392787071 , 09184409017 , 09178271407', '', '', 'Active', '2026-05-27 12:53:34'),
(6, 'Municipal', NULL, 'Ibajay Emergency Hotline', 'Ibajay', 'Municipal Emergency Hotline', '289-2673', '09998809487', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(7, 'Municipal', NULL, 'Kalibo Emergency Hotline', 'Kalibo', 'Municipal Emergency Hotline', '268-8991; 268-3505', '09078951984 , 09186312150', '159', '', 'Active', '2026-05-27 12:53:34'),
(8, 'Municipal', NULL, 'Lezo Emergency Hotline', 'Lezo', 'Municipal Emergency Hotline', '274-7514', '09178337603', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(9, 'Municipal', NULL, 'Libacao Emergency Hotline', 'Libacao', 'Municipal Emergency Hotline', '273-2311', '09300836577', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(10, 'Municipal', NULL, 'Madalag Emergency Hotline', 'Madalag', 'Municipal Emergency Hotline', '272-3655', '09077076611 , 09394748348 , 09152622896', '', '', 'Active', '2026-05-27 12:53:34'),
(11, 'Municipal', NULL, 'Makato Emergency Hotline', 'Makato', 'Municipal Emergency Hotline', '272-4014', '09471701159 , 09301703159', '', '', 'Active', '2026-05-27 12:53:34'),
(12, 'Municipal', NULL, 'Malinao Emergency Hotline', 'Malinao', 'Municipal Emergency Hotline', '272-4315', '09510851602 , 09984616070', '', '', 'Active', '2026-05-27 12:53:34'),
(13, 'Municipal', NULL, 'Malay Emergency Hotline', 'Malay', 'Municipal Emergency Hotline', '288-7843', '09198514102', '106', NULL, 'Active', '2026-05-27 12:53:34'),
(14, 'Municipal', NULL, 'Nabas Emergency Hotline', 'Nabas', 'Municipal Emergency Hotline', '', '09214605082 , 09455578242 , 09630448192', '', '', 'Active', '2026-05-27 12:53:34'),
(15, 'Municipal', NULL, 'New Washington Emergency Hotline', 'New Washington', 'Municipal Emergency Hotline', '264-4283/138', '09498988013 , 09178093222', '', '', 'Active', '2026-05-27 12:53:34'),
(16, 'Municipal', NULL, 'Numancia Emergency Hotline', 'Numancia', 'Municipal Emergency Hotline', '265-3470', '09317758445 , 09213050796', '', '', 'Active', '2026-05-27 12:53:34'),
(17, 'Municipal', NULL, 'Tangalan Emergency Hotline', 'Tangalan', 'Municipal Emergency Hotline', '271-2311', '09984512824', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(18, 'Municipal', NULL, 'Dumaguit Coast Guard', 'New Washington', 'Coast Guard', NULL, '09152269973', NULL, NULL, 'Active', '2026-05-27 12:53:34'),
(19, 'Barangay', 13, 'Kalibo MDRRMO', 'Kalibo', 'MDRRMO', '', '0917-717-7461 , 0998-998-5647', '159', '', 'Active', '2026-05-31 06:21:05'),
(20, 'Barangay', 13, 'Kalibo PNP', 'Kalibo', 'PNP', '268-2166', '0939-916-7066', '166', '', 'Active', '2026-05-31 06:22:19'),
(21, 'Barangay', 13, 'Kalibo BFP', 'Kalibo', 'Fire', '268-2143', '0951-783-1223', '', '', 'Active', '2026-05-31 06:23:17'),
(22, 'Barangay', 32, 'Ibajay_Agbago - 09942047568', 'Ibajay', 'Barangay', NULL, '09942047568', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(23, 'Barangay', 29, 'Ibajay_Agdugayan - 09380118036', 'Ibajay', 'Barangay', NULL, '09380118036', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(24, 'Barangay', 44, 'Ibajay_Antipolo - 09274895236', 'Ibajay', 'Barangay', NULL, '09274895236', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(25, 'Barangay', 22, 'Ibajay_Aparicio - 09811569784', 'Ibajay', 'Barangay', NULL, '09811569784', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(26, 'Barangay', 19, 'Ibajay_Aquino - 09291872147', 'Ibajay', 'Barangay', NULL, '09291872147', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(27, 'Barangay', 20, 'Ibajay_Aslum - 09984566799', 'Ibajay', 'Barangay', NULL, '09984566799', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(28, 'Barangay', 48, 'Ibajay_Bagacay - 09073809785', 'Ibajay', 'Barangay', NULL, '09073809785', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(29, 'Barangay', 50, 'Ibajay_Batuan - 09088759273', 'Ibajay', 'Barangay', NULL, '09088759273', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(30, 'Barangay', 41, 'Ibajay_Buenavista - 09515871575', 'Ibajay', 'Barangay', NULL, '09515871575', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(31, 'Barangay', 17, 'Ibajay_Bugtong Bato - 09388210266', 'Ibajay', 'Barangay', NULL, '09388210266', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(32, 'Barangay', 27, 'Ibajay_Cabugao - 09466725377', 'Ibajay', 'Barangay', NULL, '09466725377', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(33, 'Barangay', 51, 'Ibajay_Capilijan - 09216621858', 'Ibajay', 'Barangay', NULL, '09216621858', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(34, 'Barangay', 34, 'Ibajay_Colongcolong - 09199650246', 'Ibajay', 'Barangay', NULL, '09199650246', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(35, 'Barangay', 42, 'Ibajay_Laguinbanwa - 09455511336', 'Ibajay', 'Barangay', NULL, '09455511336', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(36, 'Barangay', 31, 'Ibajay_Mabusao - 09814954894', 'Ibajay', 'Barangay', NULL, '09814954894', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(37, 'Barangay', 23, 'Ibajay_Malindog - 09517826101', 'Ibajay', 'Barangay', NULL, '09517826101', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(38, 'Barangay', 40, 'Ibajay_Maloco - 09818137699', 'Ibajay', 'Barangay', NULL, '09818137699', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(39, 'Barangay', 21, 'Ibajay_Mina-A - 09630360561', 'Ibajay', 'Barangay', NULL, '09630360561', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(40, 'Barangay', 24, 'Ibajay_Monalaque - 09237462676', 'Ibajay', 'Barangay', NULL, '09237462676', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(41, 'Barangay', 28, 'Ibajay_Naile - 09814978911', 'Ibajay', 'Barangay', NULL, '09814978911', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(42, 'Barangay', 35, 'Ibajay_Naisud - 09237473564', 'Ibajay', 'Barangay', NULL, '09237473564', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(43, 'Barangay', 45, 'Ibajay_Naligusan - 09382560613', 'Ibajay', 'Barangay', NULL, '09382560613', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(44, 'Barangay', 37, 'Ibajay_Ondoy - 09914769434', 'Ibajay', 'Barangay', NULL, '09914769434', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(45, 'Barangay', 33, 'Ibajay_Poblacion - 09484675060', 'Ibajay', 'Barangay', NULL, '09484675060', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(46, 'Barangay', 39, 'Ibajay_Polo - 09634634233', 'Ibajay', 'Barangay', NULL, '09634634233', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(47, 'Barangay', 30, 'Ibajay_Regador - 09237474759', 'Ibajay', 'Barangay', NULL, '09237474759', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(48, 'Barangay', 25, 'Ibajay_Rivera - 09622851602', 'Ibajay', 'Barangay', NULL, '09622851602', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(49, 'Barangay', 46, 'Ibajay_Rizal - 09999944982', 'Ibajay', 'Barangay', NULL, '09999944982', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(50, 'Barangay', 38, 'Ibajay_San Isidro - 09104724377', 'Ibajay', 'Barangay', NULL, '09104724377', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(51, 'Barangay', 26, 'Ibajay_San Jose - 09303333073', 'Ibajay', 'Barangay', NULL, '09303333073', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(52, 'Barangay', 49, 'Ibajay_Santa Cruz - 09461349769', 'Ibajay', 'Barangay', NULL, '09461349769', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(53, 'Barangay', 36, 'Ibajay_Tagbaya - 09123261032', 'Ibajay', 'Barangay', NULL, '09123261032', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(54, 'Barangay', 43, 'Ibajay_Tul-Ang - 09630352874', 'Ibajay', 'Barangay', NULL, '09630352874', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(55, 'Barangay', 47, 'Ibajay_Unat - 09123083555', 'Ibajay', 'Barangay', NULL, '09123083555', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(56, 'Barangay', 18, 'Ibajay_Yawan - 09667158570', 'Ibajay', 'Barangay', NULL, '09667158570', NULL, NULL, 'Active', '2026-09-05 10:28:37'),
(57, 'Municipal', NULL, 'MDRRMO Ibajay', 'Ibajay', 'MDRRMO', '272-6830', '09318353796', NULL, NULL, 'Active', '2026-09-13 08:14:46'),
(58, 'Municipal', NULL, 'Ibajay District Hospital', 'Ibajay', 'Hospital', '289-2865', '09388469901', NULL, NULL, 'Active', '2026-09-13 08:14:46'),
(59, 'Municipal', NULL, 'PNP Ibajay', 'Ibajay', 'PNP', '289-2023', '09985986115', NULL, NULL, 'Active', '2026-09-13 08:14:46'),
(60, 'Municipal', NULL, 'BFP Ibajay', 'Ibajay', 'Fire', '289-2022', '09513219653', NULL, NULL, 'Active', '2026-09-13 08:14:46'),
(61, 'Municipal', NULL, 'Coast Guard Ibajay', 'Ibajay', 'Coast Guard', NULL, '09687269136', NULL, NULL, 'Active', '2026-09-13 08:14:46'),
(62, 'Municipal', NULL, 'Governor (Aklan Provincial Office)', NULL, 'Other', '(036) 272 7000', NULL, NULL, NULL, 'Active', '2026-09-13 08:14:46');

-- --------------------------------------------------------

--
-- Table structure for table `evacuation_centers`
--

CREATE TABLE `evacuation_centers` (
  `id` int(11) NOT NULL,
  `barangay` varchar(100) NOT NULL,
  `municipality` varchar(50) NOT NULL DEFAULT '',
  `center_name` varchar(150) NOT NULL,
  `center_type` varchar(100) DEFAULT NULL,
  `capacity` int(11) DEFAULT 0,
  `current_evacuees` int(11) DEFAULT 0,
  `status` enum('Available','Open','Full','Closed','Needs Supplies') DEFAULT 'Available',
  `contact_person` varchar(100) DEFAULT NULL,
  `contact_number` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `latitude` decimal(12,9) DEFAULT NULL,
  `longitude` decimal(12,9) DEFAULT NULL,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `evacuation_centers`
--

INSERT INTO `evacuation_centers` (`id`, `barangay`, `municipality`, `center_name`, `center_type`, `capacity`, `current_evacuees`, `status`, `contact_person`, `contact_number`, `created_at`, `latitude`, `longitude`, `is_demo`) VALUES
(1, 'Buswang Old', 'Kalibo', 'Saint Gabriel College', 'School / Institution', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', 11.715574122, 122.375679571, 0),
(2, 'Linabuan Norte', 'Kalibo', 'Barangay Hall', 'Barangay Facility', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', NULL, NULL, 0),
(3, 'Linabuan Norte', 'Kalibo', 'Elementary Schools', 'School', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', NULL, NULL, 0),
(4, 'Linabuan Norte', 'Kalibo', 'Local Church', 'Church', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', NULL, NULL, 0),
(5, 'Poblacion', 'Kalibo', 'Bliss Site Covered Court', 'Covered Court', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', 11.711979389, 122.369535753, 0),
(6, 'Poblacion', 'Kalibo', 'Poblacion Barangay Hall, 3rd Floor', 'Barangay Facility', 0, 0, 'Available', NULL, NULL, '2026-05-27 12:51:56', NULL, NULL, 0),
(7, 'Andagaw', 'Kalibo', 'Aklan State University', 'School', 0, 0, 'Available', '', '', '2026-05-29 02:23:30', 11.702677021, 122.375857875, 0),
(8, 'Agbago', 'Ibajay', 'Agbago Mall', 'Mall ngani', 900002, 0, 'Open', 'Elon Musk', '0987654321', '2026-09-07 06:07:21', NULL, NULL, 0),
(15, 'Aquino', 'Ibajay', 'Aquino', 'Evacuation Center', 999, 0, 'Available', 'mark zuckerberg', '09666421888', '2026-09-07 11:44:08', NULL, NULL, 0),
(18, 'Poblacion', 'Ibajay', 'Poblacion Parish Hall', 'Church', 150, 96, 'Open', 'Parish Staff', '09484675060', '2026-09-07 13:27:40', 11.821200000, 122.167600000, 1),
(19, 'Naisud', 'Ibajay', 'Naisud Barangay Hall', 'Barangay Facility', 80, 62, 'Open', 'Brgy. Admin', '09237473564', '2026-09-07 13:27:40', 11.805500000, 122.160800000, 1),
(20, 'Rivera', 'Ibajay', 'DingDong Gym', 'Evacuation Center', 799, 0, 'Available', 'Bill gates', '098765312', '2026-09-07 14:23:01', NULL, NULL, 0),
(21, 'Ondoy', 'Ibajay', 'Ondoy Mall', 'Evacuation Center', 9000, 0, 'Available', 'pepengtuta', '999999999', '2026-09-08 13:38:52', NULL, NULL, 0),
(22, 'Tul-Ang', 'Ibajay', 'TA data center', 'Evacuation Center', 9999, 0, 'Available', 'john cena', '09876543211', '2026-09-10 02:59:17', NULL, NULL, 0),
(24, 'Santa Cruz', 'Ibajay', 'SC CondoTell', 'Evacuation Center', 9999, 0, 'Open', 'Manny Pacman', '09666421888', '2026-09-11 11:19:25', NULL, NULL, 0),
(34, 'Polo', 'Ibajay', 'Polo Basketball Court', 'Evacuation Center', 9999, 0, 'Available', 'Jesus', '09123456789', '2026-09-12 12:46:33', NULL, NULL, 0),
(36, 'Antipolo', 'Ibajay', 'AT State University', 'Evacuation Center', 9999, 0, 'Available', 'Jose Rizal', '09666421888', '2026-09-12 14:09:16', NULL, NULL, 0),
(37, 'Yawan', 'Ibajay', 'Yawan Tower', 'Evacuation Center', 99999, 0, 'Open', 'yawan lintin', '098888666777', '2026-09-13 01:29:50', NULL, NULL, 0),
(38, 'Poblacion', 'Ibajay', 'DepEd Ibajay Central School', 'Evacuation Center', 9999, 0, 'Available', 'Tongs sahur', '09123341221', '2026-09-13 07:43:55', 11.821127000, 122.161269000, 0),
(39, 'Poblacion', 'Ibajay', 'Ibajay Sports Center', 'Gym', 9999, 0, 'Available', 'Hotdog', '00000000000', '2026-09-13 07:46:42', 11.819014000, 122.162119000, 0),
(40, 'Colongcolong', 'Ibajay', 'Aklan State University - Ibajay Campus', 'Evacuation Center', 9999, 0, 'Available', 'Peter parker', '99999999999', '2026-09-13 08:41:40', 11.818187000, 122.171434000, 0),
(41, 'Maloco', 'Ibajay', 'Maloco Covered Court', 'Evacuation Center', 99999, 0, 'Available', 'Justine Bieber', '09876543212', '2026-09-13 09:43:26', NULL, NULL, 0),
(42, 'Unat', 'Ibajay', 'Unat HQ', 'Datacenter', 10000, 0, 'Available', 'blue', '999999999999', '2026-09-17 13:15:04', NULL, NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `evac_assistance`
--

CREATE TABLE `evac_assistance` (
  `id` int(11) NOT NULL,
  `evac_center_id` int(11) NOT NULL,
  `need_id` int(11) DEFAULT NULL,
  `donor_user_id` int(11) NOT NULL,
  `donor_label` varchar(120) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty` int(11) NOT NULL DEFAULT 0,
  `qty_received` int(11) DEFAULT NULL,
  `status` enum('Pledged','Sent','Delivered') NOT NULL DEFAULT 'Pledged',
  `pledged_at` timestamp NULL DEFAULT NULL,
  `sent_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `received_at` timestamp NULL DEFAULT NULL,
  `confirmed_by_user_id` int(11) DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `over_pledge_flag` tinyint(1) NOT NULL DEFAULT 0,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `evac_assistance`
--

INSERT INTO `evac_assistance` (`id`, `evac_center_id`, `need_id`, `donor_user_id`, `donor_label`, `item`, `unit`, `qty`, `qty_received`, `status`, `pledged_at`, `sent_at`, `delivered_at`, `received_at`, `confirmed_by_user_id`, `remarks`, `over_pledge_flag`, `is_demo`, `created_at`) VALUES
(58, 19, 49, 76, 'MDRRMO Ibajay', 'water', '', 25, 15, 'Delivered', '2026-09-17 01:14:21', '2026-09-17 01:14:28', '2026-09-17 01:14:32', '2026-09-17 01:15:30', 107, '', 0, 0, '2026-09-17 01:14:21'),
(59, 19, 49, 79, 'PDRRMO', 'water', '', 25, 25, 'Delivered', '2026-09-17 01:30:40', '2026-09-17 01:30:43', '2026-09-17 01:30:46', '2026-09-17 01:32:57', 58, '', 0, 0, '2026-09-17 01:30:40'),
(60, 19, 49, 87, 'Governor', 'water', '', 25, 25, 'Delivered', '2026-09-17 01:31:17', '2026-09-17 01:31:21', '2026-09-17 01:31:21', '2026-09-17 01:43:30', 58, '', 0, 0, '2026-09-17 01:31:17'),
(61, 19, 49, 76, 'MDRRMO Ibajay', 'water', '', 25, 25, 'Delivered', '2026-09-17 01:45:18', '2026-09-17 01:49:25', '2026-09-17 01:52:33', '2026-09-17 02:00:13', 58, '', 0, 0, '2026-09-17 01:45:18'),
(62, 19, 49, 79, 'PDRRMO', 'water', '', 10, NULL, 'Pledged', '2026-09-17 12:03:53', NULL, NULL, NULL, NULL, '', 0, 0, '2026-09-17 12:03:53');

-- --------------------------------------------------------

--
-- Table structure for table `evac_center_needs`
--

CREATE TABLE `evac_center_needs` (
  `id` int(11) NOT NULL,
  `evac_center_id` int(11) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty_needed` int(11) NOT NULL DEFAULT 0,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `evac_center_needs`
--

INSERT INTO `evac_center_needs` (`id`, `evac_center_id`, `item`, `unit`, `qty_needed`, `is_demo`, `created_by`, `created_at`) VALUES
(49, 19, 'water', 'liters', 100, 1, 107, '2026-09-17 01:13:28');

-- --------------------------------------------------------

--
-- Table structure for table `evac_center_profile`
--

CREATE TABLE `evac_center_profile` (
  `id` int(11) NOT NULL,
  `evac_center_id` int(11) NOT NULL,
  `total_evacuees` int(11) NOT NULL DEFAULT 0,
  `families` int(11) NOT NULL DEFAULT 0,
  `pregnant` int(11) NOT NULL DEFAULT 0,
  `lactating_mothers` int(11) NOT NULL DEFAULT 0,
  `infants` int(11) NOT NULL DEFAULT 0,
  `children` int(11) NOT NULL DEFAULT 0,
  `older_persons` int(11) NOT NULL DEFAULT 0,
  `pwd` int(11) NOT NULL DEFAULT 0,
  `sick` int(11) NOT NULL DEFAULT 0,
  `injured` int(11) NOT NULL DEFAULT 0,
  `source` enum('manual','computed') NOT NULL DEFAULT 'manual',
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `updated_by` int(11) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `evac_center_profile`
--

INSERT INTO `evac_center_profile` (`id`, `evac_center_id`, `total_evacuees`, `families`, `pregnant`, `lactating_mothers`, `infants`, `children`, `older_persons`, `pwd`, `sick`, `injured`, `source`, `is_demo`, `updated_by`, `updated_at`) VALUES
(34, 19, 200, 100, 0, 0, 0, 100, 0, 0, 0, 0, 'manual', 1, 107, '2026-09-17 01:13:28');

-- --------------------------------------------------------

--
-- Table structure for table `incident_attachments`
--

CREATE TABLE `incident_attachments` (
  `id` int(11) NOT NULL,
  `incident_report_id` int(11) NOT NULL,
  `uploaded_by` int(11) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_path` varchar(255) NOT NULL,
  `file_type` varchar(50) DEFAULT NULL,
  `file_size` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `incident_reports`
--

CREATE TABLE `incident_reports` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `barangay_id` int(11) NOT NULL,
  `disaster_type` varchar(100) NOT NULL,
  `incident_datetime` datetime DEFAULT NULL,
  `exact_location` varchar(255) DEFAULT NULL,
  `road_status` enum('Passable','Partially Passable','Obstructed') NOT NULL DEFAULT 'Passable',
  `road_blockage_causes` varchar(255) DEFAULT NULL,
  `road_location` varchar(255) DEFAULT NULL,
  `evacuation_needed` enum('Yes','No') DEFAULT 'No',
  `evacuation_center_id` int(11) DEFAULT NULL,
  `evac_households` int(11) DEFAULT 0,
  `evac_adults` int(11) DEFAULT 0,
  `evac_children` int(11) DEFAULT 0,
  `evac_members` int(11) DEFAULT 0,
  `description` text NOT NULL,
  `assistance_needed` text DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `affected_people` int(11) DEFAULT 0,
  `injured` int(11) DEFAULT 0,
  `dead` int(11) DEFAULT 0,
  `missing` int(11) DEFAULT 0,
  `status` varchar(50) DEFAULT 'Pending',
  `referred_to_pho` tinyint(1) NOT NULL DEFAULT 0,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `client_uuid` varchar(36) DEFAULT NULL,
  `pin_outside_area` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `incident_reports`
--

INSERT INTO `incident_reports` (`id`, `user_id`, `barangay_id`, `disaster_type`, `incident_datetime`, `exact_location`, `road_status`, `road_blockage_causes`, `road_location`, `evacuation_needed`, `evacuation_center_id`, `evac_households`, `evac_adults`, `evac_children`, `evac_members`, `description`, `assistance_needed`, `latitude`, `longitude`, `affected_people`, `injured`, `dead`, `missing`, `status`, `referred_to_pho`, `is_demo`, `created_at`, `client_uuid`, `pin_outside_area`) VALUES
(110, 108, 35, 'Flood', '2026-09-17 09:09:00', NULL, 'Obstructed', 'Flooding / Deep Water', '', 'Yes', 19, 100, 100, 100, 100, 'gg', '', 11.8054218, 122.1952402, 3205, 0, 0, 100, 'Referred to PHO', 1, 0, '2026-09-17 01:10:09', NULL, 0),
(112, 127, 47, 'Storm Surge', '2026-09-17 21:16:00', NULL, 'Partially Passable', 'Fallen Tree', '', 'Yes', 42, 10, 10, 10, 10, 'gg', '', 11.7768851, 122.1637321, 9999, 0, 0, 0, 'Under MDR Review', 0, 0, '2026-09-17 13:17:38', NULL, 0),
(116, 117, 35, 'Flood', '2026-09-21 18:12:00', NULL, 'Obstructed', 'Damaged / Collapsed Bridge', '', 'No', NULL, 0, 0, 0, 0, 'gg', '', 11.8055663, 122.1976364, 3205, 0, 0, 0, 'Pending', 0, 0, '2026-09-21 10:16:22', '648d26eb-0e55-4396-931c-843a5ab04ec4', 0),
(117, 103, 37, 'Landslide', '2026-09-21 19:24:00', 'riversude', 'Partially Passable', '', '', 'Yes', 21, 10, 10, 10, 10, 'gg', '', 11.8255460, 122.1274118, 2692, 5, 0, 0, 'Reviewed', 0, 0, '2026-09-21 11:31:54', '0c3d4e41-53a7-4667-b275-ee8cdfcd9371', 0),
(118, 83, 46, 'Earthquake', '2026-09-22 13:18:00', 'riverside', 'Passable', '', '', 'No', NULL, 0, 0, 0, 0, 'gg', '', 11.7806995, 122.1728587, 1445, 9, 0, 0, 'Pending', 0, 0, '2026-09-22 05:22:04', '2a92a396-1517-470c-95ba-9db0481c3eb0', 0),
(119, 83, 46, 'Fire', '2026-09-22 13:28:00', NULL, 'Passable', '', 'g', 'No', NULL, 0, 0, 0, 0, 'gg', '', 11.7993398, 122.1713634, 1445, 0, 9, 0, 'Forwarded to PCF', 0, 0, '2026-09-22 05:32:08', '3f5ad1d1-ec3f-4dcf-87d0-6609eeceba17', 0);

-- --------------------------------------------------------

--
-- Table structure for table `incident_status_logs`
--

CREATE TABLE `incident_status_logs` (
  `id` int(11) NOT NULL,
  `incident_report_id` int(11) NOT NULL,
  `old_status` varchar(100) DEFAULT NULL,
  `new_status` varchar(100) NOT NULL,
  `remarks` text DEFAULT NULL,
  `updated_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `incident_status_logs`
--

INSERT INTO `incident_status_logs` (`id`, `incident_report_id`, `old_status`, `new_status`, `remarks`, `updated_by`, `created_at`) VALUES
(203, 110, NULL, 'Pending', 'Report submitted from mobile app.', 108, '2026-09-17 01:10:09'),
(204, 110, 'Pending', 'Reviewed', 'Report reviewed by Chairman.', 58, '2026-09-17 01:12:51'),
(205, 110, 'Reviewed', 'Forwarded to PCF', 'Report forwarded to Municipal for coordination.', 58, '2026-09-17 01:12:55'),
(206, 110, 'Forwarded to PCF', 'Under MDR Review', 'Report acknowledged and under MDR review.', 76, '2026-09-17 12:23:27'),
(207, 110, 'Under MDR Review', 'Referred to PHO', 'Report referred to Provincial.', 76, '2026-09-17 12:23:30'),
(208, 112, NULL, 'Pending', 'Report submitted from mobile app.', 127, '2026-09-17 13:17:38'),
(209, 112, 'Pending', 'Reviewed', 'Report reviewed by Chairman.', 70, '2026-09-17 13:17:52'),
(210, 112, 'Reviewed', 'Forwarded to PCF', 'Report forwarded to Municipal for coordination.', 70, '2026-09-17 13:17:55'),
(211, 112, 'Forwarded to PCF', 'Under MDR Review', 'MDR Ibajay Admin (PCF) changed this report status to Under MDR Review from mobile app.', 76, '2026-09-17 13:23:01'),
(215, 116, NULL, 'Pending', 'Report submitted from mobile app.', 117, '2026-09-21 10:16:22'),
(216, 117, NULL, 'Pending', 'Report submitted from mobile app.', 103, '2026-09-21 11:31:54'),
(217, 117, 'Pending', 'Reviewed', 'Report reviewed by Chairman.', 60, '2026-09-21 14:09:58'),
(218, 118, NULL, 'Pending', 'Report submitted from mobile app.', 83, '2026-09-22 05:22:04'),
(219, 119, NULL, 'Pending', 'Report submitted from mobile app.', 83, '2026-09-22 05:32:08'),
(220, 119, 'Pending', 'Reviewed', 'Report reviewed by Chairman.', 69, '2026-09-24 04:21:28'),
(221, 119, 'Reviewed', 'Forwarded to PCF', 'Report forwarded to Municipal for coordination.', 69, '2026-09-24 04:21:52');

-- --------------------------------------------------------

--
-- Table structure for table `pcf_facilities`
--

CREATE TABLE `pcf_facilities` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `municipality` varchar(100) NOT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pcf_facilities`
--

INSERT INTO `pcf_facilities` (`id`, `name`, `municipality`, `latitude`, `longitude`, `created_at`) VALUES
(1, 'Ibajay District Hospital', 'Ibajay', 11.8115740, 122.1535700, '2026-09-07 01:51:02'),
(2, 'Ibajay Primary Care Facility 1', 'Ibajay', 11.7679570, 122.1742240, '2026-09-07 01:51:02'),
(3, 'Ibajay Rural Health Unit II', 'Ibajay', 11.8222700, 122.1617850, '2026-09-07 01:51:02'),
(4, 'Ibajay Super Health Center', 'Ibajay', 11.8179310, 122.1235100, '2026-09-07 01:51:02'),
(5, 'Kalibo Health and Birthing Center', 'Kalibo', 11.7110170, 122.3671650, '2026-09-07 01:51:02'),
(6, 'Kalibo Rural Health Unit I', 'Kalibo', 11.6672890, 122.3529980, '2026-09-07 01:51:02');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('superadmin','barangay','pcf','pho') NOT NULL,
  `sub_role` enum('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay','pdrrmo','governor','mayor_kalibo','mayor_ibajay') DEFAULT NULL,
  `can_manage_users` tinyint(1) DEFAULT 0,
  `barangay_id` int(11) DEFAULT NULL,
  `status` enum('Active','Inactive') DEFAULT 'Active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `username`, `password`, `role`, `sub_role`, `can_manage_users`, `barangay_id`, `status`, `created_at`) VALUES
(1, 'Super Administrator', 'superadmin', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'superadmin', NULL, 0, NULL, 'Active', '2026-05-27 13:14:20'),
(2, 'MDR Admin', 'pcfadmin', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pcf', 'mdr_admin', 1, NULL, 'Active', '2026-05-27 13:14:20'),
(3, 'Provincial Admin', 'phoadmin', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'pho', NULL, 1, NULL, 'Active', '2026-05-27 13:14:20'),
(4, 'Andagaw Barangay Account', 'andagaw', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 1, 'Active', '2026-05-27 13:14:53'),
(5, 'Bachaw Norte Barangay Account', 'bachaw_norte', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 2, 'Active', '2026-05-27 13:14:53'),
(6, 'Bachaw Sur Barangay Account', 'bachaw_sur', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 3, 'Active', '2026-05-27 13:14:53'),
(7, 'Briones Barangay Account', 'briones', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 4, 'Active', '2026-05-27 13:14:53'),
(8, 'Buswang New Barangay Account', 'buswang_new', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 5, 'Active', '2026-05-27 13:14:53'),
(9, 'Buswang Old Barangay Account', 'buswang_old', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 6, 'Active', '2026-05-27 13:14:53'),
(10, 'Caano Barangay Account', 'caano', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 7, 'Active', '2026-05-27 13:14:53'),
(11, 'Estancia Barangay Account', 'estancia', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 8, 'Active', '2026-05-27 13:14:53'),
(12, 'Linabuan Norte Barangay Account', 'linabuan_norte', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 9, 'Active', '2026-05-27 13:14:53'),
(13, 'Mabilo Barangay Account', 'mabilo', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 10, 'Active', '2026-05-27 13:14:53'),
(14, 'Mobo Barangay Account', 'mobo', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 11, 'Active', '2026-05-27 13:14:53'),
(15, 'Nalook Barangay Account', 'nalook', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 12, 'Active', '2026-05-27 13:14:53'),
(16, 'Poblacion Barangay Account', 'poblacion', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 13, 'Active', '2026-05-27 13:14:53'),
(17, 'Pook Barangay Account', 'pook', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 14, 'Active', '2026-05-27 13:14:53'),
(18, 'Tigayon Barangay Account', 'tigayon', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 15, 'Active', '2026-05-27 13:14:53'),
(19, 'Tinigaw Barangay Account', 'tinigaw', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 16, 'Active', '2026-05-27 13:14:53'),
(34, 'Fiona Shrek', 'andagaw_secretary', '$2y$10$VeKPx3PKZTmrXH5VyVVYxOICTekitBPDrJklXebdAJQaomUnNWVca', 'barangay', 'secretary', 1, 1, 'Active', '2026-08-20 16:01:26'),
(35, 'Tanod Juan', 'andagaw_tanod1', '$2y$10$XSAJbu8Vxa.e6tmK07qzSu5raUorN5tIEXrK48MO1NuDTUpWMo8lC', 'barangay', 'tanod', 0, 1, 'Active', '2026-08-20 16:01:35'),
(36, 'Tanod Maria', 'andagaw_tanod2', '$2y$10$RcfJtr5Jhza8AwoMyecZC.dz0wQCdURgwf.B2ZNS1tQK1EccDS.Cq', 'barangay', 'tanod', 0, 1, 'Active', '2026-08-20 16:01:41'),
(40, 'Bugtong Bato Chairman', 'ibajay_bugtong_bato', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 17, 'Active', '2026-08-27 15:15:38'),
(41, 'Yawan Chairman', 'ibajay_yawan', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 18, 'Active', '2026-08-27 15:15:38'),
(42, 'Aquino Chairman', 'ibajay_aquino', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 19, 'Active', '2026-08-27 15:15:38'),
(43, 'Aslum Chairman', 'ibajay_aslum', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 20, 'Active', '2026-08-27 15:15:38'),
(44, 'Mina-A Chairman', 'ibajay_mina_a', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 21, 'Active', '2026-08-27 15:15:38'),
(45, 'Aparicio Chairman', 'ibajay_aparicio', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 22, 'Active', '2026-08-27 15:15:38'),
(46, 'Malindog Chairman', 'ibajay_malindog', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 23, 'Active', '2026-08-27 15:15:38'),
(47, 'Monalaque Chairman', 'ibajay_monalaque', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 24, 'Active', '2026-08-27 15:15:38'),
(48, 'Rivera Chairman', 'ibajay_rivera', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 25, 'Active', '2026-08-27 15:15:38'),
(49, 'San Jose Chairman', 'ibajay_san_jose', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 26, 'Active', '2026-08-27 15:15:38'),
(50, 'Cabugao Chairman', 'ibajay_cabugao', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 27, 'Active', '2026-08-27 15:15:38'),
(51, 'Naile Chairman', 'ibajay_naile', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 28, 'Active', '2026-08-27 15:15:38'),
(52, 'Agdugayan Chairman', 'ibajay_agdugayan', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 29, 'Active', '2026-08-27 15:15:38'),
(53, 'Regador Chairman', 'ibajay_regador', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 30, 'Active', '2026-08-27 15:15:38'),
(54, 'Mabusao Chairman', 'ibajay_mabusao', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 31, 'Active', '2026-08-27 15:15:38'),
(55, 'Agbago Chairman', 'ibajay_agbago', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 32, 'Active', '2026-08-27 15:15:38'),
(56, 'Poblacion Chairman', 'ibajay_poblacion', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 33, 'Active', '2026-08-27 15:15:38'),
(57, 'Colongcolong Chairman', 'ibajay_colongcolong', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 34, 'Active', '2026-08-27 15:15:38'),
(58, 'Naisud Chairman', 'ibajay_naisud', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 35, 'Active', '2026-08-27 15:15:38'),
(59, 'Tagbaya Chairman', 'ibajay_tagbaya', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 36, 'Active', '2026-08-27 15:15:38'),
(60, 'Ondoy Chairman', 'ibajay_ondoy', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 37, 'Active', '2026-08-27 15:15:38'),
(61, 'San Isidro Chairman', 'ibajay_san_isidro', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 38, 'Active', '2026-08-27 15:15:38'),
(62, 'Polo Chairman', 'ibajay_polo', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 39, 'Active', '2026-08-27 15:15:38'),
(63, 'Maloco Chairman', 'ibajay_maloco', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 40, 'Active', '2026-08-27 15:15:38'),
(64, 'Buenavista Chairman', 'ibajay_buenavista', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 41, 'Active', '2026-08-27 15:15:38'),
(65, 'Laguinbanwa Chairman', 'ibajay_laguinbanwa', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 42, 'Active', '2026-08-27 15:15:38'),
(66, 'Tul-Ang Chairman', 'ibajay_tul_ang', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 43, 'Active', '2026-08-27 15:15:38'),
(67, 'Antipolo Chairman', 'ibajay_antipolo', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 44, 'Active', '2026-08-27 15:15:38'),
(68, 'Naligusan Chairman', 'ibajay_naligusan', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 45, 'Active', '2026-08-27 15:15:38'),
(69, 'Rizal Chairman', 'ibajay_rizal', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 46, 'Active', '2026-08-27 15:15:38'),
(70, 'Unat Chairman', 'ibajay_unat', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 47, 'Active', '2026-08-27 15:15:38'),
(71, 'Bagacay Chairman', 'ibajay_bagacay', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 48, 'Active', '2026-08-27 15:15:38'),
(72, 'Santa Cruz Chairman', 'ibajay_santa_cruz', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 49, 'Active', '2026-08-27 15:15:38'),
(73, 'Batuan Chairman', 'ibajay_batuan', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 50, 'Active', '2026-08-27 15:15:38'),
(74, 'Capilijan Chairman', 'ibajay_capilijan', '$2y$12$zDXzBY70yowVbIp7PGUTjeFTtBar9p9uxJQGBINBWamke.OfRO42G', 'barangay', 'captain', 1, 51, 'Active', '2026-08-27 15:15:38'),
(75, 'MDR Kalibo Admin', 'mdr_kalibo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pcf', 'mdr_kalibo', 0, NULL, 'Active', '2026-08-29 14:55:36'),
(76, 'MDR Ibajay Admin', 'mdr_ibajay', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pcf', 'mdr_ibajay', 0, NULL, 'Active', '2026-08-29 14:55:36'),
(77, 'Gwen Stacy', 'agbago_secretary', '$2y$10$w3S2FCyu89kNy2sBYRRg2.dtt5Delf9p/R09JtbN3ins2ADC5u9ye', 'barangay', 'secretary', 1, 32, 'Active', '2026-08-30 00:29:30'),
(78, 'Peter Parker', 'bhert_ibajay', '$2y$10$57cQjLbl.gMklRJfK8vsOO6EW9UwjEVg8bIc3mlsKBUvbSmow7tmm', 'barangay', 'tanod', 0, 32, 'Active', '2026-08-30 00:30:33'),
(79, 'PDRRMO', 'pdrrmo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pho', 'pdrrmo', 0, NULL, 'Active', '2026-08-30 06:37:51'),
(83, 'rizal bhert', 'rizal_bhert', '$2y$10$3sBzRizOJu6MK9fIhTfcU.h5275JWsRtEYK5Qu/lmpysndJzxoL2C', 'barangay', 'tanod', 0, 46, 'Active', '2026-09-05 13:50:04'),
(84, 'rizal bhert2', 'rizal_bhert2', '$2y$10$9IZquXRbSZjxzldCrO2zcunke7n22OBuHzfquuKRGY3PdB23aMyrW', 'barangay', 'tanod', 0, 46, 'Active', '2026-09-05 14:09:16'),
(85, 'Kalibo Mayor', 'mayor_kalibo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pcf', 'mayor_kalibo', 0, NULL, 'Active', '2026-09-06 11:52:49'),
(86, 'Ibajay Mayor', 'mayor_ibajay', '$2y$10$Gq1j0.DbHJtW0ymFxIx9Me8tNoMhGrS//KbJtlxFmlfBEVAX5vqL.', 'pcf', 'mayor_ibajay', 0, NULL, 'Active', '2026-09-06 11:52:49'),
(87, 'Aklan Governor', 'governor', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS', 'pho', 'governor', 0, NULL, 'Active', '2026-09-06 13:08:19'),
(93, 'yawan_secretary', 'yawan_secretary', '$2y$10$HiYUWDL7icuk.aiyQLCpqOCpDM4EemLT3ijrZAS6HdH5P5EWBcJBy', 'barangay', 'secretary', 1, 18, 'Active', '2026-09-07 00:50:31'),
(94, 'yawa bhert', 'yawan_bhert', '$2y$10$o.9GPu0Dnbaex8q6eP14ceY24WBzBBx6VI9m9fuNzFFRD/oq5Xjvi', 'barangay', 'tanod', 0, 18, 'Active', '2026-09-07 00:51:32'),
(95, 'aslum secretary', 'aslum_secretary', '$2y$10$IjAPaWHZHsIhgPmmw3C7ne8W1OaDJWamcWxf0ZJlYO2s2vUSoix5W', 'barangay', 'secretary', 1, 20, 'Active', '2026-09-07 01:12:12'),
(96, 'aslum bhert', 'aslum_bhert', '$2y$10$rH8VXC8JKVxSTCNdScAVpOawl0K9gKeEYk39BfM47cz8IHLjoBkuu', 'barangay', 'tanod', 0, 20, 'Active', '2026-09-07 01:12:46'),
(97, 'poblacion', 'poblacion_secretary', '$2y$10$JT.Un2dlQlIoPMaw7CsHYuY5n8qwh6v2eOMozFfjKU1g26Nbxt3o.', 'barangay', 'secretary', 1, 33, 'Active', '2026-09-07 01:15:53'),
(98, 'poblacion bhert', 'poblacion bhert', '$2y$10$zQwfgh2u3/weYfmk6dsDyep18Wy4jFIGWhVFXm0Xyzai5g.fBw4/O', 'barangay', 'tanod', 0, 33, 'Active', '2026-09-07 01:17:02'),
(99, 'pob bhert', 'pob_bhert2', '$2y$10$OyAHGE0ucd1eDItylCBgiuxGiNgF3GRq5LCcSAdOKHYBcTgD1t2U.', 'barangay', 'tanod', 0, 33, 'Active', '2026-09-07 01:19:14'),
(100, 'colong2x', 'colong2x_sec', '$2y$10$TuwpXS4XUVD4jFXYvQ3XPOmmw0v8FlkoXvYMBzT8VIUAGbmOl.h8i', 'barangay', 'secretary', 1, 34, 'Active', '2026-09-07 01:22:24'),
(101, 'colong2x bhert', 'colong2x_bhert', '$2y$10$ETX4ApfFAfFGocetHZdlHOCkUtbBx9XidVLigwkaH1dZ.ljMQDsnu', 'barangay', 'tanod', 0, 34, 'Active', '2026-09-07 01:22:59'),
(102, 'ondoy sec', 'ondoy_sec', '$2y$10$ml9NuIszlIr0/z6VE7olmuaQfWDAwfCeF/fPLyxP5pqiqzyF7SRdG', 'barangay', 'secretary', 1, 37, 'Active', '2026-09-07 01:28:05'),
(103, 'ondoy_bhert', 'ondoy_bhert', '$2y$10$tIXw6luGT7MMYanETtL52e0L45G5pFtzbo4r8zehNxM/UnaXilSc2', 'barangay', 'tanod', 0, 37, 'Active', '2026-09-07 01:31:08'),
(104, 'rivera sec', 'rivera_secretary', '$2y$10$91ihvHFJ5qq8PLR8RObYZOU.IInGxz.NDtWFU9LQux.mQd.Acwqo.', 'barangay', 'secretary', 1, 25, 'Active', '2026-09-07 14:24:30'),
(105, 'rivera bhert', 'rivera_bhert', '$2y$10$sHPbxACi0TBt52E4GTPGDuThhTprHAC087DLC5KAAhZ2SybjOP/rq', 'barangay', 'tanod', 0, 25, 'Active', '2026-09-07 14:26:01'),
(106, 'ondoy bhert2', 'ondoy_bhert2', '$2y$10$TzdD6sfPCpXPGbh5oeIAb.nhEHq/cm5JVhDceAx0ZWjAjO.5EvY52', 'barangay', 'tanod', 0, 37, 'Active', '2026-09-08 13:46:58'),
(107, 'nausid sec', 'naisud_sec', '$2y$10$lhCpcGezOIl.O.fNqxR/G.8weyAZdWC83wPafKx9CyHG1xNoHJ9ra', 'barangay', 'secretary', 1, 35, 'Active', '2026-09-09 13:19:09'),
(108, 'naisudbhert', 'naisud_bhert', '$2y$10$OI9zdeeiteKDjjQQTQTn/u5bHxJsl9t56VwCGSlg8EvIQEk3UQ7QS', 'barangay', 'tanod', 0, 35, 'Active', '2026-09-09 13:19:29'),
(109, 'tulang sec', 'tulang_sec', '$2y$10$rYp8RSkPIurHkPzp4xx52OvHpofS2WteW9qfQbYJGQhOMXa6pU5dC', 'barangay', 'secretary', 1, 43, 'Active', '2026-09-10 02:56:00'),
(110, 'tulang bhert', 'tulang_bhert', '$2y$10$/rL2r06IPCgDIh9PjFl3BuMcwXQ3pwD/jb5YeAN/EVx8SmuwTYCEq', 'barangay', 'tanod', 0, 43, 'Active', '2026-09-10 02:56:25'),
(111, 'vista sec', 'vista_sec', '$2y$10$76T1/fPM95XSs5W9SE2CLeT9IamKjRzliHbmB2b4bZvcfnD4siufu', 'barangay', 'secretary', 1, 41, 'Active', '2026-09-10 12:21:39'),
(112, 'vista bhert', 'vista_bhert', '$2y$10$8pUob5H.yVFp/7GJ8W/oPeTJR9opvSxnumBon9U8H9ccFrnBzL1O.', 'barangay', 'tanod', 0, 41, 'Active', '2026-09-10 12:21:54'),
(113, 'sc sec', 'sc_sec', '$2y$10$Gnv7S4FgzCzuYExcbqqgn.MF.eFqArGvvkmcGRawL5XbXZwujcE8O', 'barangay', 'secretary', 1, 49, 'Active', '2026-09-11 11:18:14'),
(114, 'sc bhert', 'sc_bhert', '$2y$10$XnibxuDiEeSqwRDB7mKZYONv0tv/MLhTdLMSmXfUxvJH96LvjLSe.', 'barangay', 'tanod', 0, 49, 'Active', '2026-09-11 11:18:27'),
(115, 'scbhert', 'sc_bhert2', '$2y$10$LrBo7f/Q8sU5h0qQvPgD3.CutmoUP8Enjo73BhNYHVR/ErNHxve5C', 'barangay', 'tanod', 0, 49, 'Active', '2026-09-11 13:13:19'),
(116, 'rizal sec', 'rizal_sec', '$2y$10$hxFGdfi3YynFGhfr4QU6tereiPOKIEwCV.tU90QJVPDX3/.doLzPS', 'barangay', 'secretary', 1, 46, 'Active', '2026-09-12 10:08:09'),
(117, 'naisudbhert2', 'naisud_bhert2', '$2y$10$8LU0Lkf/UnKfn9b3bZdKhuJtrJIEgvHLLqCoLajftB1BCjNwWbMiO', 'barangay', 'tanod', 0, 35, 'Active', '2026-09-12 12:35:20'),
(118, 'polo sec', 'polo_sec', '$2y$10$IlLrRARCk4PrFgunFNJLJejDSpz7OGVPsUm8gmri9m86BBDebcxqy', 'barangay', 'secretary', 1, 39, 'Active', '2026-09-12 12:44:37'),
(119, 'polo bhert', 'polo_bhert', '$2y$10$VvmkKO73rJ6.tRh2QHSbpe.XOyXKfvV5Om0SQuOKNA9CgbhUVNVWS', 'barangay', 'tanod', 0, 39, 'Active', '2026-09-12 12:44:55'),
(120, 'polobhert2', 'polo_bhert2', '$2y$10$awNK9J9oA66EphFMgz9Yj.h0zDEPiPMXYQQAIBLh6OiHWAOKsjpm6', 'barangay', 'tanod', 0, 39, 'Active', '2026-09-12 12:45:11'),
(121, 'atsec', 'at_sec', '$2y$10$UaxNK65qUJ/qLYZ4Ti34jeST0D8/hJphZcNyTMGHbepdimXXZWSiS', 'barangay', 'secretary', 1, 44, 'Active', '2026-09-12 14:08:00'),
(122, 'atbhert', 'at_bhert', '$2y$10$jmSJ93g.J6MpxHzAvtd99.D6yFboKrWNuAZcSanQ.k3r6cpBJvQ9C', 'barangay', 'tanod', 0, 44, 'Active', '2026-09-12 14:08:12'),
(123, 'atbhert2', 'at_bhert2', '$2y$10$2MSWJhbNRZN8ZUTaA6iEtu//hL0VX65idK6BboEnKudTrPhSTuNne', 'barangay', 'tanod', 0, 44, 'Active', '2026-09-12 14:08:23'),
(124, 'yawan_bhert2', 'yawan_bhert2', '$2y$10$bj8biai2T9Ic4NQvglYY/.GMhVbnV2446qYrKBNYzNjeE904SSd.i', 'barangay', 'tanod', 0, 18, 'Active', '2026-09-13 01:30:33'),
(125, 'maloco', 'maloco_sec', '$2y$10$9ucY.20gYqDaITTAwyn0I.8TjI8l6CCC8C7zeTOTfcHmdidJ7NoZS', 'barangay', 'secretary', 1, 40, 'Active', '2026-09-13 09:23:08'),
(126, 'malocobhert', 'maloco_bhert', '$2y$10$cCVHLRnsCrfzvpighkb2R.DrnODze9X5V8KAIGfYVzBtdajc870ES', 'barangay', 'tanod', 0, 40, 'Active', '2026-09-13 09:23:47'),
(127, 'unatbhert', 'unatbhert', '$2y$10$Z5PidPY32CHk5YCNOd/.eOAcHPwAcgBPofB/QdHW6FXR/G5Em7Hh6', 'barangay', 'tanod', 0, 47, 'Active', '2026-09-17 13:16:21');

-- --------------------------------------------------------

--
-- Table structure for table `user_activity_logs`
--

CREATE TABLE `user_activity_logs` (
  `id` int(11) NOT NULL,
  `actor_id` int(11) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `action` varchar(50) NOT NULL,
  `target_user_id` int(11) DEFAULT NULL,
  `target_username` varchar(50) DEFAULT NULL,
  `details` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `user_activity_logs`
--

INSERT INTO `user_activity_logs` (`id`, `actor_id`, `actor_name`, `action`, `target_user_id`, `target_username`, `details`, `created_at`) VALUES
(1, 1, 'Super Administrator', 'deactivate', 4, 'andagaw', 'Account set to Inactive', '2026-06-14 10:23:39'),
(2, 1, 'Super Administrator', 'reactivate', 4, 'andagaw', 'Account set to Active', '2026-06-14 10:32:59'),
(3, 4, 'Andagaw Barangay Account', 'create', 20, 'andagaw_secretary', 'Created barangay/secretary account', '2026-08-20 15:48:06'),
(4, 4, 'Andagaw Barangay Account', 'create', 21, 'andagaw_tanod1', 'Created barangay/tanod account', '2026-08-20 15:48:24'),
(5, 20, 'Andagaw Secretary', 'create', 22, 'andagaw_tanod2', 'Created barangay/tanod account', '2026-08-20 15:48:34'),
(6, 20, 'Andagaw Secretary', 'create', 23, 'fake_captain', 'Created barangay/captain account', '2026-08-20 15:48:44'),
(7, 4, 'Andagaw Barangay Account', 'create', 24, 'andagaw_secretary', 'Created barangay/secretary account', '2026-08-20 15:50:35'),
(8, 4, 'Andagaw Barangay Account', 'create', 25, 'andagaw_secretary', 'Created barangay/secretary account', '2026-08-20 15:52:50'),
(9, 4, 'Andagaw Barangay Account', 'create', 29, 'debug_test', 'Created barangay/captain account', '2026-08-20 15:55:18'),
(10, 4, 'Andagaw Barangay Account', 'create', 30, 'test_sec', 'Created barangay/secretary account', '2026-08-20 15:57:55'),
(11, 4, 'Andagaw Barangay Account', 'create', 33, 'sec_fixed', 'Created barangay/secretary account', '2026-08-20 16:00:34'),
(12, 4, 'Andagaw Barangay Account', 'create', 34, 'andagaw_secretary', 'Created barangay/secretary account', '2026-08-20 16:01:26'),
(13, 4, 'Andagaw Barangay Account', 'create', 35, 'andagaw_tanod1', 'Created barangay/tanod account', '2026-08-20 16:01:35'),
(14, 34, 'Andagaw Secretary', 'create', 36, 'andagaw_tanod2', 'Created barangay/tanod account', '2026-08-20 16:01:41'),
(15, 1, 'Super Administrator', 'create', 37, 'test_sec', 'Created barangay/secretary account', '2026-08-20 16:28:41'),
(16, 1, 'Super Administrator', 'create', 38, 'test_sec', 'Created barangay/secretary account', '2026-08-20 16:29:11'),
(17, 1, 'Super Administrator', 'create', 39, 'test_tanod', 'Created barangay/tanod account', '2026-08-20 16:29:18'),
(18, 4, 'Andagaw Barangay Account', 'update', 34, 'andagaw_secretary', 'Updated details / role = barangay (secretary)', '2026-08-21 12:47:10'),
(19, 1, 'Super Administrator', 'update', 2, 'pcfadmin', 'Updated details / role = pcf', '2026-08-22 04:27:06'),
(20, 1, 'Super Administrator', 'update', 2, 'pcfadmin', 'Updated details / role = pcf', '2026-08-24 13:54:11'),
(21, 1, 'Super Administrator', 'update', 3, 'phoadmin', 'Updated details / role = pho', '2026-08-24 13:54:21'),
(22, 55, 'Agbago Chairman', 'create', 77, 'agbago_secretary', 'Created barangay (secretary) account', '2026-08-30 00:29:30'),
(23, 77, 'Gwen Stacy', 'create', 78, 'bhert_ibajay', 'Created barangay (tanod) account', '2026-08-30 00:30:33'),
(29, 69, 'Rizal Chairman', 'create', 83, 'rizal_bhert', 'Created barangay/tanod account', '2026-09-05 13:50:04'),
(30, 69, 'Rizal Chairman', 'create', 84, 'rizal_bhert2', 'Created barangay/tanod account', '2026-09-05 14:09:16'),
(31, 2, 'MDR Admin', 'reset_password', 86, 'mayor_ibajay', 'Reset password', '2026-09-06 12:17:46'),
(32, 3, 'Provincial Admin', 'create', 88, 'govtest', 'Created pho account', '2026-09-06 13:24:39'),
(33, 4, 'Andagaw Barangay Account', 'create', 89, 'tanodt2706', 'Created barangay/tanod account', '2026-09-07 00:43:01'),
(34, 4, 'Andagaw Barangay Account', 'create', 90, 'sect2706', 'Created barangay/secretary account', '2026-09-07 00:43:02'),
(35, 90, 'Sec Test 2706', 'create', 91, 'stanod8633', 'Created barangay/tanod account', '2026-09-07 00:43:30'),
(36, 4, 'Andagaw Barangay Account', 'create', 92, 'websec6215', 'Created barangay (secretary) account', '2026-09-07 00:44:11'),
(37, 4, 'Andagaw Barangay Account', 'update', 35, 'andagaw_tanod1', 'Updated user details', '2026-09-07 00:48:52'),
(38, 41, 'Yawan Chairman', 'create', 93, 'yawan_secretary', 'Created barangay/secretary account', '2026-09-07 00:50:31'),
(39, 93, 'yawan_secretary', 'create', 94, 'yawan_bhert', 'Created barangay/tanod account', '2026-09-07 00:51:32'),
(40, 43, 'Aslum Chairman', 'create', 95, 'aslum_secretary', 'Created barangay/secretary account', '2026-09-07 01:12:12'),
(41, 95, 'aslum secretary', 'create', 96, 'aslum_bhert', 'Created barangay/tanod account', '2026-09-07 01:12:46'),
(42, 56, 'Poblacion Chairman', 'create', 97, 'poblacion_secretary', 'Created barangay/secretary account', '2026-09-07 01:15:53'),
(43, 97, 'poblacion', 'create', 98, 'poblacion bhert', 'Created barangay/tanod account', '2026-09-07 01:17:02'),
(44, 56, 'Poblacion Chairman', 'create', 99, 'pob_bhert2', 'Created barangay/tanod account', '2026-09-07 01:19:14'),
(45, 57, 'Colongcolong Chairman', 'create', 100, 'colong2x', 'Created barangay/secretary account', '2026-09-07 01:22:24'),
(46, 57, 'Colongcolong Chairman', 'update', 100, 'colong2x_sec', 'Updated user details', '2026-09-07 01:22:39'),
(47, 57, 'Colongcolong Chairman', 'create', 101, 'colong2x_bhert', 'Created barangay/tanod account', '2026-09-07 01:22:59'),
(48, 60, 'Ondoy Chairman', 'create', 102, 'ondoy_sec', 'Created barangay/secretary account', '2026-09-07 01:28:05'),
(49, 102, 'ondoy sec', 'create', 103, 'ondoy_bhert', 'Created barangay/tanod account', '2026-09-07 01:31:08'),
(50, 48, 'Rivera Chairman', 'create', 104, 'rivera_secretary', 'Created barangay/secretary account', '2026-09-07 14:24:30'),
(51, 104, 'rivera sec', 'create', 105, 'rivera_bhert', 'Created barangay/tanod account', '2026-09-07 14:26:01'),
(52, 102, 'ondoy sec', 'create', 106, 'ondoy_bhert2', 'Created barangay/tanod account', '2026-09-08 13:46:58'),
(53, 58, 'Naisud Chairman', 'create', 107, 'naisud_sec', 'Created barangay/secretary account', '2026-09-09 13:19:09'),
(54, 58, 'Naisud Chairman', 'create', 108, 'naisud_bhert', 'Created barangay/tanod account', '2026-09-09 13:19:29'),
(55, 66, 'Tul-Ang Chairman', 'create', 109, 'tulang_sec', 'Created barangay/secretary account', '2026-09-10 02:56:00'),
(56, 66, 'Tul-Ang Chairman', 'create', 110, 'tulang_bhert', 'Created barangay/tanod account', '2026-09-10 02:56:25'),
(57, 64, 'Buenavista Chairman', 'create', 111, 'vista_sec', 'Created barangay/secretary account', '2026-09-10 12:21:39'),
(58, 64, 'Buenavista Chairman', 'create', 112, 'vista_bhert', 'Created barangay/tanod account', '2026-09-10 12:21:54'),
(59, 72, 'Santa Cruz Chairman', 'create', 113, 'sc_sec', 'Created barangay/secretary account', '2026-09-11 11:18:14'),
(60, 72, 'Santa Cruz Chairman', 'create', 114, 'sc_bhert', 'Created barangay/tanod account', '2026-09-11 11:18:27'),
(61, 113, 'sc sec', 'create', 115, 'sc_bhert2', 'Created barangay/tanod account', '2026-09-11 13:13:19'),
(62, 69, 'Rizal Chairman', 'create', 116, 'rizal_sec', 'Created barangay/secretary account', '2026-09-12 10:08:09'),
(63, 58, 'Naisud Chairman', 'create', 117, 'naisud_bhert2', 'Created barangay/tanod account', '2026-09-12 12:35:20'),
(64, 62, 'Polo Chairman', 'create', 118, 'polo_sec', 'Created barangay/secretary account', '2026-09-12 12:44:37'),
(65, 62, 'Polo Chairman', 'create', 119, 'polo_bhert', 'Created barangay/tanod account', '2026-09-12 12:44:55'),
(66, 62, 'Polo Chairman', 'create', 120, 'polo_bhert2', 'Created barangay/tanod account', '2026-09-12 12:45:11'),
(67, 62, 'Polo Chairman', 'reset_password', 118, 'polo_sec', 'Reset password', '2026-09-12 12:54:11'),
(68, 67, 'Antipolo Chairman', 'create', 121, 'at_sec', 'Created barangay/secretary account', '2026-09-12 14:08:00'),
(69, 67, 'Antipolo Chairman', 'create', 122, 'at_bhert', 'Created barangay/tanod account', '2026-09-12 14:08:12'),
(70, 67, 'Antipolo Chairman', 'create', 123, 'at_bhert2', 'Created barangay/tanod account', '2026-09-12 14:08:23'),
(71, 41, 'Yawan Chairman', 'create', 124, 'yawan_bhert2', 'Created barangay/tanod account', '2026-09-13 01:30:33'),
(72, 63, 'Maloco Chairman', 'create', 125, 'maloco_sec', 'Created barangay/tanod account', '2026-09-13 09:23:08'),
(73, 63, 'Maloco Chairman', 'update', 125, 'maloco_sec', 'Updated user details', '2026-09-13 09:23:30'),
(74, 63, 'Maloco Chairman', 'create', 126, 'maloco_bhert', 'Created barangay/tanod account', '2026-09-13 09:23:47'),
(75, 70, 'Unat Chairman', 'create', 127, 'unatbhert', 'Created barangay/tanod account', '2026-09-17 13:16:21');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `alerts`
--
ALTER TABLE `alerts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `alert_barangays`
--
ALTER TABLE `alert_barangays`
  ADD PRIMARY KEY (`id`),
  ADD KEY `alert_id` (`alert_id`),
  ADD KEY `barangay_id` (`barangay_id`);

--
-- Indexes for table `alert_reads`
--
ALTER TABLE `alert_reads`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_alert_read_user` (`alert_id`,`user_id`);

--
-- Indexes for table `barangays`
--
ALTER TABLE `barangays`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `disaster_types`
--
ALTER TABLE `disaster_types`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `emergency_hotlines`
--
ALTER TABLE `emergency_hotlines`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_hotline_scope` (`hotline_scope`),
  ADD KEY `idx_hotline_barangay` (`barangay_id`);

--
-- Indexes for table `evacuation_centers`
--
ALTER TABLE `evacuation_centers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `evac_assistance`
--
ALTER TABLE `evac_assistance`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_evac_center` (`evac_center_id`),
  ADD KEY `idx_donor` (`donor_user_id`),
  ADD KEY `idx_need_id` (`need_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_received` (`received_at`);

--
-- Indexes for table `evac_center_needs`
--
ALTER TABLE `evac_center_needs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_evac_center` (`evac_center_id`);

--
-- Indexes for table `evac_center_profile`
--
ALTER TABLE `evac_center_profile`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_evac_center` (`evac_center_id`);

--
-- Indexes for table `incident_attachments`
--
ALTER TABLE `incident_attachments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `incident_report_id` (`incident_report_id`),
  ADD KEY `uploaded_by` (`uploaded_by`);

--
-- Indexes for table `incident_reports`
--
ALTER TABLE `incident_reports`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_incident_reports_client_uuid` (`client_uuid`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `barangay_id` (`barangay_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- Indexes for table `incident_status_logs`
--
ALTER TABLE `incident_status_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `incident_report_id` (`incident_report_id`),
  ADD KEY `updated_by` (`updated_by`);

--
-- Indexes for table `pcf_facilities`
--
ALTER TABLE `pcf_facilities`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD KEY `barangay_id` (`barangay_id`);

--
-- Indexes for table `user_activity_logs`
--
ALTER TABLE `user_activity_logs`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `alerts`
--
ALTER TABLE `alerts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `alert_barangays`
--
ALTER TABLE `alert_barangays`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `alert_reads`
--
ALTER TABLE `alert_reads`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `barangays`
--
ALTER TABLE `barangays`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=52;

--
-- AUTO_INCREMENT for table `disaster_types`
--
ALTER TABLE `disaster_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `emergency_hotlines`
--
ALTER TABLE `emergency_hotlines`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=63;

--
-- AUTO_INCREMENT for table `evacuation_centers`
--
ALTER TABLE `evacuation_centers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT for table `evac_assistance`
--
ALTER TABLE `evac_assistance`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=68;

--
-- AUTO_INCREMENT for table `evac_center_needs`
--
ALTER TABLE `evac_center_needs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT for table `evac_center_profile`
--
ALTER TABLE `evac_center_profile`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=35;

--
-- AUTO_INCREMENT for table `incident_attachments`
--
ALTER TABLE `incident_attachments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `incident_reports`
--
ALTER TABLE `incident_reports`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=120;

--
-- AUTO_INCREMENT for table `incident_status_logs`
--
ALTER TABLE `incident_status_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=222;

--
-- AUTO_INCREMENT for table `pcf_facilities`
--
ALTER TABLE `pcf_facilities`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=128;

--
-- AUTO_INCREMENT for table `user_activity_logs`
--
ALTER TABLE `user_activity_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=76;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `alerts`
--
ALTER TABLE `alerts`
  ADD CONSTRAINT `alerts_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `alert_barangays`
--
ALTER TABLE `alert_barangays`
  ADD CONSTRAINT `alert_barangays_ibfk_1` FOREIGN KEY (`alert_id`) REFERENCES `alerts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `alert_barangays_ibfk_2` FOREIGN KEY (`barangay_id`) REFERENCES `barangays` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `incident_attachments`
--
ALTER TABLE `incident_attachments`
  ADD CONSTRAINT `incident_attachments_ibfk_1` FOREIGN KEY (`incident_report_id`) REFERENCES `incident_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `incident_attachments_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `incident_reports`
--
ALTER TABLE `incident_reports`
  ADD CONSTRAINT `incident_reports_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `incident_reports_ibfk_2` FOREIGN KEY (`barangay_id`) REFERENCES `barangays` (`id`);

--
-- Constraints for table `incident_status_logs`
--
ALTER TABLE `incident_status_logs`
  ADD CONSTRAINT `incident_status_logs_ibfk_1` FOREIGN KEY (`incident_report_id`) REFERENCES `incident_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `incident_status_logs_ibfk_2` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`barangay_id`) REFERENCES `barangays` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
