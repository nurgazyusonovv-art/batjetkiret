from pydantic import BaseModel, Field, field_validator

class RegisterRequest(BaseModel):
    phone: str = Field(..., min_length=10, max_length=20)
    name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=6, max_length=100)
    is_courier: bool = False
    
    @field_validator('phone')
    def phone_must_contain_digits(cls, v):
        if not any(c.isdigit() for c in v):
            raise ValueError('Phone must contain at least one digit')
        return v

class LoginRequest(BaseModel):
    phone: str = Field(..., min_length=10, max_length=20)
    password: str = Field(..., min_length=6, max_length=100)

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict
