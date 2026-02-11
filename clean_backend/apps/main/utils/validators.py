import os
from django.core.exceptions import ValidationError

def validate_file_extension(value, valid_extensions):
    ext = os.path.splitext(value.name)[1]
    if not ext.lower() in valid_extensions:
        raise ValidationError(f'Unsupported file extension. Allowed extensions: {", ".join(valid_extensions)}')

def validate_image_file_extension(value):
    validate_file_extension(value, ['.jpg', '.jpeg', '.png', '.gif', '.webp'])

def validate_video_file_extension(value):
    validate_file_extension(value, ['.mp4', '.webm', '.ogg'])

def validate_file_size(value, max_size_mb):
    limit = max_size_mb * 1024 * 1024
    if value.size > limit:
        raise ValidationError(f'File too large. Size should not exceed {max_size_mb} MB.')

def validate_image_file_size_5mb(value):
    validate_file_size(value, 5)

def validate_image_file_size_2mb(value):
    validate_file_size(value, 2)

def validate_video_file_size_10mb(value):
    validate_file_size(value, 10)
