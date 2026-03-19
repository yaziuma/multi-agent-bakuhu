---
name: pydantic-config-system
description: YAMLベースの型安全な設定管理システム。pydantic + pydantic-settings で環境変数オーバーライド対応。バリデーション、型安全性、12-factor app準拠。
---

# Pydantic Config System - 型安全設定管理

## Overview

pydantic-settings を使った型安全な設定管理システム。
YAMLファイル + 環境変数オーバーライドで、開発・本番環境の切り替えが容易。

## When to Use

- アプリケーション設定を型安全に管理したい時
- 環境変数での設定オーバーライドが必要な時
- 設定値のバリデーションを自動化したい時
- 12-factor app の設定パターンを実装する時

## Benefits

- **型安全**: mypyで設定の型ミスを検出
- **バリデーション**: pydanticで自動バリデーション
- **環境変数**: 本番環境でYAMLを使わず環境変数のみで設定可能
- **デフォルト値**: コード内にデフォルト値を定義
- **ネスト構造**: 設定を階層化して整理
- **自動補完**: IDEで設定項目の補完が効く

## Instructions

### Step 1: 依存関係インストール

```bash
uv add pydantic pydantic-settings pyyaml
uv add --dev types-pyyaml
```

### Step 2: 設定クラス定義（src/config/settings.py）

```python
"""
Configuration management using pydantic-settings.

This module provides type-safe configuration loading from YAML files
with environment variable overrides.
"""

import os
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseModel):
    """Database configuration."""

    host: str = Field("localhost", description="Database host")
    port: int = Field(5432, ge=1, le=65535, description="Database port")
    name: str = Field("mydb", description="Database name")
    user: str = Field("user", description="Database user")
    password: str = Field("", description="Database password")
    pool_size: int = Field(10, ge=1, le=100, description="Connection pool size")


class LoggingSettings(BaseModel):
    """Logging configuration."""

    level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        "INFO", description="Logging level"
    )
    format: str = Field(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        description="Log format string",
    )
    file: str = Field("logs/app.log", description="Log file path")


class Settings(BaseSettings):
    """
    Application settings.

    Loads configuration from YAML file with environment variable overrides.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_nested_delimiter="__",
        extra="ignore",
    )

    # Application settings
    app_name: str = Field("MyApp", description="Application name")
    debug: bool = Field(False, description="Debug mode")

    # Nested settings
    database: DatabaseSettings = DatabaseSettings()
    logging: LoggingSettings = LoggingSettings()


def load_settings(config_path: str | Path = "config/settings.yaml") -> Settings:
    """
    Load settings from YAML file with environment variable overrides.

    Args:
        config_path: Path to YAML configuration file

    Returns:
        Settings instance with loaded configuration

    Raises:
        FileNotFoundError: If config file doesn't exist
        yaml.YAMLError: If config file is invalid YAML

    Note:
        Environment variables can override YAML values using the format:
        SECTION__KEY=value (e.g., DATABASE__HOST=localhost)

        This function loads YAML first, then applies environment variable
        overrides by creating a Settings instance that reads from env vars.
    """
    config_path = Path(config_path)

    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_path, "r", encoding="utf-8") as f:
        config_data = yaml.safe_load(f)

    if config_data is None:
        config_data = {}

    # Apply environment variable overrides manually for better control
    for section in ["database", "logging"]:
        section_upper = section.upper()
        if section in config_data and isinstance(config_data[section], dict):
            for key in list(config_data[section].keys()):
                env_key = f"{section_upper}__{key.upper()}"
                env_value = os.environ.get(env_key)
                if env_value is not None:
                    # Parse the environment variable value
                    try:
                        config_data[section][key] = int(env_value)
                    except ValueError:
                        try:
                            config_data[section][key] = float(env_value)
                        except ValueError:
                            # Boolean parsing
                            if env_value.lower() in ("true", "yes", "1"):
                                config_data[section][key] = True
                            elif env_value.lower() in ("false", "no", "0"):
                                config_data[section][key] = False
                            else:
                                config_data[section][key] = env_value

    return Settings(**config_data)
```

### Step 3: YAML設定ファイル作成（config/settings.yaml）

```yaml
# Application Settings
app_name: "MyApp"
debug: true

# Database Settings
database:
  host: "localhost"
  port: 5432
  name: "mydb"
  user: "admin"
  password: "secret"
  pool_size: 20

# Logging Settings
logging:
  level: "DEBUG"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  file: "logs/app.log"
```

### Step 4: 使用方法

```python
# main.py
from config.settings import load_settings

def main() -> None:
    # Load settings
    settings = load_settings("config/settings.yaml")

    # Access settings with type safety
    print(f"App: {settings.app_name}")
    print(f"Database: {settings.database.host}:{settings.database.port}")
    print(f"Log level: {settings.logging.level}")

    # Settings are immutable by default (Pydantic frozen)
    # settings.debug = True  # This would raise an error if frozen=True

if __name__ == "__main__":
    main()
```

## Environment Variable Overrides

### 命名規則

環境変数名は `セクション名__キー名` の形式（大文字、ダブルアンダースコア）：

```bash
# database.host をオーバーライド
export DATABASE__HOST="production-db.example.com"

# database.port をオーバーライド
export DATABASE__PORT="5433"

# logging.level をオーバーライド
export LOGGING__LEVEL="ERROR"

# トップレベル設定
export DEBUG="false"
```

### 使用例

```bash
# 開発環境（YAML使用）
uv run python main.py

# 本番環境（環境変数使用）
DATABASE__HOST="prod-db.example.com" \
DATABASE__PASSWORD="$DB_PASSWORD" \
LOGGING__LEVEL="INFO" \
uv run python main.py
```

## Testing

### テストコード例（tests/test_config.py）

```python
"""Tests for configuration management."""

import os
from pathlib import Path

import pytest
import yaml

from config.settings import DatabaseSettings, Settings, load_settings


def test_database_settings_defaults():
    """Test DatabaseSettings default values."""
    db = DatabaseSettings()
    assert db.host == "localhost"
    assert db.port == 5432
    assert db.name == "mydb"


def test_database_settings_validation():
    """Test DatabaseSettings validation."""
    # Valid port
    db = DatabaseSettings(port=3306)
    assert db.port == 3306

    # Invalid port (out of range)
    with pytest.raises(ValueError):
        DatabaseSettings(port=70000)


def test_settings_from_dict():
    """Test Settings creation from dictionary."""
    config = {
        "app_name": "TestApp",
        "debug": True,
        "database": {
            "host": "testhost",
            "port": 5433,
        },
    }
    settings = Settings(**config)
    assert settings.app_name == "TestApp"
    assert settings.database.host == "testhost"


def test_load_settings_from_yaml(tmp_path: Path):
    """Test loading settings from YAML file."""
    # Create test YAML
    config_file = tmp_path / "test_settings.yaml"
    config = {
        "app_name": "TestApp",
        "debug": False,
        "database": {
            "host": "localhost",
            "port": 5432,
        },
        "logging": {
            "level": "DEBUG",
        },
    }

    with open(config_file, "w") as f:
        yaml.dump(config, f)

    # Load settings
    settings = load_settings(config_file)
    assert settings.app_name == "TestApp"
    assert settings.database.host == "localhost"
    assert settings.logging.level == "DEBUG"


def test_env_var_override(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Test environment variable overrides."""
    # Create base YAML
    config_file = tmp_path / "test_settings.yaml"
    config = {
        "database": {
            "host": "localhost",
            "port": 5432,
        },
    }

    with open(config_file, "w") as f:
        yaml.dump(config, f)

    # Set environment variable
    monkeypatch.setenv("DATABASE__HOST", "prod-db.example.com")
    monkeypatch.setenv("DATABASE__PORT", "5433")

    # Load settings
    settings = load_settings(config_file)
    assert settings.database.host == "prod-db.example.com"
    assert settings.database.port == 5433
```

## Guidelines

### 設定の設計原則

1. **デフォルト値は必須**: 全ての設定にデフォルト値を定義
2. **型ヒント必須**: 全ての設定フィールドに型ヒントを付ける
3. **バリデーション**: Field() で制約を定義（ge, le, regex等）
4. **description**: 各フィールドの説明を書く（self-documentingな設定）
5. **ネスト構造**: 関連する設定はBaseModelでグループ化
6. **機密情報**: パスワード等は環境変数で渡す（YAMLにコミットしない）

### 避けるべきこと

- YAMLに機密情報を直接書く
- バリデーションを省略する
- 型ヒントを省く（型安全性が失われる）
- 設定を直接変更する（イミュータブルにすべき）

### セキュリティ

```python
# 機密情報は環境変数で渡す
class DatabaseSettings(BaseModel):
    host: str = "localhost"
    port: int = 5432
    password: str = Field(
        "",
        description="Database password (set via env: DATABASE__PASSWORD)"
    )

# YAMLファイルには書かない
# database:
#   password: "secret123"  # ❌ NG

# 環境変数で渡す
# export DATABASE__PASSWORD="secret123"  # ✅ OK
```

## Advanced Examples

### 複雑な設定の例

```python
from typing import List

class APISettings(BaseModel):
    """API configuration."""

    base_url: str = Field(..., description="API base URL")
    timeout: int = Field(30, ge=1, le=300, description="Request timeout (seconds)")
    retry_count: int = Field(3, ge=0, le=10, description="Retry attempts")
    api_key_env: str = Field("API_KEY", description="Env var name for API key")


class FeatureFlags(BaseModel):
    """Feature flags."""

    enable_cache: bool = Field(True, description="Enable caching")
    enable_metrics: bool = Field(False, description="Enable metrics collection")
    allowed_origins: List[str] = Field(
        default_factory=lambda: ["http://localhost:3000"],
        description="CORS allowed origins",
    )


class Settings(BaseSettings):
    """Extended application settings."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_nested_delimiter="__",
    )

    api: APISettings
    features: FeatureFlags = FeatureFlags()
    database: DatabaseSettings = DatabaseSettings()
```

### 環境別設定

```python
from enum import Enum

class Environment(str, Enum):
    """Application environment."""

    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"


class Settings(BaseSettings):
    """Settings with environment support."""

    env: Environment = Field(
        Environment.DEVELOPMENT,
        description="Application environment",
    )

    @property
    def is_production(self) -> bool:
        """Check if running in production."""
        return self.env == Environment.PRODUCTION


# Usage
settings = load_settings()
if settings.is_production:
    # Production-specific logic
    pass
```

## Quick Start

```bash
# 1. 依存関係追加
uv add pydantic pydantic-settings pyyaml
uv add --dev types-pyyaml

# 2. ディレクトリ作成
mkdir -p src/config config

# 3. ファイル作成
# - src/config/settings.py (上記コード)
# - config/settings.yaml (YAML設定)

# 4. テスト作成
# - tests/test_config.py (テストコード)

# 5. 動作確認
uv run python -c "from config.settings import load_settings; print(load_settings())"
```

## Notes

- **pydantic v2**: 最新の pydantic v2 を推奨（v1とは互換性なし）
- **pydantic-settings**: 環境変数統合のための公式拡張
- **env_nested_delimiter**: `__` で階層構造を環境変数に表現
- **extra="ignore"**: 未定義の設定項目を無視（柔軟性向上）
- **Field()**: バリデーション・デフォルト値・説明を定義
- **.env ファイル**: 開発環境では .env ファイルでローカル設定を管理

## References

- [Pydantic Settings Documentation](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [12-Factor App: Config](https://12factor.net/config)
