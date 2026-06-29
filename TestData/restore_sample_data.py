#!/usr/bin/env python3
"""
把 TestData 下的样例 CSV 转成 App 沙盒内的 JSON 文件，模拟"用户已经导入"的状态。
直接写到模拟器 App 沙盒的 Documents/ 目录。

用法:
  python3 restore_sample_data.py <app_data_container_path>
"""
import csv
import json
import sys
import uuid
from datetime import datetime
from pathlib import Path


def make_uuid(hex_no_dash: str) -> str:
    return str(uuid.UUID(hex_no_dash))


def parse_date(s: str) -> str:
    # 2026-01-08 20:17:59 -> 2026-01-08T20:17:59Z
    try:
        dt = datetime.strptime(s.strip(), "%Y-%m-%d %H:%M:%S")
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


# Swift JSONDecoder default uses .deferredToDate which is a Double timestamp.
# We need to match the actual format used by Swift's JSONEncoder.
# The app uses `dateDecodingStrategy = .iso8601` for exams and compExams.
# For grades/mistakes it uses default decoder. Let's check by looking at the
# source: it uses `DataFileIO.load<T>` which uses default JSONDecoder.
# Default decoder for Date on macOS 10.12+/iOS 10+ is .deferredToDate (Double
# seconds since 2001-01-01 reference date).
# To be safe, use ISO8601 for everything and set dateDecodingStrategy
# accordingly... but we can't change the app. Use deferredToDate: encode
# as Double seconds since 2001-01-01.
REF_DATE = datetime(2001, 1, 1)


def swift_date(iso_str: str) -> float:
    dt = datetime.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ")
    delta = dt - REF_DATE
    return delta.total_seconds()


SUBJECTS = [
    ("Chinese", "语文", 150),
    ("Mathematics", "数学", 150),
    ("English", "英语", 150),
    ("Physics", "物理", 100),
    ("Chemistry", "化学", 100),
    ("Biology", "生物", 100),
    ("History", "历史", 100),
    ("Geography", "地理", 100),
    ("Politics", "政治", 100),
    ("Information Technology", "信息技术", 100),
]


def write_subjects(docs: Path):
    arr = []
    for name, display, full in SUBJECTS:
        arr.append({
            "id": str(uuid.uuid4()).upper(),
            "name": name,
            "enabled": True,
            "fullScore": float(full),
            "displayName": display,
        })
    (docs / "subjects.json").write_text(json.dumps(arr, ensure_ascii=False, indent=2))
    print(f"  ✓ subjects.json ({len(arr)} subjects)")


def write_grades(csv_path: Path, docs: Path):
    if not csv_path.exists():
        return
    out = []
    with csv_path.open(encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # header
        for row in reader:
            if len(row) < 10:
                continue
            grade_id = make_uuid(row[0])
            subject = row[1].strip()
            score = float(row[2])
            full_score = float(row[3]) if row[3] else None
            raw_score = float(row[5]) if row[5] else None
            ranking = int(row[6]) if row[6] else None
            importance = int(row[7]) if row[7] else 3
            exam_name = row[8]
            date_str = row[9]
            date_iso = parse_date(date_str)
            date_val = swift_date(date_iso)
            out.append({
                "id": grade_id,
                "subject": subject,
                "score": score,
                "rawScore": raw_score,
                "ranking": ranking,
                "importance": importance,
                "image": None,
                "imageFileName": None,
                "date": date_val,
                "examName": exam_name,
                "fullScore": full_score,
            })
    (docs / "grades.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    print(f"  ✓ grades.json ({len(out)} records)")


def write_mistakes(csv_path: Path, docs: Path):
    if not csv_path.exists():
        return
    out = []
    with csv_path.open(encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # header
        for row in reader:
            if len(row) < 9:
                continue
            mistake_id = make_uuid(row[0])
            title = row[1]
            subject = row[2]
            original = row[3]
            source = row[4]
            date_str = row[5]
            date_iso = parse_date(date_str)
            date_val = swift_date(date_iso)
            error_reason = row[6]
            wrong = row[7]
            correct = row[8]
            out.append({
                "id": mistake_id,
                "title": title,
                "subject": subject,
                "originalQuestion": original,
                "source": source,
                "date": date_val,
                "errorReason": error_reason,
                "wrongSolution": wrong,
                "correctSolution": correct,
                "questionImages": [],
                "reasonImages": [],
                "wrongSolutionImages": [],
                "correctSolutionImages": [],
                "questionImageFilenames": [],
                "reasonImageFilenames": [],
                "wrongImageFilenames": [],
                "correctImageFilenames": [],
            })
    (docs / "mistakes.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    print(f"  ✓ mistakes.json ({len(out)} records)")


def write_exams(csv_path: Path, docs: Path):
    """Write exams (single subject) and comprehensiveExams (multi subject)."""
    if not csv_path.exists():
        return
    singles = []
    comprehensives = []
    with csv_path.open(encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # header
        for row in reader:
            # 兼容 8 列新格式 + 7 列旧格式
            if len(row) < 7:
                continue
            exam_id = make_uuid(row[0])
            name = row[1]
            subject_str = row[2]
            date_str = row[3]
            date_iso = parse_date(date_str)
            # 8 列格式带 examEndDate (row[4])，需要跳过
            if len(row) >= 8:
                importance = int(row[5]) if row[5] else 3
                mastery = int(row[6]) if row[6] else 0
                kind = row[7]
            else:
                importance = int(row[4]) if row[4] else 3
                mastery = int(row[5]) if row[5] else 0
                kind = row[6]
            if kind == "单科" or kind == "single":
                singles.append({
                    "id": exam_id,
                    "name": name,
                    "examDate": date_iso,
                    "importance": importance,
                    "subject": subject_str,
                    "examName": name,
                    "masteryDegree": mastery,
                })
            else:
                subjects_list = [s.strip() for s in subject_str.split(";") if s.strip()]
                comprehensives.append({
                    "id": exam_id,
                    "name": name,
                    "examDate": date_iso,
                    "importance": importance,
                    "subject": subjects_list,
                    "examName": name,
                    "masteryDegree": mastery,
                })
    (docs / "exams.json").write_text(json.dumps(singles, ensure_ascii=False, indent=2))
    print(f"  ✓ exams.json ({len(singles)} single subject exams)")
    (docs / "comprehensiveExams.json").write_text(json.dumps(comprehensives, ensure_ascii=False, indent=2))
    print(f"  ✓ comprehensiveExams.json ({len(comprehensives)} comprehensive exams)")


def write_profile(docs: Path):
    profile = {
        "username": "Student",
        "age": 17,
        "educationLevel": "High School",
        "educationSystem": "National Curriculum",
        "region": "China",
        "selectedSubjects": [],
        "theme": "Auto",
        "avatarFileName": None,
        "realName": "",
        "grade": "高二",
        "className": "3班",
        "schoolName": "示例中学",
        "studentId": "2024001",
        "enrollmentYear": 2024,
        "examYear": 2027,
        "educationStage": "High School",
        "regionCode": "mainland",
        "gender": "Not Specified",
        "targetSchool": "示例大学",
        "targetScore": 650.0,
    }
    (docs / "profile.json").write_text(json.dumps(profile, ensure_ascii=False, indent=2))
    print("  ✓ profile.json")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    container = Path(sys.argv[1])
    docs = container / "Documents"
    docs.mkdir(parents=True, exist_ok=True)

    test_data = Path(__file__).parent
    print(f"Writing to: {docs}")
    write_subjects(docs)
    write_profile(docs)
    write_grades(test_data / "grades_sample.csv", docs)
    write_mistakes(test_data / "mistakes_sample.csv", docs)
    write_exams(test_data / "exams_sample.csv", docs)
    print("Done.")


if __name__ == "__main__":
    main()
