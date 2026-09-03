# Mini-Project 3: OCR Expense Tracker & Receipt Parser (Flutter & Dart)

> **Môn học:** Lập trình Đa Nền Tảng  
> **Đề tài:** Quản Lý Chi Tiêu & Bóc Tách Hóa Đơn Tự Động bằng On-Device AI (Google ML Kit) & Regex Heuristic  
> **Nền tảng hỗ trợ:** Web (PWA), Android, iOS, Windows, macOS, Linux  

---

## 🌟 Giới thiệu tổng quan

Ứng dụng **OCR Expense Tracker & Receipt Parser** được xây dựng bằng **Flutter 3.x** và **Dart 3**, đáp ứng trọn vẹn 100% các mục tiêu học tập (Learning Objectives) của bài tập:

1. **Quản lý tài chính cá nhân thông minh (Personal Finance App)**:
   - Quản lý thu chi đầy đủ (CRUD): Thêm, Sửa, Xóa, Tìm kiếm, Lọc theo danh mục.
   - Bảng màu phân loại danh mục: Ăn uống, Mua sắm, Di chuyển, Hóa đơn, Giải trí, Sức khỏe, Học tập...
   - Lưu trữ dữ liệu cục bộ bền vững (Local Persistence).

2. **On-Device AI với Google ML Kit Text Recognition**:
   - Nhận diện ký tự quang học (OCR) trực tiếp trên thiết bị (On-Device).
   - Hoạt động hoàn toàn **Offline**, bảo mật dữ liệu chi tiêu cá nhân, không tốn phí API đám mây.

3. **Thuật toán Regex Heuristic Parser bóc tách hóa đơn**:
   - **Monetary Totals**: Bóc tách tổng số tiền dựa trên quy tắc trọng số ngữ cảnh (`Tổng tiền`, `Total`, `Thanh toán`, `Cộng`, loại trừ dòng `VAT`, `Tiền khách đưa`, `Tiền thối`).
   - **Merchant Names**: Nhận diện tên nơi bán / cửa hàng (Highlands Coffee, WinMart+, Circle K, chuỗi bán lẻ, siêu thị, nhà hàng...).
   - **Transaction Dates**: Bóc tách ngày giờ giao dịch chuẩn xác (`dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yy` kèm giờ phút).
   - **Category Auto-Suggestion**: Tự động gợi ý danh mục chi tiêu dựa trên tên cửa hàng và mặt hàng.

4. **Biểu đồ hoạt họa tương tác vẽ hoàn toàn bằng `CustomPainter`**:
   - **Animated Pie Chart**: Vẽ bằng Canvas (`canvas.drawArc`), hiệu ứng animation xoay nở mượt mà (`CurvedAnimation`), chạm vào từng lát cắt để phóng to xem chi tiết số tiền và phần trăm.
   - **Animated Bar Chart**: Vẽ bằng Canvas (`canvas.drawRRect`), hiệu ứng các cột nhô lên từ 0, đường lưới tọa độ Y-axis và nhãn X-axis, chạm vào cột để xem chi tiết chi tiêu 7 ngày trong tuần.
   - *Đạt chuẩn 100% yêu cầu học thuật (không dùng thư viện ngoài cho biểu đồ).*

5. **Live Demo Web & Chuẩn Progressive Web App (PWA)**:
   - Hỗ trợ chạy trực tiếp trên trình duyệt Web.
   - Khi mở link demo bằng điện thoại (Chrome trên Android hoặc Safari trên iOS), người dùng có thể chọn **"Cài đặt ứng dụng" (Install App)** hoặc **"Thêm vào màn hình chính" (Add to Home Screen)** để dùng như app native độc lập.
   - Tích hợp sẵn bộ hóa đơn mẫu thực tế (Highlands, WinMart, Circle K, Pharmacity, Fahasa) để kiểm thử ngay lập tức.

---

## 📸 Cấu trúc thư mục dự án

```
mini_project3/
├── lib/
│   ├── main.dart                       # Điểm khởi chạy ứng dụng & Theme Material 3
│   ├── models/
│   │   ├── category.dart               # Danh mục chi tiêu & Màu sắc, Icon
│   │   ├── expense.dart                # Model khoản chi tiêu
│   │   └── receipt_result.dart         # Kết quả bóc tách từ OCR
│   ├── services/
│   │   ├── receipt_parser.dart         # BỘ NÃO REGEX HEURISTIC PARSER
│   │   ├── ocr_service.dart            # Tích hợp Google ML Kit & Bộ hóa đơn mẫu
│   │   └── database_service.dart       # Quản lý dữ liệu cục bộ và số liệu thống kê
│   ├── widgets/
│   │   ├── expense_card.dart           # Thẻ hiển thị khoản chi tiêu
│   │   └── charts/
│   │       ├── custom_pie_chart.dart   # Interactive Animated Pie Chart (CustomPainter)
│   │       └── custom_bar_chart.dart   # Interactive Animated Bar Chart (CustomPainter)
│   └── screens/
│       ├── home_screen.dart            # Màn hình chính Dashboard
│       ├── scan_receipt_screen.dart    # Chụp ảnh / Quét OCR & Duyệt kết quả bóc tách
│       ├── add_expense_screen.dart     # Thêm / Chỉnh sửa chi tiêu thủ công
│       ├── expense_list_screen.dart    # Sổ chi tiêu tìm kiếm & lọc
│       └── analytics_screen.dart       # Báo cáo thống kê chi tiết
├── test/
│   ├── receipt_parser_test.dart        # Unit Test kiểm thử thuật toán Regex Parser
│   └── widget_test.dart                # Smoke test khởi chạy giao diện
├── web/
│   ├── index.html                      # Cấu hình PWA HTML5
│   └── manifest.json                   # Cấu hình cài đặt ứng dụng trên Mobile
└── pubspec.yaml                        # Quản lý dependencies
```

---

## 🚀 Hướng dẫn cài đặt & Chạy dự án

### Yêu cầu tiên quyết
- **Flutter SDK:** Phiên bản 3.x (Đã kiểm thử trên Flutter 3.29.0)
- **Dart SDK:** Phiên bản 3.x (Dart 3.7+)
- Trình duyệt Chrome / Edge hoặc Máy ảo Android / Thiết bị thật.

### 1. Khởi chạy trên Web (Local)
```bash
# Cài đặt các thư viện phụ thuộc
flutter pub get

# Chạy trực tiếp trên trình duyệt Chrome
flutter run -d chrome
```

### 2. Chạy trên thiết bị Android
```bash
# Cắm cáp điện thoại Android hoặc mở máy ảo Android Emulator
flutter run -d android
```

### 3. Chạy Unit Test kiểm thử chất lượng
```bash
# Chạy toàn bộ các bài test tự động (bao gồm test bóc tách hóa đơn)
flutter test
```

---

## 🌐 Hướng dẫn Triển khai Live Demo (Vercel / GitHub Pages)

### Cách 1: Triển khai lên Vercel (Khuyên dùng - Cực nhanh)
1. Cài đặt Vercel CLI (nếu chưa có):
   ```bash
   npm install -g vercel
   ```
2. Build bản web:
   ```bash
   flutter build web --release
   ```
3. Đẩy lên Vercel:
   ```bash
   cd build/web
   vercel --prod
   ```
   *(Sau 1 phút, bạn sẽ nhận được Link Live Demo dạng `https://expense-ocr-xxxx.vercel.app`)*.

### Cách 2: Triển khai qua GitHub Pages
1. Đẩy toàn bộ mã nguồn lên repository GitHub (Public).
2. Vào **Settings** > **Pages** > Chọn nguồn build từ GitHub Actions hoặc branch `gh-pages`.

---

## 📱 Hướng dẫn "Cài đặt từ Mobile" (PWA)
1. Dùng điện thoại mở Link Live Demo bằng trình duyệt **Google Chrome** (Android) hoặc **Safari** (iOS).
2. Trên Android: Trình duyệt sẽ xuất hiện thanh thông báo **"Thêm ExpenseOCR vào màn hình chính"** hoặc bấm vào dấu 3 chấm góc trên bên phải -> chọn **"Cài đặt ứng dụng"**.
3. Trên iOS (iPhone): Bấm vào nút **Chia sẻ (Share)** ở thanh điều hướng dưới -> chọn **"Thêm vào MH chính" (Add to Home Screen)**.
4. Ứng dụng sẽ xuất hiện trên màn hình điện thoại với biểu tượng riêng và khởi chạy toàn màn hình như ứng dụng gốc!

---

## 👥 Tác giả
- Sinh viên thực hiện: Sinh viên môn Lập Trình Đa Nền Tảng
- Đề tài: Mini-Project 3: OCR Expense Tracker & Receipt Parser
