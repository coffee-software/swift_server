--
-- Table structure for table `run_errors`
--

DROP TABLE IF EXISTS `run_errors`;
CREATE TABLE `run_errors` (
  `app_id` int(11) NOT NULL,
  `handler` varchar(255) NOT NULL,
  `location` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `current_count` int(11) NOT NULL DEFAULT 1,
  `total_count` int(11) NOT NULL DEFAULT 1,
  `first_time` datetime DEFAULT current_timestamp(),
  `first_message` text DEFAULT NULL,
  `first_stack` text DEFAULT NULL,
  `first_request` text DEFAULT NULL,
  `last_time` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_message` text DEFAULT NULL,
  `last_stack` text DEFAULT NULL,
  `last_request` text DEFAULT NULL,
  `comment` text DEFAULT NULL,
  PRIMARY KEY (`app_id`,`handler`,`location`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Table structure for table `run_jobs`
--

DROP TABLE IF EXISTS `run_jobs`;
CREATE TABLE `run_jobs` (
  `app_id` int(11) NOT NULL,
  `job` varchar(255) NOT NULL,
  `run_count` int(11) NOT NULL DEFAULT 1,
  `last_run` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`app_id`,`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Table structure for table `run_queues`
--

DROP TABLE IF EXISTS `run_queues`;
CREATE TABLE `run_queues` (
  `app_id` int(11) NOT NULL,
  `queue` varchar(255) NOT NULL,
  `process_count` int(11) NOT NULL DEFAULT 1,
  `last_process` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`app_id`,`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
