import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys
import os

# Ensure backend directory is in the path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
from app.core.database import Base, get_db
from app.repositories.category_repo import CategoryRepository

# For tests, we try to use a test PostgreSQL DB first. If it fails (e.g. Postgres is not running),
# we fall back to a local SQLite file database so tests can run in any environment.
from app.core.config import settings
TEST_DATABASE_URL = f"postgresql://{settings.POSTGRES_USER}:{settings.POSTGRES_PASSWORD}@{settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}/{settings.POSTGRES_DB}_test"

connect_args = {}
try:
    engine = create_engine(TEST_DATABASE_URL)
    # Check connection
    engine.connect()
except Exception:
    # Fallback to SQLite database
    TEST_DATABASE_URL = "sqlite:///./localmate_test.db"
    connect_args = {"check_same_thread": False}
    engine = create_engine(TEST_DATABASE_URL, connect_args=connect_args)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session", autouse=True)
def setup_db():
    # Recreate tables
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    # Seed default categories
    db = TestingSessionLocal()
    CategoryRepository.seed_categories(db)
    db.close()
    
    yield
    # Cleanup after session
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db():
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass
            
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()
