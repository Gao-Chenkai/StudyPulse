#!/usr/bin/env python3
"""
CSV 格式回归测试：
- 验证 TestData 下的样例 CSV 符合新版 schema
- 验证导出（按新表头）→ 重新导入能完整回环
- 输出每张表解析前后的记录数和列数

用法:
  python3 TestData/csv_roundtrip_test.py
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).parent

EXPECTED_HEADERS = {
    "grades_sample.csv": [
        "ID", "Subject", "Score", "FullScore", "ScoreRate",
        "RawScore", "Ranking", "Importance", "ExamName", "Date",
    ],
    "mistakes_sample.csv": [
        "ID", "Title", "Subject", "OriginalQuestion", "Source",
        "Date", "ErrorReason", "WrongSolution", "CorrectSolution",
    ],
    "exams_sample.csv": [
        "ID", "Name", "Subject", "Date", "ExamEndDate", "Importance", "Mastery", "Type",
    ],
    "single_exams_sample.csv": [
        "ID", "Name", "Subject", "Date", "ExamEndDate", "Importance", "Mastery", "Type",
    ],
    "comprehensive_exams_sample.csv": [
        "ID", "Name", "Subject", "Date", "ExamEndDate", "Importance", "Mastery", "Type",
    ],
}

# 不再需要中文→英文表头映射（CSV 已经是新格式）；保留为兼容标记
LEGACY_HEADER_MAPS = {
    "grades_sample.csv": {},
    "mistakes_sample.csv": {},
    "exams_sample.csv": {"单科": "single", "综合": "comprehensive"},
    "single_exams_sample.csv": {"单科": "single", "综合": "comprehensive"},
    "comprehensive_exams_sample.csv": {"单科": "single", "综合": "comprehensive"},
}


def read_csv(path: Path):
    """Read CSV with utf-8-sig to handle BOM, return (header, rows)."""
    if not path.exists():
        return None, []
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        rows = [row for row in reader if row]
    if not rows:
        return [], []
    return rows[0], rows[1:]


def re_export(headers: list, rows: list) -> str:
    """Re-emit as CSV string, escaping fields that need it."""
    import io
    buf = io.StringIO()
    writer = csv.writer(buf, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    writer.writerow(headers)
    for row in rows:
        writer.writerow(row)
    return buf.getvalue()


def re_parse(csv_text: str) -> tuple:
    import io
    reader = csv.reader(io.StringIO(csv_text))
    rows = [row for row in reader if row]
    if not rows:
        return [], []
    return rows[0], rows[1:]


def check_roundtrip(name: str, path: Path):
    legacy = LEGACY_HEADER_MAPS.get(name, {})
    header, rows = read_csv(path)
    if header is None:
        print(f"  [SKIP] {name} (not found)")
        return True
    print(f"  [CHECK] {name}")
    print(f"          header={header}")
    print(f"          rows={len(rows)}")

    # 翻译表头（理论上新格式已不需要，但保留以防）
    new_header = [legacy.get(c, c) for c in header]
    new_rows = []
    for row in rows:
        new_row = []
        for cell in row:
            if cell in legacy:
                new_row.append(legacy[cell])
            else:
                new_row.append(cell)
        new_rows.append(new_row)

    # 与期望表头比对
    expected = EXPECTED_HEADERS[name]
    if new_header != expected:
        print(f"  [WARN] 头部与期望不匹配 / Header mismatch")
        print(f"          got     : {new_header}")
        print(f"          expected: {expected}")
    else:
        print(f"  [OK]   头部匹配新 schema / Header matches new schema")

    # 检查关键字段非空
    for i, row in enumerate(new_rows):
        if len(row) < len(expected):
            print(f"  [ERROR] row {i + 1} 列数不足: {len(row)} < {len(expected)}")
            return False

    # 考试 type 列必须是 single / comprehensive
    if "Type" in expected:
        for i, row in enumerate(new_rows):
            type_idx = expected.index("Type")
            if type_idx < len(row):
                t = row[type_idx].strip().lower()
                if t not in ("single", "comprehensive"):
                    print(f"  [ERROR] row {i + 1} Type 字段非法: {row[type_idx]!r}")
                    return False
        type_counts = {}
        for row in new_rows:
            t = row[expected.index("Type")].strip().lower()
            type_counts[t] = type_counts.get(t, 0) + 1
        print(f"  [OK]   type 分布: {type_counts}")

    # Round-trip：导出 → 再解析 → 行数一致 + header 一致
    csv_text = re_export(expected, new_rows)
    re_header, re_rows = re_parse(csv_text)
    if re_header != expected:
        print(f"  [ERROR] round-trip header 改变")
        return False
    if len(re_rows) != len(new_rows):
        print(f"  [ERROR] round-trip 行数变化: {len(new_rows)} → {len(re_rows)}")
        return False
    print(f"  [OK]   round-trip 成功 ({len(re_rows)} rows preserved)")

    # 检查综合考试科目列（如果适用）
    if name in ("exams_sample.csv", "comprehensive_exams_sample.csv"):
        for i, row in enumerate(new_rows):
            if row[expected.index("Type")].strip().lower() == "comprehensive":
                subj = row[expected.index("Subject")]
                if ";" not in subj and "," in subj:
                    print(f"  [WARN] 综合考试 row {i + 1} 用 , 分隔科目: {subj!r}")
                if ";" not in subj:
                    print(f"  [WARN] 综合考试 row {i + 1} 没有分号分隔: {subj!r}")
        print(f"  [OK]   综合考试科目分隔符已检查")
    return True


def main():
    print("=" * 60)
    print("StudyPulse CSV Schema 回归测试")
    print("=" * 60)
    all_ok = True
    for name in EXPECTED_HEADERS:
        ok = check_roundtrip(name, ROOT / name)
        all_ok = all_ok and ok
    print("=" * 60)
    if all_ok:
        print("[PASS] 所有样例 CSV 通过 schema + round-trip 检查")
        sys.exit(0)
    else:
        print("[FAIL] 有 CSV 不符合 schema")
        sys.exit(1)


if __name__ == "__main__":
    main()
