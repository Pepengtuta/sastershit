-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: capstone
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `evac_assistance`
--

DROP TABLE IF EXISTS `evac_assistance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `evac_assistance` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `need_id` int(11) DEFAULT NULL,
  `donor_user_id` int(11) NOT NULL,
  `donor_label` varchar(120) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty` int(11) NOT NULL DEFAULT 0,
  `status` enum('Pledged','Sent','Delivered') NOT NULL DEFAULT 'Pledged',
  `pledged_at` timestamp NULL DEFAULT NULL,
  `sent_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_evac_center` (`evac_center_id`),
  KEY `idx_donor` (`donor_user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `evac_assistance`
--

LOCK TABLES `evac_assistance` WRITE;
/*!40000 ALTER TABLE `evac_assistance` DISABLE KEYS */;
INSERT INTO `evac_assistance` VALUES (13,21,30,76,'MDRRMO Ibajay','rice','',25,'Delivered','2026-09-08 14:09:58','2026-09-10 01:22:12','2026-09-10 01:22:12','ongoing',0,'2026-09-08 14:09:58'),(14,21,32,76,'MDRRMO Ibajay','water','',100,'Delivered','2026-09-10 01:19:48','2026-09-10 01:21:37','2026-09-10 01:21:37','',0,'2026-09-10 01:19:48'),(15,21,32,76,'MDRRMO Ibajay','water','',100,'Delivered','2026-09-10 01:19:57','2026-09-10 01:21:48','2026-09-10 01:21:48','',0,'2026-09-10 01:19:57');
/*!40000 ALTER TABLE `evac_assistance` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-10  9:37:19
