#!/usr/bin/env python3
"""
Generate deterministic CSV seed data for the online_learning schema.

Usage:
  python scripts/generate_synthetic_data.py --out ./seed_data
"""

from __future__ import annotations

import argparse
import csv
import random
from pathlib import Path

RNG = random.Random(42)


def write_csv(path: Path, headers: list[str], rows: list[tuple]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)


def gen_students(n: int = 500):
    rows = []
    for i in range(1, n + 1):
        rows.append((
            i,
            f"Student{i}",
            f"LN{i}",
            f"student{i}@example.com",
            f"+100000{i:05d}",
            "UTC",
            "active",
        ))
    return rows


def gen_instructors(n: int = 50):
    return [
        (i, f"Tutor{i}", f"LN{i}", f"tutor{i}@example.com")
        for i in range(1, n + 1)
    ]


def gen_courses(n: int = 500, instructors: int = 50):
    rows = []
    for i in range(1, n + 1):
        paid = i % 3 != 0
        rows.append((
            i,
            f"CRS{i:04d}",
            f"Course {i}",
            "paid" if paid else "free",
            ((i - 1) % instructors) + 1,
            RNG.randint(240, 1440),
            round(RNG.uniform(19, 299), 2) if paid else "",
            "USD" if paid else "",
            60.0,
            3,
            1,
        ))
    return rows


def gen_lessons(courses: int = 500):
    rows = []
    lesson_id = 1
    for c in range(1, courses + 1):
        for no in range(1, 13):
            rows.append((lesson_id, c, no, f"Course {c} Lesson {no}", 1))
            lesson_id += 1
    return rows


def gen_lesson_content(total_lessons: int):
    rows = []
    content_id = 1
    for lesson_id in range(1, total_lessons + 1):
        rows.append((content_id, lesson_id, "text", f"Text content for lesson {lesson_id}", "", 1))
        content_id += 1
        if lesson_id % 2 == 0:
            rows.append((content_id, lesson_id, "video", "", f"https://cdn.example.com/v/{lesson_id}.mp4", 2))
            content_id += 1
        if lesson_id % 3 == 0:
            rows.append((content_id, lesson_id, "image", "", f"https://cdn.example.com/i/{lesson_id}.jpg", 3))
            content_id += 1
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="seed_data", help="output directory")
    args = ap.parse_args()

    out = Path(args.out)

    students = gen_students(500)
    instructors = gen_instructors(50)
    courses = gen_courses(500, 50)
    lessons = gen_lessons(500)
    lesson_content = gen_lesson_content(len(lessons))

    write_csv(out / "students.csv", ["student_id", "first_name", "last_name", "email", "phone", "timezone", "status"], students)
    write_csv(out / "instructors.csv", ["instructor_id", "first_name", "last_name", "email"], instructors)
    write_csv(
        out / "courses.csv",
        ["course_id", "course_code", "title", "course_type", "instructor_id", "duration_minutes", "price_amount", "currency_code", "pass_percentage", "max_attempts", "is_published"],
        courses,
    )
    write_csv(out / "lessons.csv", ["lesson_id", "course_id", "lesson_no", "title", "is_published"], lessons)
    write_csv(
        out / "lesson_content.csv",
        ["content_id", "lesson_id", "content_type", "body_text", "media_url", "display_order"],
        lesson_content,
    )

    print(f"Generated CSV files in: {out.resolve()}")


if __name__ == "__main__":
    main()
