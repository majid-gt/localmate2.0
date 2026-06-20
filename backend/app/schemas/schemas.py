from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional
from datetime import datetime
from decimal import Decimal

# Token Schemas
class Token(BaseModel):
    access_token: str
    token_type: str
    is_new_user: bool = False

class TokenPayload(BaseModel):
    sub: Optional[str] = None

# User Schemas
class UserBase(BaseModel):
    name: str
    phone_number: str
    email: Optional[EmailStr] = None
    profile_photo_url: Optional[str] = None

class UserCreate(UserBase):
    google_id: Optional[str] = None
    fixed_otp: Optional[str] = None

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    profile_photo_url: Optional[str] = None

class ReputationScoreResponse(BaseModel):
    total_listings: int
    avg_rating: float
    total_reviews: int
    points: int
    reputation_level: str
    updated_at: datetime

    class Config:
        from_attributes = True

class UserResponse(UserBase):
    id: str
    is_active: bool
    created_at: datetime
    reputation: Optional[ReputationScoreResponse] = None

    class Config:
        from_attributes = True

# Category Schemas
class CategoryBase(BaseModel):
    name: str
    slug: str
    icon_url: Optional[str] = None

class CategoryResponse(CategoryBase):
    id: int
    is_active: bool

    class Config:
        from_attributes = True

# Listing Image Schemas
class ListingImageResponse(BaseModel):
    id: str
    image_url: str
    order_index: int

    class Config:
        from_attributes = True

# Listing Schemas
class ListingBase(BaseModel):
    name: str
    category_id: int
    owner_name: str
    owner_phone: str
    latitude: float
    longitude: float
    address: str
    working_days: List[int]
    working_hours: str  # Store working hours description (e.g. "9:00 AM - 6:00 PM")
    description: Optional[str] = None

class ListingCreate(ListingBase):
    pass

class ListingUpdate(BaseModel):
    name: Optional[str] = None
    owner_name: Optional[str] = None
    owner_phone: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None
    working_days: Optional[List[int]] = None
    working_hours: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

class ListingResponse(ListingBase):
    id: str
    contributor_id: Optional[str]
    status: str
    created_at: datetime
    images: List[ListingImageResponse] = []
    average_rating: float = 0.0
    reviews_count: int = 0
    is_open: bool = True
    distance: Optional[float] = None  # Optional distance in kilometers

    class Config:
        from_attributes = True

class ListingDetailedResponse(ListingResponse):
    category: CategoryResponse
    contributor: Optional[UserResponse] = None

    class Config:
        from_attributes = True

# Service Review Schemas
class ServiceReviewCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class ServiceReviewResponse(BaseModel):
    id: str
    listing_id: str
    author_id: str
    rating: int
    comment: Optional[str]
    created_at: datetime
    author: Optional[UserBase] = None

    class Config:
        from_attributes = True

# Contributor Review Schemas
class ContributorReviewCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None
    listing_id: Optional[str] = None
    image_url: Optional[str] = None
    special_points: Optional[int] = Field(default=0, ge=0)

class ContributorReviewResponse(BaseModel):
    id: str
    contributor_id: str
    author_id: str
    rating: int
    comment: Optional[str]
    listing_id: Optional[str] = None
    image_url: Optional[str] = None
    special_points: int = 0
    created_at: datetime
    author: Optional[UserBase] = None
    listing: Optional[ListingResponse] = None

    class Config:
        from_attributes = True

# Suggestions Schemas
class ListingSuggestionCreate(BaseModel):
    comment: str

class ListingSuggestionResponse(BaseModel):
    id: str
    listing_id: str
    contributor_id: str
    comment: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class AdminListingSuggestionResponse(ListingSuggestionResponse):
    listing_name: str
    contributor_name: str

