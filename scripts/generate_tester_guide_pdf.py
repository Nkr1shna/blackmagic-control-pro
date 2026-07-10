#!/usr/bin/env python3
"""Render docs/tester-guide.md as the tester-facing PDF."""

from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    Image,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "tester-guide.md"
OUTPUT = ROOT / "output" / "pdf" / "blackmagic-control-pro-alpha-tester-guide.pdf"

INK = colors.HexColor("#131821")
MUTED = colors.HexColor("#5A6472")
GREEN = colors.HexColor("#18A66A")
GREEN_DARK = colors.HexColor("#087A4C")
GREEN_LIGHT = colors.HexColor("#EAF8F1")
BLUE_LIGHT = colors.HexColor("#EAF2FC")
AMBER_LIGHT = colors.HexColor("#FFF5D9")
LINE = colors.HexColor("#D8DEE7")
PAPER = colors.HexColor("#FFFFFF")


def inline_markup(text: str) -> str:
    """Convert the small inline Markdown subset used by the guide."""
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(
        r"(https://[^\s<]+)",
        r'<link href="\1" color="#087A4C"><u>\1</u></link>',
        text,
    )
    return text


def styles():
    base = getSampleStyleSheet()
    return {
        "cover_eyebrow": ParagraphStyle(
            "CoverEyebrow",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=13,
            textColor=GREEN_DARK,
            spaceAfter=12,
            textTransform="uppercase",
        ),
        "cover_title": ParagraphStyle(
            "CoverTitle",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=31,
            leading=35,
            textColor=INK,
            alignment=TA_LEFT,
            spaceAfter=12,
        ),
        "cover_subtitle": ParagraphStyle(
            "CoverSubtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=15,
            leading=21,
            textColor=MUTED,
            spaceAfter=24,
        ),
        "h1": ParagraphStyle(
            "GuideH1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=19,
            leading=22.5,
            textColor=INK,
            spaceBefore=8,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "GuideH2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=19,
            textColor=GREEN_DARK,
            spaceBefore=14,
            spaceAfter=7,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "GuideH3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            textColor=INK,
            spaceBefore=10,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "GuideBody",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.2,
            textColor=INK,
            spaceAfter=4.5,
        ),
        "bullet": ParagraphStyle(
            "GuideBullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.2,
            textColor=INK,
            leftIndent=18,
            firstLineIndent=-10,
            bulletIndent=8,
            spaceAfter=3,
        ),
        "number": ParagraphStyle(
            "GuideNumber",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.2,
            textColor=INK,
            leftIndent=22,
            firstLineIndent=-17,
            spaceAfter=3.2,
        ),
        "callout": ParagraphStyle(
            "GuideCallout",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13.5,
            textColor=INK,
            leftIndent=11,
            rightIndent=11,
            spaceBefore=5,
            spaceAfter=5,
        ),
        "caption": ParagraphStyle(
            "GuideCaption",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8,
            leading=10,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceBefore=4,
            spaceAfter=7,
        ),
        "card_title": ParagraphStyle(
            "CardTitle",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            textColor=INK,
            alignment=TA_CENTER,
            spaceAfter=3,
        ),
        "card_body": ParagraphStyle(
            "CardBody",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9.5,
            leading=12,
            textColor=PAPER,
            spaceAfter=0,
        ),
        "footer": ParagraphStyle(
            "Footer",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.5,
            textColor=MUTED,
        ),
    }


S = styles()


def cover_story():
    computer_card = [
        Paragraph("COMPUTER", S["card_title"]),
        Paragraph("Install <b>iLoader</b> here<br/>(Mac or Windows)", S["card_body"]),
    ]
    ipad_card = [
        Paragraph("iPAD", S["card_title"]),
        Paragraph("The app installs here", S["card_body"]),
    ]
    camera_card = [
        Paragraph("CAMERA", S["card_title"]),
        Paragraph("Connect it last", S["card_body"]),
    ]
    cards = Table(
        [[computer_card, ipad_card, camera_card]],
        colWidths=[2.3 * inch, 2.3 * inch, 2.3 * inch],
    )
    cards.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, 0), BLUE_LIGHT),
                ("BACKGROUND", (1, 0), (1, 0), GREEN_LIGHT),
                ("BACKGROUND", (2, 0), (2, 0), AMBER_LIGHT),
                ("BOX", (0, 0), (-1, -1), 0.7, LINE),
                ("INNERGRID", (0, 0), (-1, -1), 0.7, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 16),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 16),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )
    reminder = Table(
        [[Paragraph("Every step is labelled <b>[COMPUTER]</b>, <b>[iPAD]</b>, or <b>[CAMERA]</b> so you always know which device to pick up.", S["callout"])]],
        colWidths=[6.9 * inch],
    )
    reminder.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), AMBER_LIGHT),
                ("BOX", (0, 0), (-1, -1), 0.7, colors.HexColor("#E7C866")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return [
        Spacer(1, 0.38 * inch),
        Paragraph("ALPHA TESTER SETUP", S["cover_eyebrow"]),
        Paragraph("Blackmagic<br/>Control Pro", S["cover_title"]),
        Paragraph(
            "Install the test build on your iPad with iLoader, then connect your camera.",
            S["cover_subtitle"],
        ),
        HRFlowable(width="100%", thickness=3, color=GREEN, spaceAfter=24),
        cards,
        Spacer(1, 0.28 * inch),
        reminder,
        Spacer(1, 0.3 * inch),
        Paragraph(
            "Allow about 15 minutes. Keep the iPad unlocked and connected by USB while iLoader is working.",
            S["cover_subtitle"],
        ),
        Spacer(1, 1.05 * inch),
        Paragraph(
            "Unofficial alpha software - not made by or affiliated with Blackmagic Design.",
            S["caption"],
        ),
        PageBreak(),
    ]


def styled_table(rows):
    widths = [1.05 * inch, 1.35 * inch, 4.5 * inch]
    data = []
    for row_index, row in enumerate(rows):
        data.append(
            [
                Paragraph(
                    inline_markup(cell),
                    S["body"] if row_index else S["table_header"],
                )
                for cell in row
            ]
        )
    table = Table(data, colWidths=widths, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), INK),
                ("TEXTCOLOR", (0, 0), (-1, 0), PAPER),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F7F9FB")),
                ("GRID", (0, 0), (-1, -1), 0.6, LINE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return table


def parse_markdown(path: Path):
    lines = path.read_text(encoding="utf-8").splitlines()
    story = []
    paragraph_lines = []
    table_rows = []
    skip_cover_text = True

    def flush_paragraph():
        if paragraph_lines:
            text = " ".join(x.strip() for x in paragraph_lines)
            story.append(Paragraph(inline_markup(text), S["body"]))
            paragraph_lines.clear()

    def flush_table():
        if table_rows:
            story.append(styled_table(table_rows))
            story.append(Spacer(1, 7))
            table_rows.clear()

    for raw in lines:
        line = raw.rstrip()
        if skip_cover_text:
            if line.startswith("## What you need"):
                skip_cover_text = False
            else:
                continue

        if not line:
            flush_paragraph()
            flush_table()
            continue

        if re.match(r"^\|\s*---", line):
            continue
        if line.startswith("|") and line.endswith("|"):
            flush_paragraph()
            table_rows.append([cell.strip() for cell in line.strip("|").split("|")])
            continue

        flush_table()

        image_match = re.match(r"^!\[(.*?)\]\((.*?)\)$", line)
        if image_match:
            flush_paragraph()
            asset = Path(image_match.group(2))
            if not asset.is_absolute():
                asset = path.parent / asset
            if asset.exists():
                screenshot = Image(str(asset))
                scale = min(
                    6.2 * inch / screenshot.imageWidth,
                    2.8 * inch / screenshot.imageHeight,
                )
                screenshot.drawWidth = screenshot.imageWidth * scale
                screenshot.drawHeight = screenshot.imageHeight * scale
                frame = Table([[screenshot]], colWidths=[screenshot.drawWidth + 12])
                frame.setStyle(
                    TableStyle(
                        [
                            ("BOX", (0, 0), (-1, -1), 0.7, LINE),
                            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F3F5F8")),
                            ("LEFTPADDING", (0, 0), (-1, -1), 6),
                            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                            ("TOPPADDING", (0, 0), (-1, -1), 6),
                            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                        ]
                    )
                )
                caption = Paragraph(inline_markup(image_match.group(1)), S["caption"])
                story.append(KeepTogether([frame, caption]))
            continue

        if line == "---":
            flush_paragraph()
            story.append(HRFlowable(width="100%", thickness=0.7, color=LINE, spaceBefore=6, spaceAfter=6))
        elif line.startswith("### "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[4:]), S["h3"]))
        elif line.startswith("## "):
            flush_paragraph()
            if line.startswith("## Part 3") or line.startswith("## Part 5"):
                story.append(PageBreak())
            story.append(Paragraph(inline_markup(line[3:]), S["h1"]))
        elif line.startswith("# "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[2:]), S["h1"]))
        elif line.startswith("> "):
            flush_paragraph()
            box = Table(
                [[Paragraph(inline_markup(line[2:]), S["callout"])]],
                colWidths=[6.9 * inch],
            )
            box.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, -1), GREEN_LIGHT),
                        ("LINEBEFORE", (0, 0), (0, -1), 3, GREEN),
                        ("TOPPADDING", (0, 0), (-1, -1), 6),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                    ]
                )
            )
            story.append(box)
        elif re.match(r"^\d+\.\s", line):
            flush_paragraph()
            number, text = line.split(". ", 1)
            story.append(Paragraph(f"<b>{number}.</b> {inline_markup(text)}", S["number"]))
        elif line.startswith("- "):
            flush_paragraph()
            story.append(Paragraph(f"&bull; {inline_markup(line[2:])}", S["bullet"]))
        else:
            paragraph_lines.append(line)

    flush_paragraph()
    flush_table()
    return story


def draw_page(canvas, doc):
    page = canvas.getPageNumber()
    canvas.saveState()
    if page > 1:
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.6)
        canvas.line(0.62 * inch, 0.56 * inch, 7.88 * inch, 0.56 * inch)
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(0.65 * inch, 0.34 * inch, "BLACKMAGIC CONTROL PRO - ALPHA TESTER GUIDE")
        canvas.drawRightString(7.85 * inch, 0.34 * inch, f"{page}")
    canvas.restoreState()


def build():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=LETTER,
        rightMargin=0.65 * inch,
        leftMargin=0.65 * inch,
        topMargin=0.62 * inch,
        bottomMargin=0.72 * inch,
        title="Blackmagic Control Pro - Alpha Tester Guide",
        author="Blackmagic Control Pro",
        subject="Mac and iPad alpha tester installation guide",
    )
    story = cover_story() + parse_markdown(SOURCE)
    doc.build(story, onFirstPage=draw_page, onLaterPages=draw_page)
    print(OUTPUT)


if __name__ == "__main__":
    build()
