"""Tests for Markdown parser."""

from pathlib import Path

from kb.parsers.markdown import MarkdownParser


def test_markdown_parser_basic():
    """Test basic Markdown parsing with headings."""
    parser = MarkdownParser()

    # Create temporary test file
    test_content = """# Top Level

Some content here.

## Second Level

More content.

### Third Level

Final content.
"""
    test_file = Path("/tmp/test_markdown.md")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Should have 3 chunks (one per heading)
        assert len(chunks) == 3

        # Check first chunk
        assert chunks[0].metadata.breadcrumb == ["Top Level"]
        assert "# Top Level" in chunks[0].content

        # Check second chunk
        assert chunks[1].metadata.breadcrumb == ["Top Level", "Second Level"]
        assert "## Second Level" in chunks[1].content

        # Check third chunk
        assert chunks[2].metadata.breadcrumb == [
            "Top Level",
            "Second Level",
            "Third Level",
        ]
        assert "### Third Level" in chunks[2].content

        # Check relationships
        assert chunks[1].parent_id == chunks[0].id
        assert chunks[2].parent_id == chunks[1].id

    finally:
        test_file.unlink(missing_ok=True)


def test_markdown_parser_no_headings():
    """Test Markdown parsing with no headings."""
    parser = MarkdownParser()

    test_content = "Just plain text without any headings."
    test_file = Path("/tmp/test_no_headings.md")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Should have 1 chunk (entire file)
        assert len(chunks) == 1
        assert chunks[0].metadata.breadcrumb == []
        assert chunks[0].content == test_content

    finally:
        test_file.unlink(missing_ok=True)


def test_markdown_parser_real_file():
    """Test parsing real queue/ file."""
    parser = MarkdownParser()

    # Use dashboard.md if it exists
    dashboard_path = Path("/home/quieter/projects/multi-agent-bakuhu/dashboard.md")

    if dashboard_path.exists():
        chunks = parser.parse(dashboard_path)

        # Should have at least one chunk
        assert len(chunks) > 0

        # All chunks should have valid metadata
        for chunk in chunks:
            assert chunk.id
            assert chunk.metadata.path == str(dashboard_path)
            assert chunk.metadata.chunk_type == "markdown"
            assert chunk.metadata.line_start > 0
            assert chunk.metadata.line_end >= chunk.metadata.line_start
            assert chunk.metadata.file_mtime > 0
            assert len(chunk.metadata.chunk_hash) == 40  # SHA1 hex


def test_markdown_parser_siblings():
    """Test sibling relationship detection."""
    parser = MarkdownParser()

    test_content = """# Top

## Child 1

Content 1.

## Child 2

Content 2.

## Child 3

Content 3.
"""
    test_file = Path("/tmp/test_siblings.md")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Find child chunks (level 2)
        child_chunks = [c for c in chunks if len(c.metadata.breadcrumb) == 2]

        assert len(child_chunks) == 3

        # Each child should have 2 siblings
        for chunk in child_chunks:
            assert len(chunk.sibling_ids) == 2

    finally:
        test_file.unlink(missing_ok=True)
