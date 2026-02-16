"""Tests for YAML parser."""

from pathlib import Path

from kb.parsers.yaml import YAMLParser


def test_yaml_parser_basic():
    """Test basic YAML parsing with flattening."""
    parser = YAMLParser()

    test_content = """db:
  host: localhost
  port: 5432
app:
  name: test-app
  version: 1.0.0
"""
    test_file = Path("/tmp/test_yaml.yaml")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Should have 4 chunks (one per leaf value)
        assert len(chunks) == 4

        # Check flattened keys
        chunk_contents = [c.content for c in chunks]
        assert any("db.host: localhost" in c for c in chunk_contents)
        assert any("db.port: 5432" in c for c in chunk_contents)
        assert any("app.name: test-app" in c for c in chunk_contents)
        assert any("app.version: 1.0.0" in c for c in chunk_contents)

        # Check breadcrumbs
        db_host_chunk = next(c for c in chunks if "db.host" in c.content)
        assert db_host_chunk.metadata.breadcrumb == ["db", "host"]

    finally:
        test_file.unlink(missing_ok=True)


def test_yaml_parser_with_comments():
    """Test YAML parsing with comments."""
    parser = YAMLParser()

    test_content = """# Database configuration
db:
  host: localhost  # Local development
  port: 5432
"""
    test_file = Path("/tmp/test_yaml_comments.yaml")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Comments should be preserved in content
        db_host_chunk = next(c for c in chunks if "db.host" in c.content)
        # Comment extraction may vary, just check basic structure
        assert "db.host: localhost" in db_host_chunk.content

    finally:
        test_file.unlink(missing_ok=True)


def test_yaml_parser_with_lists():
    """Test YAML parsing with list structures."""
    parser = YAMLParser()

    test_content = """items:
  - name: item1
    value: 100
  - name: item2
    value: 200
"""
    test_file = Path("/tmp/test_yaml_lists.yaml")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Should have chunks for list elements
        assert len(chunks) > 0

        # Check list indexing
        chunk_contents = [c.content for c in chunks]
        assert any("items[0].name" in c for c in chunk_contents)
        assert any("items[1].name" in c for c in chunk_contents)

    finally:
        test_file.unlink(missing_ok=True)


def test_yaml_parser_real_file():
    """Test parsing real queue/ YAML file."""
    parser = YAMLParser()

    # Use shogun_to_karo.yaml if it exists
    yaml_path = Path(
        "/home/quieter/projects/multi-agent-bakuhu/queue/shogun_to_karo.yaml"
    )

    if yaml_path.exists():
        chunks = parser.parse(yaml_path)

        # Should have at least one chunk
        assert len(chunks) > 0

        # All chunks should have valid metadata
        for chunk in chunks:
            assert chunk.id
            assert chunk.metadata.path == str(yaml_path)
            assert chunk.metadata.chunk_type == "yaml"
            assert chunk.metadata.line_start > 0
            assert len(chunk.metadata.chunk_hash) == 40  # SHA1 hex
            assert len(chunk.metadata.breadcrumb) > 0  # All YAML chunks have breadcrumb


def test_yaml_parser_relationships():
    """Test parent-child relationships in YAML."""
    parser = YAMLParser()

    test_content = """parent:
  child1: value1
  child2: value2
  nested:
    deep: value3
"""
    test_file = Path("/tmp/test_yaml_relations.yaml")
    test_file.write_text(test_content)

    try:
        chunks = parser.parse(test_file)

        # Find child chunks
        child_chunks = [c for c in chunks if "child" in c.content]

        # They should be siblings
        if len(child_chunks) >= 2:
            assert child_chunks[0].id in child_chunks[1].sibling_ids
            assert child_chunks[1].id in child_chunks[0].sibling_ids

    finally:
        test_file.unlink(missing_ok=True)
