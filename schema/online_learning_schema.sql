-- Online Learning Platform schema (MySQL 8.0+)
-- Normalized to 3NF with audit-friendly event tables and operational constraints.

CREATE DATABASE IF NOT EXISTS online_learning
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE online_learning;

SET sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

CREATE TABLE students (
  student_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  external_ref VARCHAR(64) NULL,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  email VARCHAR(254) NOT NULL,
  phone VARCHAR(30) NULL,
  timezone VARCHAR(64) NULL,
  status ENUM('active','suspended','deleted') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id),
  UNIQUE KEY uq_students_email (email),
  UNIQUE KEY uq_students_external_ref (external_ref)
) ENGINE=InnoDB;

CREATE TABLE instructors (
  instructor_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  email VARCHAR(254) NOT NULL,
  bio TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (instructor_id),
  UNIQUE KEY uq_instructors_email (email)
) ENGINE=InnoDB;

CREATE TABLE courses (
  course_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  course_code VARCHAR(40) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  course_type ENUM('free','paid') NOT NULL,
  instructor_id BIGINT UNSIGNED NOT NULL,
  duration_minutes INT UNSIGNED NOT NULL,
  price_amount DECIMAL(10,2) NULL,
  currency_code CHAR(3) NULL,
  pass_percentage DECIMAL(5,2) NOT NULL DEFAULT 60.00,
  max_attempts TINYINT UNSIGNED NOT NULL DEFAULT 3,
  is_published TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (course_id),
  UNIQUE KEY uq_courses_code (course_code),
  KEY idx_courses_instructor (instructor_id),
  CONSTRAINT fk_courses_instructor
    FOREIGN KEY (instructor_id) REFERENCES instructors(instructor_id),
  CONSTRAINT chk_course_price_rules
    CHECK (
      (course_type = 'free' AND price_amount IS NULL AND currency_code IS NULL)
      OR
      (course_type = 'paid' AND price_amount IS NOT NULL AND price_amount > 0 AND currency_code IS NOT NULL)
    ),
  CONSTRAINT chk_pass_percentage CHECK (pass_percentage > 0 AND pass_percentage <= 100),
  CONSTRAINT chk_max_attempts CHECK (max_attempts >= 1)
) ENGINE=InnoDB;

CREATE TABLE lessons (
  lesson_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  course_id BIGINT UNSIGNED NOT NULL,
  lesson_no TINYINT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  objective TEXT NULL,
  is_published TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (lesson_id),
  UNIQUE KEY uq_lessons_course_no (course_id, lesson_no),
  KEY idx_lessons_course (course_id),
  CONSTRAINT fk_lessons_course
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
      ON DELETE CASCADE,
  CONSTRAINT chk_lesson_no CHECK (lesson_no BETWEEN 1 AND 12)
) ENGINE=InnoDB;

CREATE TABLE lesson_content (
  content_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lesson_id BIGINT UNSIGNED NOT NULL,
  content_type ENUM('text','image','video') NOT NULL,
  body_text MEDIUMTEXT NULL,
  media_url VARCHAR(1024) NULL,
  display_order SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (content_id),
  KEY idx_lesson_content_lesson (lesson_id),
  KEY idx_lesson_content_type (content_type),
  CONSTRAINT fk_lesson_content_lesson
    FOREIGN KEY (lesson_id) REFERENCES lessons(lesson_id)
      ON DELETE CASCADE,
  CONSTRAINT chk_lesson_content_payload
    CHECK (
      (content_type = 'text' AND body_text IS NOT NULL)
      OR
      (content_type IN ('image','video') AND media_url IS NOT NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  course_id BIGINT UNSIGNED NOT NULL,
  gateway_ref VARCHAR(80) NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  payment_status ENUM('pending','completed','failed','refunded') NOT NULL,
  paid_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (payment_id),
  UNIQUE KEY uq_gateway_ref (gateway_ref),
  KEY idx_payments_student_course_status (student_id, course_id, payment_status),
  CONSTRAINT fk_payments_student FOREIGN KEY (student_id) REFERENCES students(student_id),
  CONSTRAINT fk_payments_course FOREIGN KEY (course_id) REFERENCES courses(course_id),
  CONSTRAINT chk_payment_amount CHECK (amount > 0)
) ENGINE=InnoDB;

CREATE TABLE enrollments (
  enrollment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  course_id BIGINT UNSIGNED NOT NULL,
  subscription_type ENUM('free','paid') NOT NULL,
  enrollment_status ENUM('in_progress','completed','abandoned') NOT NULL DEFAULT 'in_progress',
  enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (enrollment_id),
  UNIQUE KEY uq_enrollment_student_course (student_id, course_id),
  KEY idx_enrollments_active (student_id, enrollment_status),
  KEY idx_enrollments_course_status (course_id, enrollment_status),
  CONSTRAINT fk_enrollment_student FOREIGN KEY (student_id) REFERENCES students(student_id),
  CONSTRAINT fk_enrollment_course FOREIGN KEY (course_id) REFERENCES courses(course_id),
  CONSTRAINT chk_completed_at_required
    CHECK (
      (enrollment_status = 'completed' AND completed_at IS NOT NULL)
      OR
      (enrollment_status IN ('in_progress','abandoned'))
    )
) ENGINE=InnoDB;

CREATE TABLE lesson_progress (
  progress_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  lesson_id BIGINT UNSIGNED NOT NULL,
  first_access_at DATETIME NULL,
  last_access_at DATETIME NULL,
  completion_status ENUM('not_started','in_progress','completed') NOT NULL DEFAULT 'not_started',
  completed_at DATETIME NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (progress_id),
  UNIQUE KEY uq_progress_enrollment_lesson (enrollment_id, lesson_id),
  KEY idx_progress_lookup (enrollment_id, completion_status),
  KEY idx_progress_lesson (lesson_id),
  CONSTRAINT fk_progress_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE,
  CONSTRAINT fk_progress_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(lesson_id),
  CONSTRAINT chk_progress_completed
    CHECK (
      (completion_status = 'completed' AND completed_at IS NOT NULL)
      OR
      (completion_status IN ('not_started','in_progress'))
    )
) ENGINE=InnoDB;

CREATE TABLE lesson_access_logs (
  access_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  lesson_id BIGINT UNSIGNED NOT NULL,
  accessed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  access_source ENUM('web','mobile','api','other') NOT NULL DEFAULT 'web',
  metadata JSON NULL,
  PRIMARY KEY (access_log_id),
  KEY idx_access_enrollment_time (enrollment_id, accessed_at),
  KEY idx_access_lesson_time (lesson_id, accessed_at),
  CONSTRAINT fk_access_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE,
  CONSTRAINT fk_access_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(lesson_id)
) ENGINE=InnoDB;

CREATE TABLE exams (
  exam_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  course_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  instructions TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (exam_id),
  UNIQUE KEY uq_exam_course (course_id),
  CONSTRAINT fk_exam_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE exam_questions (
  question_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  exam_id BIGINT UNSIGNED NOT NULL,
  lesson_id BIGINT UNSIGNED NOT NULL,
  question_text TEXT NOT NULL,
  marks DECIMAL(5,2) NOT NULL,
  negative_marking_enabled TINYINT(1) NOT NULL DEFAULT 0,
  negative_marks DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  created_by_instructor_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (question_id),
  KEY idx_exam_questions_exam (exam_id),
  KEY idx_exam_questions_lesson (lesson_id),
  CONSTRAINT fk_question_exam FOREIGN KEY (exam_id) REFERENCES exams(exam_id) ON DELETE CASCADE,
  CONSTRAINT fk_question_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(lesson_id),
  CONSTRAINT fk_question_creator FOREIGN KEY (created_by_instructor_id) REFERENCES instructors(instructor_id),
  CONSTRAINT chk_marks_positive CHECK (marks > 0),
  CONSTRAINT chk_negative_marks CHECK ((negative_marking_enabled = 0 AND negative_marks = 0) OR (negative_marking_enabled = 1 AND negative_marks >= 0))
) ENGINE=InnoDB;

CREATE TABLE question_options (
  option_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  option_no TINYINT UNSIGNED NOT NULL,
  option_text VARCHAR(1000) NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (option_id),
  UNIQUE KEY uq_question_option_no (question_id, option_no),
  KEY idx_options_question (question_id),
  CONSTRAINT fk_option_question FOREIGN KEY (question_id) REFERENCES exam_questions(question_id) ON DELETE CASCADE,
  CONSTRAINT chk_option_no CHECK (option_no BETWEEN 1 AND 6)
) ENGINE=InnoDB;

CREATE TABLE exam_attempts (
  attempt_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  exam_id BIGINT UNSIGNED NOT NULL,
  attempt_no SMALLINT UNSIGNED NOT NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  submitted_at DATETIME NULL,
  total_score DECIMAL(8,2) NULL,
  result_status ENUM('in_progress','passed','failed') NOT NULL DEFAULT 'in_progress',
  evaluated_at DATETIME NULL,
  PRIMARY KEY (attempt_id),
  UNIQUE KEY uq_attempt_number (enrollment_id, exam_id, attempt_no),
  KEY idx_attempt_lookup (enrollment_id, exam_id, result_status),
  CONSTRAINT fk_attempt_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE,
  CONSTRAINT fk_attempt_exam FOREIGN KEY (exam_id) REFERENCES exams(exam_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE exam_attempt_answers (
  answer_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  attempt_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  selected_option_id BIGINT UNSIGNED NULL,
  is_correct TINYINT(1) NULL,
  awarded_marks DECIMAL(5,2) NULL,
  answered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (answer_id),
  UNIQUE KEY uq_answer_attempt_question (attempt_id, question_id),
  KEY idx_answers_attempt (attempt_id),
  CONSTRAINT fk_answer_attempt FOREIGN KEY (attempt_id) REFERENCES exam_attempts(attempt_id) ON DELETE CASCADE,
  CONSTRAINT fk_answer_question FOREIGN KEY (question_id) REFERENCES exam_questions(question_id),
  CONSTRAINT fk_answer_option FOREIGN KEY (selected_option_id) REFERENCES question_options(option_id)
) ENGINE=InnoDB;

CREATE TABLE certificates (
  certificate_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  certificate_no CHAR(36) NOT NULL,
  enrollment_id BIGINT UNSIGNED NOT NULL,
  attempt_id BIGINT UNSIGNED NOT NULL,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  student_name VARCHAR(255) NOT NULL,
  course_name VARCHAR(255) NOT NULL,
  completion_date DATE NOT NULL,
  final_score DECIMAL(8,2) NOT NULL,
  grade VARCHAR(10) NULL,
  PRIMARY KEY (certificate_id),
  UNIQUE KEY uq_certificate_no (certificate_no),
  UNIQUE KEY uq_certificate_enrollment (enrollment_id),
  CONSTRAINT fk_certificate_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id),
  CONSTRAINT fk_certificate_attempt FOREIGN KEY (attempt_id) REFERENCES exam_attempts(attempt_id)
) ENGINE=InnoDB;

DELIMITER $$

CREATE TRIGGER trg_enrollment_before_insert
BEFORE INSERT ON enrollments
FOR EACH ROW
BEGIN
  DECLARE v_course_type ENUM('free','paid');
  DECLARE v_active_count INT;
  DECLARE v_paid_count INT;

  SELECT course_type INTO v_course_type
  FROM courses
  WHERE course_id = NEW.course_id;

  IF NEW.subscription_type <> v_course_type THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Enrollment subscription_type must match course_type';
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM enrollments
  WHERE student_id = NEW.student_id
    AND enrollment_status = 'in_progress';

  IF v_active_count >= 6 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A student cannot have more than 6 in-progress courses';
  END IF;

  IF v_course_type = 'paid' THEN
    SELECT COUNT(*) INTO v_paid_count
    FROM payments
    WHERE student_id = NEW.student_id
      AND course_id = NEW.course_id
      AND payment_status = 'completed';

    IF v_paid_count = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed payment required before paid-course enrollment';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_enrollment_before_update
BEFORE UPDATE ON enrollments
FOR EACH ROW
BEGIN
  DECLARE v_active_count INT;

  IF NEW.enrollment_status = 'completed' AND NEW.completed_at IS NULL THEN
    SET NEW.completed_at = CURRENT_TIMESTAMP;
  END IF;

  IF OLD.enrollment_status <> 'in_progress' AND NEW.enrollment_status = 'in_progress' THEN
    SELECT COUNT(*) INTO v_active_count
    FROM enrollments
    WHERE student_id = NEW.student_id
      AND enrollment_status = 'in_progress';

    IF v_active_count >= 6 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A student cannot have more than 6 in-progress courses';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_lesson_progress_after_update
AFTER UPDATE ON lesson_progress
FOR EACH ROW
BEGIN
  DECLARE v_completed INT;
  DECLARE v_course_id BIGINT UNSIGNED;

  IF NEW.completion_status = 'completed' AND OLD.completion_status <> 'completed' THEN
    SELECT e.course_id INTO v_course_id
    FROM enrollments e
    WHERE e.enrollment_id = NEW.enrollment_id;

    SELECT COUNT(*) INTO v_completed
    FROM lesson_progress lp
    JOIN lessons l ON l.lesson_id = lp.lesson_id
    WHERE lp.enrollment_id = NEW.enrollment_id
      AND l.course_id = v_course_id
      AND lp.completion_status = 'completed';

    IF v_completed = 12 THEN
      UPDATE enrollments
      SET enrollment_status = 'completed', completed_at = CURRENT_TIMESTAMP
      WHERE enrollment_id = NEW.enrollment_id
        AND enrollment_status <> 'completed';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_course_publish_before_update
BEFORE UPDATE ON courses
FOR EACH ROW
BEGIN
  DECLARE v_lessons INT;
  DECLARE v_lessons_with_text INT;

  IF OLD.is_published = 0 AND NEW.is_published = 1 THEN
    SELECT COUNT(*) INTO v_lessons
    FROM lessons
    WHERE course_id = NEW.course_id;

    IF v_lessons <> 12 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course must have exactly 12 lessons before publish';
    END IF;

    SELECT COUNT(DISTINCT l.lesson_id) INTO v_lessons_with_text
    FROM lessons l
    JOIN lesson_content lc ON lc.lesson_id = l.lesson_id AND lc.content_type = 'text'
    WHERE l.course_id = NEW.course_id;

    IF v_lessons_with_text <> 12 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Every lesson must include text content before publish';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_attempt_submit_before_update
BEFORE UPDATE ON exam_attempts
FOR EACH ROW
BEGIN
  DECLARE v_total_questions INT;
  DECLARE v_answered_questions INT;

  IF OLD.submitted_at IS NULL AND NEW.submitted_at IS NOT NULL THEN
    SELECT COUNT(*) INTO v_total_questions
    FROM exam_questions q
    WHERE q.exam_id = NEW.exam_id;

    IF v_total_questions < 25 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exam must contain at least 25 questions';
    END IF;

    SELECT COUNT(*) INTO v_answered_questions
    FROM exam_attempt_answers a
    JOIN exam_questions q ON q.question_id = a.question_id
    WHERE a.attempt_id = NEW.attempt_id
      AND q.exam_id = NEW.exam_id;

    IF v_answered_questions = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Assessment must be attempted before completion/certificate';
    END IF;
  END IF;
END$$

CREATE PROCEDURE sp_evaluate_attempt(IN p_attempt_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_exam_id BIGINT UNSIGNED;
  DECLARE v_enrollment_id BIGINT UNSIGNED;
  DECLARE v_course_id BIGINT UNSIGNED;
  DECLARE v_total_score DECIMAL(8,2);
  DECLARE v_pass_pct DECIMAL(5,2);
  DECLARE v_total_possible DECIMAL(8,2);
  DECLARE v_percent DECIMAL(5,2);

  SELECT exam_id, enrollment_id INTO v_exam_id, v_enrollment_id
  FROM exam_attempts
  WHERE attempt_id = p_attempt_id;

  UPDATE exam_attempt_answers aa
  JOIN question_options qo ON qo.option_id = aa.selected_option_id
  JOIN exam_questions q ON q.question_id = aa.question_id
  SET aa.is_correct = qo.is_correct,
      aa.awarded_marks = CASE
        WHEN qo.is_correct = 1 THEN q.marks
        WHEN qo.is_correct = 0 AND q.negative_marking_enabled = 1 THEN -q.negative_marks
        ELSE 0
      END
  WHERE aa.attempt_id = p_attempt_id;

  SELECT COALESCE(SUM(awarded_marks),0)
  INTO v_total_score
  FROM exam_attempt_answers
  WHERE attempt_id = p_attempt_id;

  SELECT COALESCE(SUM(marks),0) INTO v_total_possible
  FROM exam_questions
  WHERE exam_id = v_exam_id;

  SELECT c.course_id, c.pass_percentage
  INTO v_course_id, v_pass_pct
  FROM exams e
  JOIN courses c ON c.course_id = e.course_id
  WHERE e.exam_id = v_exam_id;

  IF v_total_possible = 0 THEN
    SET v_percent = 0;
  ELSE
    SET v_percent = (v_total_score / v_total_possible) * 100;
  END IF;

  UPDATE exam_attempts
  SET total_score = v_total_score,
      evaluated_at = CURRENT_TIMESTAMP,
      result_status = CASE WHEN v_percent >= v_pass_pct THEN 'passed' ELSE 'failed' END,
      submitted_at = COALESCE(submitted_at, CURRENT_TIMESTAMP)
  WHERE attempt_id = p_attempt_id;
END$$

CREATE PROCEDURE sp_issue_certificate(IN p_enrollment_id BIGINT UNSIGNED, IN p_attempt_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_status ENUM('in_progress','completed','abandoned');
  DECLARE v_result ENUM('in_progress','passed','failed');
  DECLARE v_count INT;

  SELECT enrollment_status INTO v_status
  FROM enrollments
  WHERE enrollment_id = p_enrollment_id;

  SELECT result_status INTO v_result
  FROM exam_attempts
  WHERE attempt_id = p_attempt_id
    AND enrollment_id = p_enrollment_id;

  IF v_status <> 'completed' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Certificate requires completed course';
  END IF;

  IF v_result <> 'passed' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Certificate requires passed assessment';
  END IF;

  SELECT COUNT(*) INTO v_count FROM certificates WHERE enrollment_id = p_enrollment_id;
  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Certificate already exists for enrollment';
  END IF;

  INSERT INTO certificates (
    certificate_no,
    enrollment_id,
    attempt_id,
    student_name,
    course_name,
    completion_date,
    final_score,
    grade
  )
  SELECT
    UUID(),
    e.enrollment_id,
    ea.attempt_id,
    CONCAT(s.first_name, ' ', s.last_name),
    c.title,
    DATE(e.completed_at),
    ea.total_score,
    CASE
      WHEN ea.total_score >= 90 THEN 'A'
      WHEN ea.total_score >= 75 THEN 'B'
      WHEN ea.total_score >= 60 THEN 'C'
      ELSE 'D'
    END
  FROM enrollments e
  JOIN students s ON s.student_id = e.student_id
  JOIN courses c ON c.course_id = e.course_id
  JOIN exam_attempts ea ON ea.attempt_id = p_attempt_id
  WHERE e.enrollment_id = p_enrollment_id;
END$$

DELIMITER ;

-- Operational validation queries
-- 1) Ensure all published courses have exactly 12 lessons with text content.
-- 2) Ensure each exam has >= 25 questions.
-- 3) Ensure each question has 4-6 options and exactly one correct option.
