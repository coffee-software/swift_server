CREATE TABLE run_errors (
    `app_id` INT NOT NULL,
    `handler` VARCHAR(255) NOT NULL,
    `location` VARCHAR(255) NOT NULL,

    `status` VARCHAR(255) NOT NULL,
    `current_count` int NOT NULL DEFAULT 1,
    `total_count` int NOT NULL DEFAULT 1,

    `first_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `first_message` TEXT NULL,
    `first_stack` TEXT NULL,
    `first_request` TEXT NULL,

    `last_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `last_message` TEXT NULL,
    `last_stack` TEXT NULL,
    `last_request` TEXT NULL,

    `comment` TEXT NULL,
    PRIMARY KEY(app_id, handler, location)
);

CREATE TABLE run_queues (
    `app_id` INT NOT NULL,
    `queue` VARCHAR(255) NOT NULL,
    `process_count` int NOT NULL DEFAULT 1,
    `last_process` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(app_id, queue)
);

CREATE TABLE run_jobs (
    `app_id` INT NOT NULL,
    `job` VARCHAR(255) NOT NULL,
    `run_count` int NOT NULL DEFAULT 1,
    `last_run` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(app_id, job)
);

CREATE TABLE run_stats (
    `time` DATETIME,
    `app_id` INT NOT NULL,
    `sub_id` INT NOT NULL,
    `handler` VARCHAR(255) NOT NULL,

    `count` INT NOT NULL,

    `max_queries` INT NOT NULL,
    `total_queries` FLOAT NOT NULL,
    `max_time` INT NOT NULL,
    `total_time` FLOAT NOT NULL,

    PRIMARY KEY(`time`, `app_id`, `sub_id`, `handler`),
    INDEX(`handler`)
);