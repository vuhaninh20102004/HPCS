import uvicorn
from fastapi import FastAPI, HTTPException
from camera.scanner import process_camera_frame
from pydantic import BaseModel
from typing import Optional

app = FastAPI(title="HPCS Camera Backend", version="1.0.0")

class ScanResult(BaseModel):
    plate_number: Optional[str]
    confidence: float
    message: str

@app.get("/")
def read_root():
    return {"message": "Camera Backend is running"}

@app.get("/api/scan-plate", response_model=ScanResult)
def scan_plate(camera_id: str = "default_cam"):
    """
    Endpoint mô phỏng lấy frame từ camera và nhận diện biển số
    """
    try:
        result = process_camera_frame(camera_id)
        return ScanResult(
            plate_number=result.get("plate_number"),
            confidence=result.get("confidence", 0.0),
            message="Quét thành công"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
