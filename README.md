# J2ME Decade for iOS

Ứng dụng giả lập J2ME đa nhiệm (Multi-Tab), tích hợp bộ định tuyến Proxy (SOCKS5/HTTP) và công cụ Thay đổi IP Server Game (dành cho Ninja School Online và các game Java) dành cho iPhone / iPad.

## Tính năng nổi bật
* **Đa Tab (Multi-Tab / Multi-Slot):** Mở nhiều tab game chạy song song trên cùng một màn hình.
* **Thay IP Server:** Danh sách máy chủ NSO định sẵn (Bokken, Shuriken, Tessen, Kunai, Katana) hoặc tự nhập IP & Port tùy biến.
* **Gán Proxy Riêng Từng Tab:** Hỗ trợ SOCKS5 và HTTP Connect tunneling.
* **Bàn phím ảo J2ME đầy đủ:** LSK, RSK, D-Pad điều hướng và Numpad 0-9, *, #.
* **Tự động Build IPA bằng GitHub Actions:** Tự động biên dịch mã nguồn thành file `.ipa` thông qua máy ảo macOS của GitHub.

## Hướng dẫn cài đặt lên iPhone bằng Sideloadly
1. Vào tab **Actions** trên GitHub repository này.
2. Chọn bản build mới nhất và tải file `J2ME-Decade-IPA` về máy tính (giải nén sẽ có file `J2ME-Decade.ipa`).
3. Mở **Sideloadly** trên máy tính:
   * Kéo file `J2ME-Decade.ipa` vào Sideloadly.
   * Nhập Apple ID của bạn.
   * Cắm cáp iPhone và bấm **Start**.
4. Trên iPhone: Vào **Cài đặt -> Cài đặt chung -> Quản lý VPN & Thiết bị** -> Chọn Tin cậy (Trust) tài khoản Apple ID của bạn để mở app.
