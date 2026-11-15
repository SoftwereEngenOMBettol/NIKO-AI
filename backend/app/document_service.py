"""Safe, local-first document generation for NIKO.

Only structured text is accepted. This module never executes user-provided code or
fetches remote templates. PDF is intentionally not advertised until an Arabic-capable
font/shaping pipeline is configured and tested.
"""
from __future__ import annotations

import csv
import io
from typing import Any


SUPPORTED_FORMATS = ("docx", "xlsx", "pptx", "txt", "csv")


def _clean_text(value: Any, *, limit: int = 20_000) -> str:
    text = str(value or "").strip()
    if len(text) > limit:
        raise ValueError(f"Text field exceeds {limit} characters")
    return text


def generate_document(
    *,
    file_format: str,
    title: str,
    content: str = "",
    sections: list[dict[str, str]] | None = None,
    rows: list[list[str]] | None = None,
) -> tuple[bytes, str, str]:
    """Return (bytes, mime type, filename) for a supported document format."""
    fmt = file_format.lower().strip()
    if fmt not in SUPPORTED_FORMATS:
        raise ValueError(f"Unsupported format. Supported formats: {', '.join(SUPPORTED_FORMATS)}")

    safe_title = _clean_text(title, limit=160) or "NIKO Document"
    safe_content = _clean_text(content)
    safe_sections = sections or []
    safe_rows = rows or []
    if len(safe_sections) > 100 or len(safe_rows) > 5000:
        raise ValueError("Document contains too many sections or rows")

    if fmt == "txt":
        body = safe_title + "\n" + "=" * min(len(safe_title), 80) + "\n\n" + safe_content
        for section in safe_sections:
            heading = _clean_text(section.get("heading", ""), limit=160)
            text = _clean_text(section.get("text", ""))
            body += f"\n\n{heading}\n{text}"
        return body.encode("utf-8"), "text/plain; charset=utf-8", "niko-document.txt"

    if fmt == "csv":
        stream = io.StringIO(newline="")
        writer = csv.writer(stream)
        for row in safe_rows:
            writer.writerow([_clean_text(cell, limit=4000) for cell in row[:50]])
        return stream.getvalue().encode("utf-8-sig"), "text/csv; charset=utf-8", "niko-document.csv"

    if fmt == "docx":
        from docx import Document
        from docx.enum.text import WD_ALIGN_PARAGRAPH

        doc = Document()
        doc.add_heading(safe_title, level=0)
        if safe_content:
            paragraph = doc.add_paragraph(safe_content)
            paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        for section in safe_sections:
            heading = _clean_text(section.get("heading", ""), limit=160)
            text = _clean_text(section.get("text", ""))
            if heading:
                doc.add_heading(heading, level=1)
            if text:
                paragraph = doc.add_paragraph(text)
                paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        output = io.BytesIO()
        doc.save(output)
        return output.getvalue(), "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "niko-document.docx"

    if fmt == "xlsx":
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill

        workbook = Workbook()
        sheet = workbook.active
        sheet.title = "NIKO"
        sheet.append([safe_title])
        sheet["A1"].font = Font(bold=True, size=16, color="FFFFFF")
        sheet["A1"].fill = PatternFill("solid", fgColor="243447")
        for row in safe_rows:
            sheet.append([_clean_text(cell, limit=4000) for cell in row[:50]])
        if not safe_rows and safe_content:
            for line in safe_content.splitlines():
                sheet.append([line[:4000]])
        sheet.freeze_panes = "A2"
        output = io.BytesIO()
        workbook.save(output)
        return output.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "niko-document.xlsx"

    from pptx import Presentation
    from pptx.util import Inches, Pt

    presentation = Presentation()
    slide = presentation.slides.add_slide(presentation.slide_layouts[0])
    slide.shapes.title.text = safe_title
    slide.placeholders[1].text = safe_content[:3000] if safe_content else "Created with NIKO AI"
    for section in safe_sections[:40]:
        slide = presentation.slides.add_slide(presentation.slide_layouts[1])
        slide.shapes.title.text = _clean_text(section.get("heading", "Section"), limit=160)
        slide.placeholders[1].text = _clean_text(section.get("text", ""))[:5000]
    output = io.BytesIO()
    presentation.save(output)
    return output.getvalue(), "application/vnd.openxmlformats-officedocument.presentationml.presentation", "niko-document.pptx"
