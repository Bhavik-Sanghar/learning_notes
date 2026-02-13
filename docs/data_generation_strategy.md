# Data Generation Strategy and Load Testing Approach

## 1) Targets
- 500+ courses, each with exactly 12 lessons.
- 500+ students.
- Each student subscribed to 5..20 courses.
- Fewer than 6 `in_progress` enrollments per student.
- Every subscribed course has progress/access logs.
- Every course has one exam with >= 25 questions.

## 2) Bulk generation flow

1. Generate base entities to CSV with `scripts/generate_synthetic_data.py`.
2. Bulk-load with `LOAD DATA INFILE` into staging or direct target tables.
3. Generate enrollments/payments/progress/exam artifacts in SQL batches.

## 3) Example bulk-load commands

```sql
LOAD DATA LOCAL INFILE 'seed_data/students.csv'
INTO TABLE students
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(student_id, first_name, last_name, email, phone, timezone, status);

LOAD DATA LOCAL INFILE 'seed_data/courses.csv'
INTO TABLE courses
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(course_id, course_code, title, course_type, instructor_id, duration_minutes,
 @price_amount, @currency_code, pass_percentage, max_attempts, is_published)
SET
 price_amount = NULLIF(@price_amount,''),
 currency_code = NULLIF(@currency_code,'');
```

## 4) Enrollment/progress synthesis notes

- Use deterministic pseudo-random mapping: `course_id = (student_id * k + offset) % 500 + 1`.
- For paid courses, create `payments(payment_status='completed')` before `enrollments`.
- Keep at most 5 in-progress rows/student; mark remaining as `completed` or `abandoned`.
- Insert 12 `lesson_progress` rows per enrollment and matching `lesson_access_logs` rows.

## 5) Exam/question synthesis notes

- Insert 1 exam/course.
- Insert 25..40 questions/exam.
- For each question, insert 4..6 options and exactly one `is_correct=1`.
- Generate attempts (1..N per enrollment where allowed), answers, then call `sp_evaluate_attempt`.

## 6) Load test approach

- Use k6/JMeter/Gatling against APIs for:
  - concurrent enrollment,
  - lesson access logging,
  - exam submission/evaluation.
- Run DB-level checks:
  - p95 latency for key SELECTs and INSERTs,
  - lock wait/deadlock rates,
  - buffer pool hit rate,
  - replication/binlog lag (if replica used).
- Validate constraints continuously via anomaly queries.

## 7) Post-load validation SQL snippets

```sql
-- courses with wrong lesson count
SELECT course_id, COUNT(*) c FROM lessons GROUP BY course_id HAVING c <> 12;

-- students violating in-progress cap
SELECT student_id, COUNT(*) active_cnt
FROM enrollments
WHERE enrollment_status = 'in_progress'
GROUP BY student_id
HAVING active_cnt > 6;

-- exams below question minimum
SELECT e.exam_id, COUNT(q.question_id) q_cnt
FROM exams e
LEFT JOIN exam_questions q ON q.exam_id = e.exam_id
GROUP BY e.exam_id
HAVING q_cnt < 25;
```

