#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Markdown → 格式严格的 Word 文档转换器
严格遵循中文学术论文排版规范：
- 一级标题：三号黑体 16pt 加粗
- 二级标题：四号黑体 14pt 加粗
- 三级标题：小四号黑体 12pt 加粗
- 正文：小四号宋体 12pt，首行缩进 2 字符，1.5 倍行距
- 代码：Consolas 小五号 9pt，灰色底纹
- 表格：五号宋体 10.5pt，深色表头
"""

from docx import Document
from docx.shared import Pt, Inches, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml
import re, os, sys

# ── 配置 ──
SRC_DIR = r'D:\新建文件夹\defend_the_tower\docs'
OUTPUT  = os.path.join(SRC_DIR, 'Space_Frontline_期末报告.docx')

# 章节顺序
FILES = [
    '01-项目概述.md',
    '02-需求分析.md',
    '03-总体设计.md',
    '04-详细实现.md',
    '05-游戏测试.md',
    '06-特色与创新.md',
    '07-总结与展望.md',
    '08-参考文献.md',
]

# ── 文档初始化 ──
doc = Document()

for section in doc.sections:
    section.page_width  = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin    = Cm(2.54)
    section.bottom_margin = Cm(2.54)
    section.left_margin   = Cm(3.17)
    section.right_margin  = Cm(3.17)

# Normal 样式
style = doc.styles['Normal']
style.font.name = '宋体'
style.font.size = Pt(12)
style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
style.paragraph_format.line_spacing = 1.5
style.paragraph_format.space_after = Pt(0)
style.paragraph_format.space_before = Pt(0)

# ── 工具函数 ──
def cn_font(run, cn='宋体', en='Times New Roman', size=Pt(12), bold=False, color=None):
    run.font.name = en
    run.font.size = size
    run.bold = bold
    run.element.rPr.rFonts.set(qn('w:eastAsia'), cn)
    if color:
        run.font.color.rgb = color

def heading(text, level):
    """统一标题格式"""
    p = doc.add_paragraph()
    if level == 1:
        p.paragraph_format.space_before = Pt(18)
        p.paragraph_format.space_after = Pt(12)
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        cn_font(p.add_run(text), '黑体', 'Arial', Pt(16), True)
    elif level == 2:
        p.paragraph_format.space_before = Pt(12)
        p.paragraph_format.space_after = Pt(6)
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        cn_font(p.add_run(text), '黑体', 'Arial', Pt(14), True)
    elif level == 3:
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(4)
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        cn_font(p.add_run(text), '黑体', 'Arial', Pt(12), True)
    elif level == 0:
        p.paragraph_format.space_before = Pt(24)
        p.paragraph_format.space_after = Pt(18)
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cn_font(p.add_run(text), '黑体', 'Arial', Pt(22), True)

def body(text):
    """正文段落：首行缩进 2 字符"""
    if not text.strip():
        return
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(24)
    p.paragraph_format.line_spacing = 1.5
    cn_font(p.add_run(text), '宋体', 'Times New Roman', Pt(12))

def body_no_indent(text):
    """正文无缩进"""
    if not text.strip():
        return
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing = 1.5
    cn_font(p.add_run(text), '宋体', 'Times New Roman', Pt(12))

def bullet(text, indent_level=0):
    """列表项"""
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1.0 + indent_level * 0.8)
    p.paragraph_format.line_spacing = 1.5
    marker = '●' if indent_level == 0 else '○'
    cn_font(p.add_run(f'{marker} {text}'), '宋体', 'Times New Roman', Pt(12))

def code_block(text):
    """代码块"""
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1.0)
    p.paragraph_format.line_spacing = 1.2
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="F0F0F0" w:val="clear"/>')
    p.paragraph_format.element.get_or_add_pPr().append(shd)
    for i, line in enumerate(text.split('\n')):
        if i > 0:
            p.add_run('\n')
        cn_font(p.add_run(line), '宋体', 'Consolas', Pt(9))

def make_table(header, rows):
    """创建带格式表格"""
    table = doc.add_table(rows=1 + len(rows), cols=len(header))
    table.style = 'Table Grid'
    table.alignment = WD_TABLE_ALIGNMENT.CENTER

    for i, h in enumerate(header):
        cell = table.rows[0].cells[i]
        cell.text = ''
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cn_font(p.add_run(h), '黑体', 'Arial', Pt(10.5), True)
        shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="D9E2F3" w:val="clear"/>')
        cell._element.get_or_add_tcPr().append(shd)

    for r, row in enumerate(rows):
        for c, val in enumerate(row):
            cell = table.rows[r + 1].cells[c]
            cell.text = ''
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c > 0 else WD_ALIGN_PARAGRAPH.LEFT
            cn_font(p.add_run(str(val)), '宋体', 'Times New Roman', Pt(10.5))

    doc.add_paragraph()

def page_break():
    doc.add_page_break()

# ── Markdown 解析器 ──

def parse_md(filepath):
    """解析 markdown 文件, 逐行处理"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    i = 0
    in_code = False
    code_text = []
    in_table = False
    table_header = []
    table_rows = []

    def flush_table():
        nonlocal in_table, table_header, table_rows
        if table_header:
            make_table(table_header, table_rows)
            table_header = []
            table_rows = []
            in_table = False

    while i < len(lines):
        line = lines[i].rstrip()

        # 代码块
        if line.startswith('```'):
            if in_code:
                code_block('\n'.join(code_text))
                code_text = []
                in_code = False
            else:
                flush_table()
                in_code = True
            i += 1
            continue

        if in_code:
            code_text.append(line)
            i += 1
            continue

        # 空行
        if not line.strip():
            flush_table()
            i += 1
            continue

        # 表格
        if '|' in line and line.strip().startswith('|'):
            flush_table()
            cells = [c.strip() for c in line.split('|')[1:-1]]
            # 跳过分隔行
            if all(c.replace('-', '').replace(':', '').strip() == '' for c in cells):
                i += 1
                continue
            if not in_table:
                table_header = cells
                in_table = True
            else:
                table_rows.append(cells)
            i += 1
            continue

        # Mermaid 图跳过
        if line.strip().startswith('```mermaid'):
            flush_table()
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                i += 1
            i += 1
            continue

        # 标题
        h_match = re.match(r'^(#{1,3})\s+(.+)$', line)
        if h_match:
            flush_table()
            level = len(h_match.group(1))
            text = h_match.group(2).strip()
            heading(text, level)
            i += 1
            continue

        # 列表
        bullet_match = re.match(r'^[-*]\s+(.+)$', line)
        if bullet_match:
            flush_table()
            bullet(bullet_match.group(1).strip())
            i += 1
            continue

        # 数字列表
        num_match = re.match(r'^\d+\.\s+(.+)$', line)
        if num_match:
            flush_table()
            bullet(num_match.group(1).strip())
            i += 1
            continue

        # 加粗行
        bold_match = re.match(r'^\*\*(.+)\*\*$', line)
        if bold_match:
            flush_table()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            cn_font(p.add_run(bold_match.group(1).strip()), '黑体', 'Arial', Pt(12), True)
            i += 1
            continue

        # 水平线
        if line.strip() in ('---', '***', '___'):
            flush_table()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(6)
            i += 1
            continue

        # 普通段落
        flush_table()
        # 清理 markdown 内联格式
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', line)
        text = re.sub(r'\*(.+?)\*', r'\1', text)
        text = re.sub(r'`(.+?)`', r'\1', text)
        text = re.sub(r'\[(.+?)\]\(.+?\)', r'\1', text)

        # 判断是否为首行(无缩进标题行)
        if text.startswith('> '):
            body_no_indent(text[2:].strip())
        elif line == lines[0].rstrip() or (i > 0 and not lines[i-1].strip()):
            # 段落首行
            body(text)
        else:
            body(text)

        i += 1

    flush_table()

# ── 封面 ──

for _ in range(6):
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing = 1.0

heading('移动应用开发期末课程报告', 0)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(12)
cn_font(p.add_run('Space Frontline（星际前线）'), '黑体', 'Arial', Pt(18), True)

for _ in range(4):
    doc.add_paragraph()

info_table = doc.add_table(rows=5, cols=2)
info_table.style = 'Table Grid'
info_data = [
    ('课程名称', '移动应用开发（YN3012140019）'),
    ('游戏类型', '塔防 Roguelike'),
    ('开发引擎', 'Flutter 3.x + Flame 1.26.1'),
    ('运行平台', 'Android'),
    ('完成日期', '2026年7月'),
]
for i, (k, v) in enumerate(info_data):
    for j, txt in enumerate([k, v]):
        cell = info_table.rows[i].cells[j]
        cell.text = ''
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.RIGHT if j == 0 else WD_ALIGN_PARAGRAPH.LEFT
        cn_font(p.add_run(txt), '黑体' if j == 0 else '宋体', 'Arial', Pt(14), j == 0)
    info_table.rows[i].cells[0].width = Cm(4)
    info_table.rows[i].cells[1].width = Cm(8)

page_break()

# ── 成绩考核表 ──
heading('期末课程报告成绩考核表', 1)

make_table(
    ['指标内容', '分值', '指标内涵及评估标准（A/B/C/D）', '得分'],
    [
        ['选题定位', '20分', '', ''],
        ['选题意义', '5', 'A.意义重大 B.意义较大 C.意义一般 D.属于简单开发/无意义', ''],
        ['解决的关键技术问题', '5', 'A.准确且范围合适 B.重点突出 C.基本准确 D.部分关键/未抓住关键', ''],
        ['技术路线可行程度', '10', 'A.合理可行具体且有创新 B.合理可行具体 C.基本合理可行 D.不够合理', ''],
        ['完成情况', '50分', '', ''],
        ['小组成员的工作量', '15', 'A.高出平均要求15%以上 B.高出平均要求 C.达到平均要求 D.低于平均要求', ''],
        ['项目完成技术水平', '15', 'A.难度很大超出一般本科生水平 B.难度较大达到毕业论文水平 C.难度一般 D.难度小', ''],
        ['达到预期目标程度', '10', 'A.完全达到 B.基本达到 C.无法预见 D.未能达到', ''],
        ['团队精神', '10', 'A.团队合作精神强 B.合作情况良好 C.合作情况一般 D.合作不好', ''],
        ['总结情况', '30分', '', ''],
        ['报告撰写质量', '30', '完整性+逻辑结构+内容丰富+文字表达+图表制作+整体效果 各5分', ''],
        ['综合得分', '', '', ''],
    ]
)

body('教师评语：')
doc.add_paragraph()
doc.add_paragraph()
p = doc.add_paragraph()
cn_font(p.add_run('任课教师签名：______________          日期：______________'), '宋体', 'Times New Roman', Pt(12))
body_no_indent('注：该表每人一份，附在封面之后。本报告由独立完成。')

page_break()

# ── 摘要 ──
heading('摘要', 1)

body('Space Frontline（星际前线）是一款基于 Flutter + Flame 引擎开发的塔防 Roguelike 移动游戏。'
     '项目以太空战斗为主题，玩家操控位于屏幕底部的中央炮塔，抵御从屏幕顶端不断下降的外星敌人，'
     '守卫人类最后的防线。')

body('游戏实现了 15 波递增难度的完整关卡、19 种 Roguelike Buff（分属通用/火焰/冰霜/雷电/暗影/机械六大元素体系）、'
     '4 种各具特色的敌人类型（基础敌人水银、产怪型精英沃土、治疗辅助型护士、汲取充能型惊雷）、'
     '5 种可收集使用的消耗道具以及永久天赋树系统。技术上采用 Flame 组件树架构、AABB 碰撞检测、'
     '多源状态效果叠加、ValueNotifier 跨层通信等方案，完整实现了游戏循环、对象管理、碰撞检测、'
     '状态效果、数据持久化等核心功能。')

body('项目的核心创新在于：惊雷敌人的汲取机制为塔防游戏引入了玩家策略博弈（主动击杀电池 vs 放任汲取），'
     '多源燃烧叠加系统实现了精细的状态管理，精英 Trait Mixin 模式统一了精英类型判断，'
     '以及纯 Flame 组件驱动的道具飞入动画等视觉优化方案。')

p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(12)
cn_font(p.add_run('关键词：'), '黑体', 'Arial', Pt(12), True)
cn_font(p.add_run('Flutter；Flame游戏引擎；塔防游戏；Roguelike；跨平台移动开发'), '宋体', 'Times New Roman', Pt(12))

page_break()

# ── 逐章节解析 ──
for fname in FILES:
    fpath = os.path.join(SRC_DIR, fname)
    if not os.path.exists(fpath):
        print(f'WARNING: {fpath} not found, skipping')
        continue
    print(f'Processing: {fname}')
    parse_md(fpath)

# ── 保存 ──
doc.save(OUTPUT)
print(f'\nDone! Saved to: {OUTPUT}')
