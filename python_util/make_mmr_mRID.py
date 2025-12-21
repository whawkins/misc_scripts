import hashlib


def simple_structured_mmr_mrid(lfdi: bytes, reading_type: str, pen: str) -> str:
    """
    Generate a structured mRID: [LFDI prefix][ReadingType ID][PEN suffix]
    
    Parameters:
    - lfdi: The LFDI (20-byte hash)
    - reading_type: Name of the reading type (e.g., "Voltage")
    - pen: Hex string representing your PEN or vendor ID (e.g., "A1B2")
    
    Returns:
    - 32-character uppercase mRID string
    """
    print(f"[DEBUG] Input parameters:")
    print(f"  - lfdi: {lfdi.hex()}")
    print(f"  - reading_type: {reading_type}")
    print(f"  - pen: {pen}")
    print()
    
    # Step 1: LFDI prefix (first 8 bytes = 16 hex chars)
    lfdi_prefix = lfdi[:8].hex().upper()
    print(f"[DEBUG] Step 1 - LFDI prefix (first 8 bytes):")
    print(f"  - lfdi_prefix: {lfdi_prefix} (length: {len(lfdi_prefix)})")
    print()

    # Step 2: Hash the reading type to get consistent 8 hex chars
    reading_hash = hashlib.sha256(reading_type.encode("utf-8")).digest()
    reading_type_id = reading_hash[:4].hex().upper()  # 4 bytes = 8 hex chars
    print(f"[DEBUG] Step 2 - Reading type hash:")
    print(f"  - reading_type input: {reading_type}")
    print(f"  - full sha256 hash: {reading_hash.hex()}")
    print(f"  - reading_type_id (first 4 bytes): {reading_type_id} (length: {len(reading_type_id)})")
    print()

    # Step 3: Ensure PEN suffix is 8 hex characters (pad if needed)
    pen_suffix = pen.upper().zfill(8)[:8]
    print(f"[DEBUG] Step 3 - PEN suffix:")
    print(f"  - pen input: {pen}")
    print(f"  - pen_suffix: {pen_suffix} (length: {len(pen_suffix)})")
    print()

    # Combine
    mrid = (lfdi_prefix + reading_type_id + pen_suffix)[:32]  # Ensure exactly 32 chars
    print(f"[DEBUG] Final mRID composition:")
    print(f"  - {lfdi_prefix} + {reading_type_id} + {pen_suffix} = {lfdi_prefix + reading_type_id + pen_suffix}")
    print(f"  - mrid (trimmed to 32 chars): {mrid} (length: {len(mrid)})")
    print()
    return mrid



# Example usage
if __name__ == "__main__":
    # Simulated LFDI (SHA-256 hash of some unique device cert)
    cert = b"DeviceCertOrID"
    lfdi = hashlib.sha256(cert).digest()[:20]
    
    pen = "1A2B"  # Your Private Enterprise Number in hex (can be longer or shorter)
    reading_types = ["RealPower", "ReactivePower", "Voltage", "Frequency"]
    
    for rt in reading_types:
        mrid = simple_structured_mmr_mrid(lfdi, rt, pen)
        print(f"{rt} → mRID: {mrid}")