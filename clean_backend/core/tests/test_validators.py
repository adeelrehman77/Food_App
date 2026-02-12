import pytest
from unittest.mock import MagicMock, patch
from django.core.exceptions import ValidationError
from core.utils.validators import (
    validate_phone_number, validate_file_size, validate_image_file_extension,
    validate_video_file_extension, validate_password_strength, validate_emirates_id,
    validate_uae_phone_number, validate_postal_code, validate_credit_card_number,
    validate_cvv, validate_expiry_date, sanitize_html, validate_json_schema,
    validate_file_upload
)

class TestValidators:
    def test_validate_phone_number(self):
        assert validate_phone_number('1234567') == '1234567'
        assert validate_phone_number('+1-234-567-8901') == '+1-234-567-8901'
        with pytest.raises(ValidationError):
            validate_phone_number('123')
        with pytest.raises(ValidationError):
            validate_phone_number('1'*16)

    def test_validate_file_size(self):
        file = MagicMock()
        file.size = 1024 * 1024 # 1MB
        validate_file_size(file, max_size_mb=5)
        
        file.size = 6 * 1024 * 1024
        with pytest.raises(ValidationError):
            validate_file_size(file, max_size_mb=5)

    def test_validate_image_extension(self):
        file = MagicMock()
        file.name = 'test.jpg'
        validate_image_file_extension(file)
        
        file.name = 'test.txt'
        with pytest.raises(ValidationError):
            validate_image_file_extension(file)

    def test_validate_password_strength(self):
        assert validate_password_strength('StrongP@ss1') == 'StrongP@ss1'
        with pytest.raises(ValidationError): validate_password_strength('short')
        with pytest.raises(ValidationError): validate_password_strength('nouppercase1!')
        with pytest.raises(ValidationError): validate_password_strength('NOLOWERCASE1!')
        with pytest.raises(ValidationError): validate_password_strength('NoDigit!')
        with pytest.raises(ValidationError): validate_password_strength('NoSpecial1')

    def test_validate_emirates_id(self):
        assert validate_emirates_id('784-1980-1234567-1') == '784198012345671'
        with pytest.raises(ValidationError):
            validate_emirates_id('123')

    def test_validate_uae_phone(self):
        assert validate_uae_phone_number('971501234567') == '971501234567'
        assert validate_uae_phone_number('0501234567') == '0501234567'
        with pytest.raises(ValidationError):
            validate_uae_phone_number('123')

    def test_validate_credit_card(self):
        # Luhn test
        # 4532 0151 1283 036 (Visa validity check - 13 digits is min but 16 common)
        # 4242 4242 4242 4242 (Valid Visa Test Number)
        valid = '4242424242424242'
        assert validate_credit_card_number(valid) == valid
        with pytest.raises(ValidationError):
            validate_credit_card_number('4242424242424241') # Invalid checksum
        with pytest.raises(ValidationError):
             validate_credit_card_number('abc')

    def test_sanitize_html(self):
        with patch('bleach.clean') as mock_clean:
            mock_clean.return_value = 'safe'
            assert sanitize_html('<script>bad</script>') == 'safe'

    def test_validate_json_schema(self):
        with patch('jsonschema.validate'):
            assert validate_json_schema({}, {}) == {}
