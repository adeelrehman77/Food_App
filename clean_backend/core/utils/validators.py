import re
from django.core.exceptions import ValidationError
from django.core.validators import EmailValidator
from django.utils.translation import gettext_lazy as _

def validate_phone_number(value):
    """Validate phone number format."""
    # Remove all non-digit characters
    digits_only = re.sub(r'\D', '', value)
    
    # Check if it's a valid length (7-15 digits)
    if len(digits_only) < 7 or len(digits_only) > 15:
        raise ValidationError(_('Phone number must be between 7 and 15 digits.'))
    
    return value

def validate_file_size(value, max_size_mb=5):
    """Validate file size."""
    max_size_bytes = max_size_mb * 1024 * 1024
    
    if value.size > max_size_bytes:
        raise ValidationError(
            _('File size must be no more than %(max_size)s MB.'),
            params={'max_size': max_size_mb}
        )

def validate_image_file_extension(value):
    """Validate image file extension."""
    import os
    ext = os.path.splitext(value.name)[1]
    valid_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
    
    if not ext.lower() in valid_extensions:
        raise ValidationError(_('Unsupported file extension.'))

def validate_video_file_extension(value):
    """Validate video file extension."""
    import os
    ext = os.path.splitext(value.name)[1]
    valid_extensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm']
    
    if not ext.lower() in valid_extensions:
        raise ValidationError(_('Unsupported video file extension.'))

def validate_password_strength(password):
    """Validate password strength."""
    if len(password) < 8:
        raise ValidationError(_('Password must be at least 8 characters long.'))
    
    if not re.search(r'[A-Z]', password):
        raise ValidationError(_('Password must contain at least one uppercase letter.'))
    
    if not re.search(r'[a-z]', password):
        raise ValidationError(_('Password must contain at least one lowercase letter.'))
    
    if not re.search(r'\d', password):
        raise ValidationError(_('Password must contain at least one digit.'))
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise ValidationError(_('Password must contain at least one special character.'))
    
    return password

def validate_emirates_id(value):
    """Validate Emirates ID format."""
    # Remove spaces and dashes
    clean_value = re.sub(r'[\s-]', '', value)
    
    # Check if it's 15 digits
    if not re.match(r'^\d{15}$', clean_value):
        raise ValidationError(_('Emirates ID must be 15 digits.'))
    
    return clean_value

def validate_uae_phone_number(value):
    """Validate UAE phone number format."""
    # Remove all non-digit characters
    digits_only = re.sub(r'\D', '', value)
    
    # UAE phone numbers start with 971 or 050, 051, 052, 054, 055, 056, 058
    if digits_only.startswith('971'):
        if len(digits_only) != 12:  # 971 + 9 digits
            raise ValidationError(_('Invalid UAE phone number format.'))
    elif digits_only.startswith(('050', '051', '052', '054', '055', '056', '058')):
        if len(digits_only) != 10:  # 050 + 7 digits
            raise ValidationError(_('Invalid UAE phone number format.'))
    else:
        raise ValidationError(_('Invalid UAE phone number format.'))
    
    return value

def validate_postal_code(value):
    """Validate postal code format."""
    # UAE doesn't use postal codes, but this can be used for other countries
    if not re.match(r'^\d{5}(-\d{4})?$', value):
        raise ValidationError(_('Invalid postal code format.'))
    
    return value

def validate_credit_card_number(value):
    """Validate credit card number using Luhn algorithm."""
    # Remove spaces and dashes
    digits = re.sub(r'\D', '', value)
    
    if not digits.isdigit():
        raise ValidationError(_('Credit card number must contain only digits.'))
    
    if len(digits) < 13 or len(digits) > 19:
        raise ValidationError(_('Credit card number must be between 13 and 19 digits.'))
    
    # Luhn algorithm
    checksum = 0
    num_digits = len(digits)
    oddeven = num_digits & 1
    
    for count in range(num_digits):
        digit = int(digits[count])
        if not (( count & 1 ) ^ oddeven ):
            digit = digit * 2
        if digit > 9:
            digit = digit - 9
        checksum = checksum + digit
    
    if checksum % 10 != 0:
        raise ValidationError(_('Invalid credit card number.'))
    
    return value

def validate_cvv(value):
    """Validate CVV code."""
    if not value.isdigit():
        raise ValidationError(_('CVV must contain only digits.'))
    
    if len(value) < 3 or len(value) > 4:
        raise ValidationError(_('CVV must be 3 or 4 digits.'))
    
    return value

def validate_expiry_date(value):
    """Validate card expiry date."""
    if not re.match(r'^\d{2}/\d{2}$', value):
        raise ValidationError(_('Expiry date must be in MM/YY format.'))
    
    month, year = value.split('/')
    month = int(month)
    year = int(year)
    
    if month < 1 or month > 12:
        raise ValidationError(_('Invalid month.'))
    
    # Add 2000 to year if it's less than 50, otherwise add 1900
    if year < 50:
        year += 2000
    else:
        year += 1900
    
    from datetime import datetime
    current_date = datetime.now()
    expiry_date = datetime(year, month, 1)
    
    if expiry_date < current_date:
        raise ValidationError(_('Card has expired.'))
    
    return value

def sanitize_html(value):
    """Sanitize HTML content."""
    import bleach
    
    allowed_tags = [
        'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'a', 'img', 'table', 'tr', 'td', 'th', 'thead', 'tbody'
    ]
    
    allowed_attributes = {
        'a': ['href', 'title'],
        'img': ['src', 'alt', 'title'],
        '*': ['class', 'id']
    }
    
    return bleach.clean(value, tags=allowed_tags, attributes=allowed_attributes, strip=True)

def validate_json_schema(value, schema):
    """Validate JSON against a schema."""
    try:
        import jsonschema
        jsonschema.validate(value, schema)
        return value
    except ImportError:
        # If jsonschema is not available, skip validation
        return value
    except jsonschema.ValidationError as e:
        raise ValidationError(f'JSON validation error: {str(e)}')

def validate_file_upload(value, allowed_types=None, max_size_mb=5):
    """Comprehensive file upload validation."""
    if allowed_types is None:
        allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    
    # Check file size
    validate_file_size(value, max_size_mb)
    
    # Check file type
    if hasattr(value, 'content_type') and value.content_type not in allowed_types:
        raise ValidationError(_('File type not allowed.'))
    
    # Check file extension
    import os
    ext = os.path.splitext(value.name)[1].lower()
    allowed_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
    
    if ext not in allowed_extensions:
        raise ValidationError(_('File extension not allowed.'))
    
    return value 