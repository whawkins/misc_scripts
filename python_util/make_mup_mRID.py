import hashlib

def generate_mup_mrid(lfdi: bytes, role_flag: int, pen: str) -> str:
    """
    Generate a structured mRID for a Mirror Usage Point (MUP).
    
    Parameters:
    - lfdi: LFDI as 20-byte hash.
    - role_flag: Integer representing the MUP roleFlag (e.g., 0x49, 0x03).
    - pen: Hex string of your PEN (e.g., "1A2B").
    
    Returns:
    - 32-character mRID string.
    """
    print(f"[DEBUG] Input parameters:")
    print(f"  - lfdi: {lfdi.hex()}")
    print(f"  - role_flag: {role_flag} (0x{role_flag:02X})")
    print(f"  - pen: {pen}")
    print()
    
    # LFDI prefix (8 bytes → 16 hex chars)
    lfdi_prefix = lfdi[:8].hex().upper()
    print(f"[DEBUG] Step 1 - LFDI prefix (first 8 bytes):")
    print(f"  - lfdi_prefix: {lfdi_prefix} (length: {len(lfdi_prefix)})")
    print()

    # RoleFlag ID (encode as 4-byte hex, padded)
    role_hex = role_flag.to_bytes(4, byteorder="big").hex().upper()  # 4 bytes = 8 hex
    print(f"[DEBUG] Step 2 - RoleFlag encoding:")
    print(f"  - role_flag input: {role_flag} (0x{role_flag:02X})")
    print(f"  - role_hex (4-byte big-endian): {role_hex} (length: {len(role_hex)})")
    print()

    # PEN suffix (ensure 8 hex chars)
    pen_suffix = pen.upper().zfill(8)[:8]
    print(f"[DEBUG] Step 3 - PEN suffix:")
    print(f"  - pen input: {pen}")
    print(f"  - pen_suffix: {pen_suffix} (length: {len(pen_suffix)})")
    print()

    # Combine
    mrid = (lfdi_prefix + role_hex + pen_suffix)[:32]
    print(f"[DEBUG] Final mRID composition:")
    print(f"  - {lfdi_prefix} + {role_hex} + {pen_suffix} = {lfdi_prefix + role_hex + pen_suffix}")
    print(f"  - mrid (trimmed to 32 chars): {mrid} (length: {len(mrid)})")
    print()
    return mrid

# Example usage
if __name__ == "__main__":
    # Simulate device LFDI (from certificate or unique ID)
    device_id = b"MyDeviceCertOrID"
    lfdi = hashlib.sha256(device_id).digest()[:20]

    pen = "1A2B"  # Your enterprise number
    role_flags = [0x49, 0x03]

    for rf in role_flags:
        mrid = generate_mup_mrid(lfdi, rf, pen)
        print(f"RoleFlag {rf:02X} → mRID: {mrid}")