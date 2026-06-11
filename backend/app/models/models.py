from sqlalchemy import Column, Integer, String, Float, Boolean, Text, ForeignKey, ForeignKeyConstraint, UniqueConstraint, Numeric, DateTime, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, index=True) # UUID stored as string
    phone_number = Column(String(20), unique=True, index=True, nullable=False)
    email = Column(String(255), nullable=True)
    name = Column(String(100), nullable=False)
    profile_photo_url = Column(String(500), nullable=True)
    google_id = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    listings = relationship("Listing", back_populates="contributor", cascade="all, delete-orphan")
    saved_listings = relationship("SavedListing", back_populates="user", cascade="all, delete-orphan")
    reviews_written = relationship("ServiceReview", back_populates="author", cascade="all, delete-orphan")
    contributor_reviews_written = relationship("ContributorReview", foreign_keys="[ContributorReview.author_id]", back_populates="author", cascade="all, delete-orphan")
    contributor_reviews_received = relationship("ContributorReview", foreign_keys="[ContributorReview.contributor_id]", back_populates="contributor", cascade="all, delete-orphan")
    reputation = relationship("ReputationScore", back_populates="user", uselist=False, cascade="all, delete-orphan")
    suggestions = relationship("ListingSuggestion", back_populates="contributor", cascade="all, delete-orphan")

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    slug = Column(String(100), unique=True, index=True, nullable=False)
    icon_url = Column(String(500), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    listings = relationship("Listing", back_populates="category")

class Listing(Base):
    __tablename__ = "listings"

    id = Column(String(36), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="RESTRICT"), nullable=False)
    owner_name = Column(String(100), nullable=False)
    owner_phone = Column(String(20), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(Text, nullable=False)
    working_days = Column(JSON, nullable=False) # e.g. [1, 2, 3, 4, 5]
    working_hours = Column(Text, nullable=False) # Store JSON string or raw text working hours description
    description = Column(Text, nullable=True)
    contributor_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    status = Column(String(50), default="active", nullable=False) # active, disabled
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Unique Constraint to prevent duplicates
    __table_args__ = (
        UniqueConstraint("owner_phone", "category_id", name="unique_owner_phone_category"),
    )

    # Relationships
    category = relationship("Category", back_populates="listings")
    contributor = relationship("User", back_populates="listings")
    images = relationship("ListingImage", back_populates="listing", cascade="all, delete-orphan")
    saved_by_users = relationship("SavedListing", back_populates="listing", cascade="all, delete-orphan")
    reviews = relationship("ServiceReview", back_populates="listing", cascade="all, delete-orphan")
    suggestions = relationship("ListingSuggestion", back_populates="listing", cascade="all, delete-orphan")

class ListingImage(Base):
    __tablename__ = "listing_images"

    id = Column(String(36), primary_key=True, index=True)
    listing_id = Column(String(36), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False)
    image_url = Column(String(500), nullable=False)
    order_index = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    listing = relationship("Listing", back_populates="images")

class SavedListing(Base):
    __tablename__ = "saved_listings"

    id = Column(String(36), primary_key=True, index=True)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    listing_id = Column(String(36), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "listing_id", name="unique_user_saved_listing"),
    )

    # Relationships
    user = relationship("User", back_populates="saved_listings")
    listing = relationship("Listing", back_populates="saved_by_users")

class ServiceReview(Base):
    __tablename__ = "service_reviews"

    id = Column(String(36), primary_key=True, index=True)
    listing_id = Column(String(36), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False)
    author_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rating = Column(Integer, nullable=False)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    listing = relationship("Listing", back_populates="reviews")
    author = relationship("User", back_populates="reviews_written")

class ContributorReview(Base):
    __tablename__ = "contributor_reviews"

    id = Column(String(36), primary_key=True, index=True)
    contributor_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    author_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rating = Column(Integer, nullable=False)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    contributor = relationship("User", foreign_keys=[contributor_id], back_populates="contributor_reviews_received")
    author = relationship("User", foreign_keys=[author_id], back_populates="contributor_reviews_written")

class ReputationScore(Base):
    __tablename__ = "reputation_scores"

    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    total_listings = Column(Integer, default=0, nullable=False)
    avg_rating = Column(Numeric(3, 2), default=0.00, nullable=False)
    total_reviews = Column(Integer, default=0, nullable=False)
    points = Column(Integer, default=0, nullable=False)
    reputation_level = Column(String(50), default="Bronze Contributor", nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    user = relationship("User", back_populates="reputation")

class ListingSuggestion(Base):
    __tablename__ = "listing_suggestions"

    id = Column(String(36), primary_key=True, index=True)
    listing_id = Column(String(36), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False)
    contributor_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    comment = Column(Text, nullable=False)
    status = Column(String(50), default="pending", nullable=False) # pending, resolved
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    listing = relationship("Listing", back_populates="suggestions")
    contributor = relationship("User", back_populates="suggestions")
