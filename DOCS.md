# Hybrid Parking Control System (HPCS) - Tài liệu kỹ thuật

> Tài liệu cấu trúc và vận hành cho team phát triển.

Chi tiết luồng thanh toán end-to-end: xem `PAYMENT_FLOW.md`.

## Tech Stack

| Công nghệ | Mục đích |
|---|---|
| Next.js 16 (App Router) | Full-stack web framework |
| React 19 + TypeScript | Frontend và type safety |
| Tailwind CSS v4 + shadcn/ui | UI system |
| MariaDB (mysql2) | Cơ sở dữ liệu nghiệp vụ |
| NextAuth v5 (Credentials + JWT) | Xác thực và phân quyền |
| Python / FastAPI | Service nhận diện biển số |

## Cấu trúc thư mục chính

```
.
├── database/
│   ├── init.sql                        # Schema + seed user admin
│   └── migrations/
│       └── 2026-04-13_payments_compat.sql
├── backend/
│   ├── main.py                         # API Python cho nhận diện biển số
│   └── camera/scanner.py
├── src/
│   ├── app/
│   │   ├── layout.tsx                  # Root layout + bootstrap scheduler sync
│   │   ├── page.tsx                    # Dashboard tổng quan
│   │   ├── (auth)/login/page.tsx
│   │   ├── (main)/
│   │   │   ├── vehicles/
│   │   │   ├── parking-slots/
│   │   │   ├── history/
│   │   │   ├── camera/
│   │   │   └── transactions/           # Trang thống kê doanh thu + set giá
│   │   ├── (pay)/payment/page.tsx      # Trang QR/payment demo đơn giản
│   │   └── api/
│   │       ├── auth/[...nextauth]/route.ts
│   │       ├── vehicles/route.ts
│   │       ├── parking-slots/route.ts
│   │       ├── history/route.ts
│   │       ├── camera/route.ts
│   │       ├── dashboard/overview/route.ts
│   │       ├── reports/revenue/route.ts
│   │       ├── parking-rates/route.ts
│   │       └── payments/
│   │           ├── route.ts
│   │           └── sync/route.ts
│   ├── components/
│   ├── lib/
│   │   ├── db.ts
│   │   ├── reports.ts
│   │   ├── payments.ts
│   │   ├── xgate.ts
│   │   ├── payment-sync.ts
│   │   └── payment-sync-scheduler.ts
│   ├── auth.ts
│   └── proxy.ts                        # Bảo vệ route + RBAC API
└── public/
```

## Database model

Ngoài các bảng cũ (`users`, `vehicles`, `parking_slots`, `history`, `cameras`), hệ thống hiện có thêm:

- `parking_rates`: cấu hình giá theo loại xe (`vehicle_type`, `unit_price`, `is_active`)
- `payments`: lưu hóa đơn thanh toán và trạng thái đối soát
	- Trạng thái: `pending | paid | failed`
	- Đồng bộ: `xgate_reference`, `matched_content`, `paid_at`, `synced_at`

Ghi chú thiết kế hiện tại:

- Không sử dụng bảng `transactions` riêng cho thống kê.
- Không dùng `payment_sync_logs` hoặc `payment_sync_state`.
- Thống kê lưu lượng lấy từ bảng `history`.

## API chính

### Core APIs

- `GET/POST /api/vehicles`
- `GET/POST/PATCH/DELETE /api/parking-slots`
- `GET/POST /api/history`
- `GET /api/camera` (bridge sang Python backend)

### Dashboard và báo cáo

- `GET /api/dashboard/overview`
	- Trả về KPI dashboard, recent history events, camera/system status.

- `GET /api/reports/revenue?date_from=YYYY-MM-DD&date_to=YYYY-MM-DD`
	- Trả về revenue timeseries, status distribution, traffic series, totals, parking rates.

### Payment và đối soát XGate

- `GET /api/payments?limit=20`
- `GET /api/payments?invoice_number=HPCS-...`
- `POST /api/payments`
	- Tạo payment trạng thái `pending`.
	- Nếu không truyền `amount`, hệ thống lấy đơn giá active từ `parking_rates` theo `vehicleType`.

- `POST /api/payments/sync`
	- Trigger đối soát thủ công với XGate.
	- Match theo quy tắc: `invoice_number` xuất hiện trong `content` giao dịch chuyển khoản.

- `GET /api/parking-rates`
- `PATCH /api/parking-rates`
	- Cập nhật loạt đơn giá.

## Auth và RBAC

- Auth dùng NextAuth Credentials ở `src/auth.ts`.
- Route guard nằm tại `src/proxy.ts`.
- Với request chưa đăng nhập:
	- Route web: redirect về `/login`.
	- Route API: trả JSON `401 Unauthorized`.
- API yêu cầu role `admin`:
	- `POST /api/payments/sync`
	- `PATCH /api/parking-rates`

## Luồng đồng bộ XGate

Nguồn triển khai:

- `src/lib/xgate.ts`: gọi API XGate và normalize payload.
- `src/lib/payment-sync.ts`: đối soát payment pending.
- `src/lib/payment-sync-scheduler.ts`: scheduler định kỳ.

Nguyên tắc:

- Giới hạn gọi XGate tối đa `5 requests/phút` (rate limit cục bộ process).
- Chỉ cập nhật payment đang `pending`.
- Khi match thành công: cập nhật `status=paid`, `paid_at`, `synced_at`, `xgate_reference`, `matched_content`.

Scheduler:

- Bootstrap ở `src/app/layout.tsx`.
- Không chạy trong phase build production để tránh side effect build-time.

## Biến môi trường

```bash
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=parking_management

# NextAuth
AUTH_SECRET=replace-with-secure-random-string

# Python backend scanner
PYTHON_API_URL=http://localhost:8000

# XGate
XGATE_API_KEY=your-xgate-api-key
XGATE_API_URL=https://xgate.vn/api/v1/transactions
XGATE_ACCOUNT=9394441571
XGATE_SYNC_ENABLED=false
XGATE_SYNC_INTERVAL_MS=300000
XGATE_MAX_REQUESTS_PER_RUN=1
XGATE_PAGE_LIMIT=50
XGATE_TYPE=in

# Payment QR (VietQR)
PAYMENT_QR_BANK_CODE=mb
PAYMENT_QR_ACCOUNT_NUMBER=9394441571
PAYMENT_QR_ACCOUNT_NAME=LE VAN NHAT
PAYMENT_QR_TEMPLATE=compact2
```

## Setup development

### 1) Cài dependencies

```bash
npm install
```

### 2) Khởi tạo hoặc nâng cấp database

Khởi tạo mới:

```bash
mysql -u root -p < database/init.sql
```

Nếu DB đã tồn tại từ phiên bản cũ, cần đảm bảo có đủ bảng/cột mới (`parking_rates`, `payments`, `payments.synced_at`) trước khi chạy tính năng payment sync.

Có thể chạy migration compatibility:

```bash
mysql -u root -p parking_management < database/migrations/2026-04-13_payments_compat.sql
```

Nếu DB chạy trong Docker (ví dụ container `hpcs-mariadb`):

```bash
Get-Content database/migrations/2026-04-13_payments_compat.sql | docker exec -i hpcs-mariadb mariadb -uroot -proot parking_management
```

### 3) Chạy web app

```bash
npm run dev
```

### 4) Chạy Python backend (camera scanner)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

## Validation trước khi merge

```bash
npm run lint
npm run build
```
