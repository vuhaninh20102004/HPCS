import random
import time

def process_camera_frame(camera_id: str) -> dict:
    """
    Mock OCR scanner module.
    Trong thực tế, function này sẽ dùng OpenCV kết nối RTSP
    và dùng mô hình nhận diện trả về kết quả biển số.
    """
    # ... mock delay
    time.sleep(0.5)
    
    # Mock plates
    mock_plates = ["29A-123.45", "30F-999.99", "51G-234.56", "15A-333.33", "UNKNOWN"]
    detected = random.choice(mock_plates)
    
    if detected == "UNKNOWN":
        return {
            "plate_number": None,
            "confidence": 0.0
        }
        
    return {
        "plate_number": detected,
        # random confidence 0.8 -> 0.99
        "confidence": round(0.8 + random.random() * 0.19, 2)
    }
