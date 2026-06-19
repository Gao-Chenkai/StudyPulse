# StudyPulse 测试数据

这是 StudyPulse 应用的测试数据目录，包含真实的学生学习数据样本。

## 📊 数据说明

| 文件 | 数量 | 说明 |
|------|------|------|
| `grades_sample.csv` | 200条 | 学生成绩数据（过去 2 年） |
| `mistakes_sample.csv` | 100条 | 错题本数据（过去 1 年） |
| `single_exams_sample.csv` | 50条 | 单科考试安排（未来） |
| `comprehensive_exams_sample.csv` | 10条 | 综合考试安排（未来） |
| `exams_sample.csv` | 60条 | 合并后的考试数据（单科 + 综合） |

## 📁 数据结构

### 成绩数据 (`grades_sample.csv`)
| 字段 | 说明 |
|------|------|
| ID | 唯一标识符 |
| Subject | 科目 ID (chinese, math, english, physics, chemistry, biology, history, geography, politics) |
| Score | 得分 |
| FullScore | 满分 (100, 120, 或 150) |
| ScoreRate | 得分率 % |
| RawScore | 原始分（可选） |
| Ranking | 班级排名 |
| Importance | 重要程度 (1-5) |
| ExamName | 考试名称 |
| Date | 考试日期 |

### 错题数据 (`mistakes_sample.csv`)
| 字段 | 说明 |
|------|------|
| ID | 唯一标识符 |
| Title | 错题标题 |
| Subject | 科目 ID |
| OriginalQuestion | 题目内容 |
| Source | 来源（考试名称） |
| Date | 记录日期 |
| ErrorReason | 错误原因 |
| WrongSolution | 错误解答 |
| CorrectSolution | 正确解答 |

### 考试数据 (`exams_sample.csv`)
| 字段 | 说明 |
|------|------|
| ID | 唯一标识符 |
| Name | 考试名称 |
| Subject | 科目（单科考试）或多个科目（综合考试，分号分隔） |
| Date | 考试日期 |
| Importance | 重要程度 (1-5) |
| Mastery | 掌握程度 (0-100) |
| Type | 考试类型 (单科 / 综合) |

## 🚀 使用方法

### 1. 导入到 StudyPulse
在 StudyPulse 应用中，进入「设置」→「数据导出/导入」，选择相应的 CSV 文件进行导入。

### 2. 用 Excel 查看
直接用 Excel 或 Numbers 打开 CSV 文件查看和编辑。

### 3. 重新生成数据
运行 Python 脚本可生成新的随机测试数据：
```bash
cd TestData
python3 generate_test_data.py
```

## 📝 注意事项
- 数据包含 UTF-8 BOM，确保 Excel 正确识别编码
- 日期格式：`YYYY-MM-DD HH:MM:SS`
- 科目列表参考：`chinese`, `math`, `english`, `physics`, `chemistry`, `biology`, `history`, `geography`, `politics`

## 📈 数据特点
- 分数符合正态分布（平均约 75 分）
- 时间跨度真实（成绩为过去 2 年，考试为未来）
- 涵盖多种考试类型（单元考、月考、期中、期末、模拟等）
- 错题包含真实的错误原因和解答
