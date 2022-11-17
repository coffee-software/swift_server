--
-- Table structure for table `run_errors`
--

DROP TABLE IF EXISTS `run_errors`;
CREATE TABLE `run_errors` (
  `app_id` int NOT NULL,
  `handler` varchar(255) NOT NULL,
  `location` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `current_count` int NOT NULL DEFAULT '1',
  `total_count` int NOT NULL DEFAULT '1',
  `first_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `first_message` text,
  `first_stack` text,
  `first_request` text,
  `last_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_message` text,
  `last_stack` text,
  `last_request` text,
  `comment` text,
  PRIMARY KEY (`app_id`,`handler`,`location`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Table structure for table `run_jobs`
--

DROP TABLE IF EXISTS `run_jobs`;
CREATE TABLE `run_jobs` (
  `app_id` int NOT NULL,
  `job` varchar(255) NOT NULL,
  `run_count` int NOT NULL DEFAULT '1',
  `last_run` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`app_id`,`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Table structure for table `run_queues`
--

DROP TABLE IF EXISTS `run_queues`;
CREATE TABLE `run_queues` (
  `app_id` int NOT NULL,
  `queue` varchar(255) NOT NULL,
  `process_count` int NOT NULL DEFAULT '1',
  `last_process` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`app_id`,`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Table structure for table `run_stats`
--

DROP TABLE IF EXISTS `run_stats`;
CREATE TABLE `run_stats` (
  `time` datetime NOT NULL,
  `app_id` int NOT NULL,
  `sub_id` int NOT NULL,
  `handler` varchar(255) NOT NULL,
  `count` int NOT NULL,
  `max_queries` int NOT NULL,
  `total_queries` float NOT NULL,
  `max_time` int NOT NULL,
  `total_time` float NOT NULL,
  PRIMARY KEY (`time`,`app_id`,`sub_id`,`handler`),
  KEY `handler` (`handler`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
