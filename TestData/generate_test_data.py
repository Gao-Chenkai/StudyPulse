#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
StudyPulse 测试数据生成器
生成真实的成绩、错题和考试测试数据
"""

import csv
import random
import uuid
from datetime import datetime, timedelta

subject_names = {
    "Chinese": "语文",
    "Mathematics": "数学",
    "English": "英语",
    "Physics": "物理",
    "Chemistry": "化学",
    "Biology": "生物",
    "History": "历史",
    "Geography": "地理",
    "Politics": "政治",
    "Music": "音乐",
    "Art": "美术",
    "Sports": "体育",
    "Economics": "经济学",
    "Computer Science": "计算机科学",
    "Science": "科学",
    "History & Society": "历史与社会",
    "Information Technology": "信息技术",
    "General Technology": "通用技术",
    "Mathematics A": "数学A",
    "Mathematics B": "数学B",
    "Liberal Studies": "通识教育",
    "Chinese History": "中国历史",
    "Visual Arts": "视觉艺术",
    "Mother Tongue": "母语",
    "Additional Mathematics": "高等数学",
    "Combined Science": "综合科学",
    "Social Studies": "社会研究",
    "English Language": "英语语言",
    "English Literature": "英语文学",
    "Business Studies": "商务研究",
    "Religious Studies": "宗教研究",
    "French": "法语",
    "Spanish": "西班牙语",
    "German": "德语",
    "Drama": "戏剧",
    "Further Mathematics": "进阶数学",
    "Human Biology": "人体生物学",
    "Business": "商务",
    "Psychology": "心理学",
    "Sociology": "社会学",
    "Philosophy": "哲学",
    "Media Studies": "媒体研究",
    "IB English A: Literature": "IB英语A：文学",
    "IB English A: Language & Literature": "IB英语A：语言与文学",
    "IB Chinese A: Literature": "IB中文A：文学",
    "IB Chinese A: Language & Literature": "IB中文A：语言与文学",
    "IB Self-Taught Language A": "IB自学语言A",
    "IB English B": "IB英语B",
    "IB French B": "IB法语B",
    "IB Spanish B": "IB西班牙语B",
    "IB Mandarin B": "IB中文B",
    "IB Ab Initio French": "IB法语入门",
    "IB Ab Initio Spanish": "IB西班牙语入门",
    "IB History": "IB历史",
    "IB Geography": "IB地理",
    "IB Economics": "IB经济学",
    "IB Psychology": "IB心理学",
    "IB Philosophy": "IB哲学",
    "IB Business Management": "IB商务管理",
    "IB Global Politics": "IB全球政治",
    "IB Environmental Systems": "IB环境系统",
    "IB Physics": "IB物理",
    "IB Chemistry": "IB化学",
    "IB Biology": "IB生物学",
    "IB Computer Science": "IB计算机科学",
    "IB Design Technology": "IB设计技术",
    "IB Mathematics: Analysis & Approaches SL": "IB数学：分析与方法SL",
    "IB Mathematics: Analysis & Approaches HL": "IB数学：分析与方法HL",
    "IB Mathematics: Applications & Interpretation SL": "IB数学：应用与解释SL",
    "IB Mathematics: Applications & Interpretation HL": "IB数学：应用与解释HL",
    "IB Visual Arts": "IB视觉艺术",
    "IB Music": "IB音乐",
    "IB Theatre": "IB戏剧",
    "IB Film": "IB电影",
    "IB Dance": "IB舞蹈",
    "IB TOK": "IB知识理论",
    "IB Extended Essay": "IB拓展论文",
    "AP English Language": "AP英语语言",
    "AP English Literature": "AP英语文学",
    "AP US History": "AP美国历史",
    "AP World History": "AP世界历史",
    "AP European History": "AP欧洲历史",
    "AP Human Geography": "AP人文地理",
    "AP US Government": "AP美国政府",
    "AP Macroeconomics": "AP宏观经济学",
    "AP Microeconomics": "AP微观经济学",
    "AP Psychology": "AP心理学",
    "AP Calculus AB": "AP微积分AB",
    "AP Calculus BC": "AP微积分BC",
    "AP Statistics": "AP统计学",
    "AP Precalculus": "AP预备微积分",
    "AP Computer Science A": "AP计算机科学A",
    "AP Computer Science Principles": "AP计算机科学原理",
    "AP Physics 1": "AP物理1",
    "AP Physics 2": "AP物理2",
    "AP Physics C: Mechanics": "AP物理C：力学",
    "AP Physics C: E&M": "AP物理C：电磁学",
    "AP Chemistry": "AP化学",
    "AP Biology": "AP生物学",
    "AP Environmental Science": "AP环境科学",
    "AP Chinese": "AP中文",
    "AP French": "AP法语",
    "AP Spanish": "AP西班牙语",
    "AP German": "AP德语",
    "AP Japanese": "AP日语",
    "AP Latin": "AP拉丁语",
    "AP Art History": "AP艺术史",
    "AP Music Theory": "AP音乐理论",
    "AP Studio Art 2D": "AP工作室艺术2D",
    "AP Studio Art 3D": "AP工作室艺术3D",
    "AP Studio Art Drawing": "AP工作室艺术绘画",
    "SAT Math Level 1": "SAT数学1",
    "SAT Math Level 2": "SAT数学2",
    "SAT Physics": "SAT物理",
    "SAT Chemistry": "SAT化学",
    "SAT Biology": "SAT生物学",
    "SAT US History": "SAT美国历史",
    "SAT World History": "SAT世界历史",
    "SAT Literature": "SAT文学",
    "SAT Spanish": "SAT西班牙语",
    "SAT French": "SAT法语",
    "SAT Chinese": "SAT中文",
    "ACT English": "ACT英语",
    "ACT Math": "ACT数学",
    "ACT Reading": "ACT阅读",
    "ACT Science": "ACT科学",
    "ACT Writing": "ACT写作",
    "SAT EBRW": "SAT阅读与写作",
    "SAT Math": "SAT数学",
    "SAT Essay": "SAT作文",
    "GPA": "GPA",
    "GRE Verbal": "GRE语文",
    "GRE Quantitative": "GRE数学",
    "GRE AW": "GRE分析性写作",
    "GMAT Total": "GMAT总分",
    "TOEFL": "托福",
    "IELTS": "雅思"
}

exam_names = [
    "单元测验", "月考", "期中考试", "期末考试", "模拟考试",
    "适应性考试", "诊断性考试", "摸底考试", "期末复习", "寒假作业检查",
    "暑假作业检查", "Quiz 1", "Mid-Term Test", "End-of-Year Exam",
    "Mock Exam", "Final Review", "Practice Test", "Quarterly Exam",
    "Pre-Mock Exam", "Mock Exam 2", "Final Revision Quiz", "Weekly Test"
]

mistake_titles = [
    "三角函数图像问题", "二次函数易错点", "英语语法填空错误",
    "电磁感应综合题", "化学实验装置连接问题",
    "数列求和难题", "近代不平等条约", "时区计算问题",
    "基因遗传图谱", "完形填空高频错题",
    "酸碱中和滴定误差", "牛顿运动定律综合运用",
    "生态系统能量流动",
    "文言文翻译理解错误", "有机化学同分异构体",
    "三角函数恒等变换易错", "阅读理解主旨大意题",
    "立体几何三视图", "向量运算错误",
    "物理受力分析"
]

error_reasons = [
    "概念理解不够全面", "计算过程出错", "审题不清", "知识点遗漏", "粗心大意",
    "记忆错误", "应用能力不足", "时间不够用", "概念混淆",
    "公式记错", "思路不清", "计算失误", "单位换算错误",
    "忘记重要知识点",
    "书写错误", "概念理解不清",
    "关键信息获取不足",
    "时间分配不合理",
    "书写格式错误"
]

correct_solutions = [
    "首先分析问题，理清思路，再逐步计算",
    "重新整理知识点，找到正确方法",
    "牢记基础方法: 1.理解题意 2.回忆知识点 3.解题 4.检查总结",
    "仔细审清题意，圈出关键词，避免理解偏差",
    "巩固基础，加强复习，概念要清晰，步骤要规范",
    "计算时保持专注，每一步都要仔细检查",
    "重新看题，认真思考，整理思路，规范步骤",
    "先记牢相关概念和公式，再应用解题",
    "强化训练类似题目，总结常见错误和正确思路"
]

wrong_solutions = [
    "错误原因：使用了错误的方法一，导致结果偏离",
    "计算步骤出错，中间某一步的数值算错了",
    "理解题目有偏差，理解错了题目中的关键条件",
    "公式记错了，应该是另一个公式",
    "步骤错了！思路不对，整个方向都错了",
    "计算出错导致整个结果全错，前面的步骤还挺对的",
    "没有完全理解概念，知识点混淆了",
    "步骤全错了，得重新学习这部分内容",
    "中间步骤有错误，导致后面的计算都错了"
]

original_question_prefixes = [
    "题目内容：",
    "经典错题：",
    "题目：",
    "易错典型题："
]

def random_date_past(days_back=730):
    """生成过去随机日期"""
    now = datetime.now()
    random_days = random.randint(1, days_back)
    return now - timedelta(days=random_days)

def random_date_future(days_ahead=180):
    """生成未来随机日期"""
    now = datetime.now()
    random_days = random.randint(1, days_ahead)
    return now + timedelta(days=random_days)

def format_date(dt):
    """格式化日期"""
    return dt.strftime("%Y-%m-%d %H:%M:%S")

def generate_grades(count=200):
    """生成成绩测试数据"""
    data = []
    subjects = list(subject_names.keys())[:9]  # 前 9 个主要科目
    
    for _ in range(count):
        subject_key = random.choice(subjects)
        subject_full_score = random.choice([100, 120, 150])
        
        # 分数（正态分布，平均在 75 分左右）
        rand_val = random.random()
        if rand_val < 0.1:
            base = random.uniform(40, 60)
        elif rand_val < 0.7:
            base = random.uniform(65, 90)
        else:
            base = random.uniform(85, 100)
        
        score = base * (subject_full_score / 100)
        score = max(0, min(score, subject_full_score))
        
        raw_score = random.uniform(40, 100) * (subject_full_score / 100) if random.random() > 0.5 else None
        ranking = random.randint(1, 60)
        importance = random.randint(1, 5)
        exam_name = random.choice(exam_names)
        score_rate = (score / subject_full_score) * 100
        date = random_date_past()
        
        row = [
            str(uuid.uuid4()),
            subject_key,
            f"{score:.1f}",
            str(subject_full_score),
            f"{score_rate:.1f}",
            f"{raw_score:.1f}" if raw_score is not None else "",
            str(ranking),
            str(importance),
            exam_name,
            format_date(date)
        ]
        data.append(row)
    
    return data

def generate_mistakes(count=100):
    """生成错题测试数据 - 每个科目都有"""
    data = []
    all_subjects = list(subject_names.keys())
    
    # 彻底去除所有换行符的函数
    def clean(s):
        return s.replace("\n", " ").replace("\r", " ").strip()
    
    # 确保每个科目至少有1条错题
    for subject_key in all_subjects:
        title = random.choice(mistake_titles)
        prefix = random.choice(original_question_prefixes)
        original_question = prefix + title + "。这是一道典型的易错题，需要认真思考。"
        source = "来自：" + random.choice(exam_names)
        error_reason = random.choice(error_reasons)
        wrong_sol = random.choice(wrong_solutions)
        correct_sol = random.choice(correct_solutions)
        date = random_date_past(days_back=365)
        
        row = [
            str(uuid.uuid4()),
            clean(title),
            clean(subject_key),
            clean(original_question),
            clean(source),
            format_date(date),
            clean(error_reason),
            clean(wrong_sol),
            clean(correct_sol)
        ]
        data.append(row)
    
    # 补充剩余的错题，随机科目
    remaining = count - len(all_subjects)
    for _ in range(remaining):
        subject_key = random.choice(all_subjects)
        title = random.choice(mistake_titles)
        prefix = random.choice(original_question_prefixes)
        original_question = prefix + title + "。这是一道典型的易错题，需要认真思考。"
        source = "来自：" + random.choice(exam_names)
        error_reason = random.choice(error_reasons)
        wrong_sol = random.choice(wrong_solutions)
        correct_sol = random.choice(correct_solutions)
        date = random_date_past(days_back=365)
        
        row = [
            str(uuid.uuid4()),
            clean(title),
            clean(subject_key),
            clean(original_question),
            clean(source),
            format_date(date),
            clean(error_reason),
            clean(wrong_sol),
            clean(correct_sol)
        ]
        data.append(row)
    
    return data

def generate_exams(single_count=50, comp_count=10):
    """生成考试测试数据"""
    single_data = []
    comp_data = []
    
    subjects = list(subject_names.keys())[:10]
    
    # 单科考试
    for _ in range(single_count):
        subject_key = random.choice(subjects)
        exam_name = random.choice(exam_names)
        importance = random.randint(1, 5)
        mastery = random.randint(0, 100)
        date = random_date_future()
        
        row = [
            str(uuid.uuid4()),
            exam_name,
            subject_key,
            format_date(date),
            str(importance),
            str(mastery),
            "单科"
        ]
        single_data.append(row)
    
    # 综合考试
    comp_exam_names = ["期中考试", "期末考试", "模拟考试", "Final Exam", "Mid-Year Exam", "Mock Exam", "高三模考", "中考模拟"]
    for _ in range(comp_count):
        subject_count = random.randint(3, 6)
        selected_subjects = random.sample(subjects, subject_count)
        subject_list = ";".join(selected_subjects)
        exam_name = random.choice(comp_exam_names)
        importance = random.randint(3, 5)
        mastery = random.randint(20, 80)
        date = random_date_future(days_ahead=365)
        
        row = [
            str(uuid.uuid4()),
            exam_name,
            subject_list,
            format_date(date),
            str(importance),
            str(mastery),
            "综合"
        ]
        comp_data.append(row)
    
    return single_data, comp_data

def main():
    print("=" * 60)
    print("📚 StudyPulse 测试数据生成器")
    print("=" * 60)
    
    # 生成数据
    print("\n⏳ 正在生成数据...")
    
    grades_data = generate_grades(200)
    mistakes_data = generate_mistakes(100)
    single_exams_data, comp_exams_data = generate_exams(50, 10)
    
    # 保存 CSV
    print("💾 正在保存文件...")
    
    # 成绩
    with open("grades_sample.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "科目", "分数", "满分", "分数率", 
            "原始分数", "排名", "重要性", "考试名称", "日期"
        ])
        writer.writerows(grades_data)
    print("  ✅ 成绩数据已保存: grades_sample.csv (200条)")
    
    # 错题
    with open("mistakes_sample.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "标题", "科目", "原始问题", "来源", 
            "日期", "错误原因", "错误解法", "正确解法"
        ])
        writer.writerows(mistakes_data)
    print("  ✅ 错题数据已保存: mistakes_sample.csv (100条)")
    
    # 单科考试
    with open("single_exams_sample.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "名称", "科目", "日期", "重要性", "掌握程度", "类型"
        ])
        writer.writerows(single_exams_data)
    print("  ✅ 单科考试数据已保存: single_exams_sample.csv (50条)")
    
    # 综合考试
    with open("comprehensive_exams_sample.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "名称", "科目", "日期", "重要性", "掌握程度", "类型"
        ])
        writer.writerows(comp_exams_data)
    print("  ✅ 综合考试数据已保存: comprehensive_exams_sample.csv (10条)")
    
    # 合并考试数据
    all_exams_data = single_exams_data + comp_exams_data
    with open("exams_sample.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "ID", "名称", "科目", "日期", "重要性", "掌握程度", "类型"
        ])
        writer.writerows(all_exams_data)
    print("  ✅ 合并考试数据已保存: exams_sample.csv (60条)")
    
    print("\n🎉 所有测试数据生成完成！")
    print("\n📊 数据统计：")
    print("  - 成绩：200条")
    print("  - 错题：100条")
    print("  - 单科考试：50条")
    print("  - 综合考试：10条")
    print("  - 总计：360条")
    print("\n💡 提示：使用 Excel 或导入功能可导入这些数据到 StudyPulse！")

if __name__ == "__main__":
    main()
