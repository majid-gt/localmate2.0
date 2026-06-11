from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from typing import Generator
from app.core.config import settings

try:
    engine = create_engine(
        settings.DATABASE_URL,
        pool_pre_ping=True,
    )
    # Test connection
    conn = engine.connect()
    conn.close()
except Exception as e:
    print(f"WARNING: PostgreSQL connection failed: {e}. Falling back to SQLite localmate_dev.db.")
    sqlite_url = "sqlite:///./localmate_dev.db"
    engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db() -> Generator:
    try:
        db = SessionLocal()
        yield db
    finally:
        db.close()
