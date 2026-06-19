
import csv

# 直接用 Python 的 csv 模块读
print("=== 用 Python csv 模块读 ===")

with open("mistakes_sample.csv", encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    rows = list(reader)
    print(f"总行数: {len(rows)}")
    print(f"表头: {rows[0]}")
    print(f"第一行数据列数: {len(rows[1])}")
    print(f"第一行数据: {rows[1]}")
    print()
    print("=== 检查文件换行符 ===")
    with open("mistakes_sample.csv", "rb") as fb:
        content = fb.read(2000)
        print("前2000字节的十六进制:")
        print(content.hex())
        print()
        if b"\r\n" in content:
            print("✓ 找到 \\r\\n (CRLF)")
        if b"\n" in content:
            print("✓ 找到 \\n (LF)")
        if b"\r" in content:
            print("✓ 找到 \\r (CR)")

