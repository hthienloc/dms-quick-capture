# Thuật ngữ / Glossary

Dưới đây là các thuật ngữ dùng trong plugin, code, và settings để tránh nhầm lẫn.

## Annotation concepts

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Tool** | Công cụ vẽ / chỉnh sửa (pen, line, arrow, rect, etc.) | `toolButtons` trong CaptureConfig.qml |
| **Stroke** | Một đường vẽ hoàn chỉnh do user tạo ra | Lưu trong strokes JSON |
| **Annotation** | Tổng thể tất cả strokes + text + stamp trên canvas | Export ra ảnh cuối cùng |
| **Canvas** | Vùng vẽ chính, chứa screenshot + annotation | `drawingCanvas` trong QuickCaptureModal.qml |
| **Screenshot** | Ảnh chụp màn hình gốc (chưa annotate) | `bgImage`, nằm dưới strokes |

## Color / Palette

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Palette** | Bộ 8 màu có sẵn để chọn | Preset (Nord, Solarized, Adaptive) hoặc Custom |
| **Preset** | Palette màu định sẵn (Nord, Solarized, Adaptive) | Không thể sửa trực tiếp |
| **Custom palette** | Palette màu user tự định nghĩa | Có thể ghi đè từng slot |
| **Color slot** | 1 trong 8 ô màu trên toolbar | Slot 0 = primary, Slot 1-7 = accent |
| **Slot** | Viết tắt của color slot | Dùng trong code: `toolbar_color_0`, `slot_1`... |
| **Accent color** | Màu phụ (slot 2-8) | Phân biệt với primary |
| **Primary color** | Màu chính (slot 1) | Thường dùng làm màu mặc định cho tool |

## Toolbar

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Toolbar** | Thanh công cụ chính, chứa tất cả tools + tùy chỉnh | QuickCaptureToolbar.qml |
| **Horizontal toolbar** | Toolbar nằm ngang (dưới modal) | Layout chính, đủ chỗ cho tất cả tools |
| **Vertical toolbar** | Toolbar dọc (trái modal) | Bị giới hạn chiều cao, cần 2 hàng |
| **More tools** | Menu phụ chứa các actions: rotate, mirror, OCR, QR | MoreToolsMenu.qml |
| **Action button** | Nút thực thi hành động (không phải tool vẽ) | Export, Copy, Float, Undo, Redo |
| **Tool button** | Nút chọn tool vẽ | Pen, Line, Arrow, Rect, etc. |

## Backdrop

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Backdrop** | Nền phía sau screenshot | Có padding, shadow, corner radius |
| **Backdrop mode** | Kiểu backdrop: none, solid, gradient, radial, conic | BackdropModeSelectors.qml |
| **Backdrop padding** | Khoảng cách từ viền screenshot đến viền backdrop | Mặc định 40px |
| **Backdrop shadow** | Bóng đổ mô phỏng (4 lớp đè) | Chưa có GPU blur |
| **Backdrop alignment** | Vị trí screenshot trong khung backdrop | 9 vị trí (hiện tại chỉ center) |

## Radial menu

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Radial menu** | Menu vòng tròn xuất hiện khi right-click | RadialMenu.qml |
| **Radial preset** | 1 trong 8 slot của radial menu | Mỗi slot gồm: tool + color + thickness |
| **Center button** | Nút giữa radial menu (chọn Select tool) | `centerClicked` signal |
| **Hover trigger** | Auto-chọn preset khi hover qua sector | Không cần click |
| **Sector** | Một phần của radial menu (1/8 vòng tròn) | |

## Capture / Export

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Capture** | Hành động chụp màn hình | `capture()` function |
| **Region capture** | Chụp một vùng chọn trên màn hình | |
| **Fullscreen capture** | Chụp toàn màn hình | |
| **Export** | Xuất ảnh đã annotate ra file | PNG / WebP / JPEG |
| **Float** | Đưa ảnh đang edit ra cửa sổ riêng (luôn ở trên) | Cần dms-floaty |
| **Restore from float** | Mở lại ảnh từ float window để tiếp tục edit | |
| **Copy to clipboard** | Copy annotation ra clipboard (không lưu file) | |

## Tools (vẽ)

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Pen / Freehand** | Vẽ tự do bằng chuột | `strokeWidth` kiểm soát độ dày |
| **Line** | Vẽ đường thẳng | Click điểm đầu → kéo → thả |
| **Arrow** | Vẽ đường thẳng có mũi tên | Double-headed, dashed styles |
| **Rectangle / Rect** | Vẽ hình chữ nhật | Border styles: dashed, dotted |
| **Ellipse** | Vẽ hình ellipse / circle | |
| **Text** | Thêm text annotation | Font size = `thickness` |
| **Pixelate** | Làm mờ vùng chọn (mosaic) | `thickness` = pixel block size |
| **Redact** | Che vùng chọn bằng màu đen | Shape: rectangle (hiện tại) |
| **Stamp** | Đánh số thứ tự (1, 2, 3...) | Number stamp |
| **Highlighter** | Tô màu trong suốt (highlight) | |
| **Spotlight** | Làm tối vùng ngoài spotlight | Còn gọi là "focus spotlight" |
| **Callout** | Zoom một vùng ảnh | Còn gọi là "area zoom" |
| **Backdrop** | Bật/tắt chế độ nền | Không phải tool vẽ, là mode |

## Actions (không phải tool vẽ)

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Select** | Chọn / di chuyển annotation có sẵn | Tool mặc định (phím V) |
| **Eraser** | Xóa stroke / annotation | |
| **Crop** | Cắt ảnh | |
| **Color picker** | Chọn màu từ ảnh | Eyedropper (phím F) |
| **Rotate** | Xoay ảnh (CW / CCW) | |
| **Mirror** | Lật ảnh (ngang / dọc) | |
| **OCR** | Nhận diện text từ ảnh (copy ra clipboard) | |
| **Scan QR** | Quét QR code từ ảnh | |
| **Copy Color** | Copy màu tại vị trí click | Eyedropper tool |

## Settings / PluginData

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **pluginData** | Object lưu tất cả settings của plugin | Key-value, persist ra file |
| **Setting** | Một giá trị cấu hình cụ thể | Mỗi key trong pluginData |
| **Preset (tool)** | Radial preset = tool + color + thickness | |
| **Preset (palette)** | Bộ màu có sẵn (Nord, Solarized...) | Context: palette preset |
| **Starting tool** | Tool được chọn khi mở capture | Có thể là 1 tool cụ thể hoặc radial preset |
| **Default preset** | Radial preset mặc định khi capture | `defaultPresetIndex` (0-7) |

## Misc

| Thuật ngữ | Ý nghĩa | Ghi chú |
|---|---|---|
| **Modal** | Cửa sổ capture chính (toàn màn hình) | QuickCaptureModal.qml |
| **Daemon** | Service chạy nền, quản lý lifecycle | QuickCaptureDaemon.qml |
| **Float window** | Cửa sổ nhỏ luôn ở trên, hiển thị annotation | Do dms-floaty quản lý |
| **IPC** | Giao tiếp giữa các process | Dùng `dms ipc call` |
| **Stroke JSON** | File lưu tất cả annotation dưới dạng JSON | `/tmp/dms_capture_strokes.json` |
| **Sidecar** | File JSON đi kèm ảnh float, lưu trạng thái backdrop + strokes | |
