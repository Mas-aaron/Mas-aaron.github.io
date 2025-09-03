from firebase_admin import messaging
from .models import Device
from decimal import Decimal


def format_ugx_currency(amount):
    """
    Format amount as Ugandan Shillings (UGX)
    Example: 15000 -> "UGX 15,000"
    """
    if isinstance(amount, (int, float, Decimal)):
        # UGX typically doesn't use decimal places
        formatted_amount = f"{int(amount):,}"
        return f"UGX {formatted_amount}"
    return f"UGX {amount}"


def parse_ugx_amount(ugx_string):
    """
    Parse UGX string back to numeric amount
    Example: "UGX 15,000" -> 15000
    """
    if isinstance(ugx_string, str):
        # Remove UGX prefix and commas
        cleaned = ugx_string.replace('UGX', '').replace(',', '').strip()
        try:
            return Decimal(cleaned)
        except:
            return Decimal('0')
    return Decimal(str(ugx_string))
