from io import BytesIO

import pytest

from app.document_service import SUPPORTED_FORMATS, generate_document


def test_supported_formats_are_explicit():
    assert {"docx", "xlsx", "pptx", "txt", "csv"} == set(SUPPORTED_FORMATS)


def test_txt_document_contains_title_and_content():
    data, mime, filename = generate_document(
        file_format="txt", title="السيرة الذاتية", content="مهندسة برمجيات"
    )
    assert "السيرة الذاتية".encode() in data
    assert "مهندسة برمجيات".encode() in data
    assert mime.startswith("text/plain")
    assert filename.endswith(".txt")


def test_csv_document_is_utf8_with_bom():
    data, mime, filename = generate_document(
        file_format="csv", title="جدول", rows=[["الاسم", "الوظيفة"], ["سارة", "مهندسة"]]
    )
    assert data.startswith(b"\xef\xbb\xbf")
    assert "سارة".encode() in data
    assert mime.startswith("text/csv")
    assert filename.endswith(".csv")


@pytest.mark.parametrize("fmt", ["docx", "xlsx", "pptx"])
def test_office_documents_have_valid_container_signature(fmt):
    data, _, filename = generate_document(
        file_format=fmt,
        title="NIKO",
        content="Test content",
        sections=[{"heading": "Summary", "text": "A sample document"}],
        rows=[["A", "B"], ["1", "2"]],
    )
    assert data[:2] == b"PK"
    assert filename.endswith(f".{fmt}")


def test_unsupported_pdf_is_not_falsely_generated():
    with pytest.raises(ValueError, match="Unsupported format"):
        generate_document(file_format="pdf", title="CV")
