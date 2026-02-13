# Online Learning Platform - Schema Design Document

## 1) Design goals
- Normalize to at least 3NF.
- Enforce business rules where possible at database level (constraints, triggers, procedures).
- Preserve audit trails for enrollment activity, lesson access, and exam attempts.
- Keep read paths efficient for high-volume activity.

## 2) Core entities and normalization

### Identity and ownership
- `students`: profile and account status.
- `instructors`: tutor identities.
- `courses`: course metadata and monetization model.

### Content model
- `lessons`: exactly 12 lesson slots (`lesson_no` 1..12) per course.
- `lesson_content`: polymorphic content rows by type (`text`, `image`, `video`).

### Subscription and payment
- `payments`: independent payment events with statuses.
- `enrollments`: student-course subscription state and lifecycle.

### Progress and audit
- `lesson_progress`: latest per lesson/enrollment status.
- `lesson_access_logs`: append-only historical access log.

### Assessment
- `exams`: 1 exam per course.
- `exam_questions`: question bank for an exam with custom marks and optional negative marking.
- `question_options`: 4..6 options and one correct (validated operationally).
- `exam_attempts`: attempt headers with result and score.
- `exam_attempt_answers`: per-question chosen option + awarded marks.

### Certification
- `certificates`: exactly one certificate per enrollment if course completed + exam passed.

All non-key attributes depend on their table keys only; transitive dependencies are avoided by separating concerns (e.g., payment vs enrollment vs attempt).

## 3) Business-rule enforcement mapping

- **Free/Paid constraints**: `courses.chk_course_price_rules`; enrollment trigger checks `subscription_type` matches `course_type`.
- **Paid course requires payment**: `trg_enrollment_before_insert` validates a completed payment exists.
- **Max 6 active courses**: enforced in `trg_enrollment_before_insert` and `trg_enrollment_before_update`.
- **Exactly 12 lessons per course**: enforced before publish in `trg_course_publish_before_update`.
- **Text content required per lesson**: also enforced before publish.
- **Auto-complete course at 12 lesson completions**: `trg_lesson_progress_after_update`.
- **Mandatory exam attempt before completion workflow**: submit trigger requires at least one answer before final submission.
- **At least 25 questions/exam**: checked at attempt submission.
- **Negative marking and scoring**: `sp_evaluate_attempt`.
- **Certificate only after completion + pass**: `sp_issue_certificate`.

## 4) Indexing strategy

- Enrollment hot paths:
  - `idx_enrollments_active (student_id, enrollment_status)`
  - `idx_enrollments_course_status (course_id, enrollment_status)`
- Progress lookups:
  - `uq_progress_enrollment_lesson`
  - `idx_progress_lookup (enrollment_id, completion_status)`
- Audit scans by time:
  - `idx_access_enrollment_time`
  - `idx_access_lesson_time`
- Assessment lookups:
  - `idx_exam_questions_exam`, `idx_attempt_lookup`, `idx_answers_attempt`

## 5) High-volume access model

- Keep write-heavy logs append-only (`lesson_access_logs`).
- Use compact surrogate PKs (`BIGINT UNSIGNED`) and selective secondary indexes.
- Keep attempt evaluation in stored procedure to reduce application round trips.
- Support historical analytics without mutating old rows.

## 6) Validation checklist (post-load)

1. Courses count >= 500.
2. Lessons per course = 12.
3. Each lesson has >= 1 text content row.
4. Students count >= 500.
5. Subscriptions/student between 5 and 20, with in-progress <= 6.
6. Each course has one exam with >= 25 questions.
7. Every question has 4..6 options and exactly one correct.

