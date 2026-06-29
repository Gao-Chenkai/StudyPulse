#!/usr/bin/env python3
"""
把 TestData 下的旧版（中文表头、7 列）样例 CSV 转成新版（英文表头、8 列）样例。

- grades_sample.csv：10 列 (ID, Subject, Score, FullScore, ScoreRate, RawScore, Ranking, Importance, ExamName, Date)
- mistakes_sample.csv：9 列
- exams_sample.csv / single_exams_sample.csv / comprehensive_exams_sample.csv：8 列
  (ID, Name, Subject, Date, ExamEndDate, Importance, Mastery, Type)

Type 统一为 single / comprehensive。
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).parent

GRADES_NEW_HEADER = [
    "ID", "Subject", "Score", "FullScore", "ScoreRate",
    "RawScore", "Ranking", "Importance", "ExamName", "Date",
]
GRADES_OLD_TO_NEW = {
    "ID": "ID", "科目": "Subject", "分数": "Score", "满分": "FullScore",
    "分数率": "ScoreRate", "得分率": "ScoreRate",
    "原始分数": "RawScore", "原始分": "RawScore",
    "排名": "Ranking", "重要性": "Importance", "重要度": "Importance",
    "考试名称": "ExamName", "考试名": "ExamName", "日期": "Date",
}

MISTAKES_NEW_HEADER = [
    "ID", "Title", "Subject", "OriginalQuestion", "Source",
    "Date", "ErrorReason", "WrongSolution", "CorrectSolution",
]
MISTAKES_OLD_TO_NEW = {
    "ID": "ID", "标题": "Title", "科目": "Subject",
    "原始问题": "OriginalQuestion", "来源": "Source", "日期": "Date",
    "错误原因": "ErrorReason", "错误解法": "WrongSolution", "正确解法": "CorrectSolution",
}

EXAMS_NEW_HEADER = [
    "ID", "Name", "Subject", "Date", "ExamEndDate", "Importance", "Mastery", "Type",
]
EXAMS_OLD_TO_NEW = {
    "ID": "ID", "名称": "Name", "科目": "Subject", "日期": "Date",
    "考试结束日期": "ExamEndDate", "重要性": "Importance", "掌握程度": "Mastery",
    "类型": "Type", "单科": "single", "综合": "comprehensive",
}


def convert_row(row: list, mapping: dict, insert_blank_at: int = None) -> list:
    new_row = []
    for cell in row:
        new_row.append(mapping.get(cell, cell))
    if insert_blank_at is not None:
        new_row.insert(insert_blank_at, "")
    return new_row


def read_legacy(path: Path):
    if not path.exists():
        return None, []
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        rows = [row for row in reader if row]
    if not rows:
        return [], []
    return rows[0], rows[1:]


def write_new(path: Path, new_header: list, new_rows: list):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(new_header)
        for row in new_rows:
            writer.writerow(row)
    print(f"  ✓ {path.name} ({len(new_rows)} rows)")


def convert_grades():
    old_header, old_rows = read_legacy(ROOT / "grades_sample.csv")
    if not old_header:
        print("  [SKIP] grades_sample.csv not found")
        return
    new_rows = [convert_row(row, GRADES_OLD_TO_NEW) for row in old_rows]
    write_new(ROOT / "grades_sample.csv", GRADES_NEW_HEADER, new_rows)


def convert_mistakes():
    old_header, old_rows = read_legacy(ROOT / "mistakes_sample.csv")
    if not old_header:
        print("  [SKIP] mistakes_sample.csv not found")
        return
    new_rows = [convert_row(row, MISTAKES_OLD_TO_NEW) for row in old_rows]
    write_new(ROOT / "mistakes_sample.csv", MISTAKES_NEW_HEADER, new_rows)


def convert_exams():
    """Convert all exam CSVs (single / comprehensive / mixed)."""
    for fname in ("exams_sample.csv", "single_exams_sample.csv", "comprehensive_exams_sample.csv"):
        old_header, old_rows = read_legacy(ROOT / fname)
        if not old_header:
            print(f"  [SKIP] {fname} not found")
            continue
        new_rows = []
        for row in old_rows:
            new_row = convert_row(row, EXAMS_OLD_TO_NEW, insert_blank_at=4)
            new_rows.append(new_row)
        write_new(ROOT / fname, EXAMS_NEW_HEADER, new_rows)


def main():
    print("=" * 60)
    print("Convert sample CSVs to new English-header schema")
    print("=" * 60)
    convert_grades()
    convert_mistakes()
    convert_exams()
    print("=" * 60)
    print("[DONE] All sample CSVs updated")


if __name__ == "__main__":
    main()
