# Hybrid Parking Control System (HPCS) - Cấu trúc dự án

> Tài liệu cấu trúc cho team phát triển

## Tech Stack

| Công nghệ | Mục đích |
|---|---|
| **Next.js** (App Router) | Framework React full-stack |
| **TypeScript** | Type safety |
| **Tailwind CSS v4** | Styling |
| **shadcn/ui** (Radix) | UI Components |
| **MariaDB** (mysql2) | Database chính |
| **Python / FastAPI** | Nhận diện biển số (Backend tách rời) |
| **jose** / **jsonwebtoken** | Xác thực người dùng (Auth Cookies) |
| **Montserrat** | Font chủ đạo (Local font custom) |

## File Tree

```
website/
├── database/                               # Script Database
│   └── init.sql                            # Khởi tạo DB schemas và tài khoản mẫu (admin/admin123)
├── backend/                                # Python Backend cho xử lý Camera
│   ├── requirements.txt
│   ├── main.py                             # API endpoint Python (FastAPI)
│   └── camera/
│       └── scanner.py                      # Core AI quét frame camera (sẽ tích hợp OpenCV)
├── src/
│   ├── app/
│   │   ├── globals.css
│   │   ├── layout.tsx                      # Root sử dụng local font Montserrat
│   │   ├── page.tsx                        # Dashboard
│   │   ├── (auth)/                         # Nhóm route Auth
│   │   │   ├── layout.tsx
│   │   │   └── login/page.tsx             # Giao diện Đăng nhập
│   │   ├── (main)/                         # Route group chính
│   │   │   ├── layout.tsx                  # Navbar + Footer
│   │   │   ├── vehicles/                   
│   │   │   ├── parking-slots/             
│   │   │   ├── history/                    
│   │   │   └── camera/                     
│   │   └── api/                            
│   │       ├── auth/
│   │       │   ├── login/route.ts         # Sinh JWT token và Cookies auth
│   │       │   └── logout/route.ts        # Huỷ Cookies Auth
│   │       ├── vehicles/route.ts          
│   │       ├── parking-slots/route.ts     
│   │       ├── history/route.ts           
│   │       └── camera/route.ts            
│   ├── components/
│   │   ├── ui/                             # shadcn components
│   │   ├── navbar.tsx                      # Navbar có Dropdown Tài Khoản
│   │   └── footer.tsx
│   └── lib/
│       ├── db.ts                           # Code Query MariaDB (`query()`)
│       ├── camera.ts                       # Call sang `http://localhost:8000/api/scan-plate`
│       └── utils.ts
└── public/
```

## Conventions

### Authentication & Database
- Users được lưu ở `users` table tại cơ sở dữ liệu `parking_management`.
- Hệ thống sử dụng **NextAuth.js** (Auth.js) thông qua Provider `Credentials`. Xác thực được thực hiện qua `src/auth.ts`, cấu hình JWT session và trả header Set-Cookie tương ứng.
- Route bảo vệ được quản lý tự động bởi `src/middleware.ts`.

### Backend AI Python
- Quản lý process tách rời trên `localhost:8000`.
- API Call từ Server `src/lib/camera.ts` để lấy data biển số trả về. Nhờ vậy Next.js chỉ việc nhận data và render, không gánh logic nặng.

## Setup Development

```bash
# Cấu hình CSDL MariaDB (.env.local)
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=parking_management

# Chạy Database init (Bằng GUI Tool / CLI vào MariaDB server)
source database/init.sql

# Khởi chạy Next.js
npm install
npm run dev

# Khởi chạy Python Backend chuyên biệt
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```
