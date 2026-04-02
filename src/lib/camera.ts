/**
 * Camera Device Handler
 *
 * module kết nối và xử lý camera nhận diện biển số liên kết đến Backend Python
 */

export interface CameraDevice {
  id: string;
  name: string;
  ipAddress: string;
  port: number;
  status: "online" | "offline" | "error";
}

export interface CapturedFrame {
  timestamp: Date;
  imageBuffer: Buffer | null;
  cameraId: string;
}

export interface PlateDetectionResult {
  plateNumber: string | null;
  confidence: number;
  timestamp: Date;
  cameraId: string;
}

export async function connectCamera(
  ipAddress: string,
  port: number
): Promise<CameraDevice> {
  return {
    id: `cam_${Date.now()}`,
    name: `Camera ${ipAddress}`,
    ipAddress,
    port,
    status: "online",
  };
}

export async function captureFrame(
  cameraId: string
): Promise<CapturedFrame> {
  return {
    timestamp: new Date(),
    imageBuffer: null,
    cameraId,
  };
}

/**
 * Nhận diện biển số thông qua FastAPI Backend
 */
export async function detectPlate(
  frame: CapturedFrame
): Promise<PlateDetectionResult> {
  try {
    const res = await fetch(`http://localhost:8000/api/scan-plate?camera_id=${frame.cameraId}`);
    if (!res.ok) {
      throw new Error(`Python API error: ${res.statusText}`);
    }
    const data = await res.json();
    return {
      plateNumber: data.plate_number,
      confidence: data.confidence,
      timestamp: frame.timestamp,
      cameraId: frame.cameraId,
    };
  } catch (error) {
    console.error("Camera detectPlate error:", error);
    return {
      plateNumber: null,
      confidence: 0,
      timestamp: frame.timestamp,
      cameraId: frame.cameraId,
    };
  }
}

export async function disconnectCamera(cameraId: string): Promise<void> {
  console.log(`Camera ${cameraId} disconnected`);
}

export async function getConnectedCameras(): Promise<CameraDevice[]> {
  return [];
}
