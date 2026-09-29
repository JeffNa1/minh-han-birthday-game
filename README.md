# Minh Hân · Lễ Hội Trái Tim

Game sinh nhật tặng Minh Hân, lấy cảm hứng từ trò Flash **Sát thủ tình trường 2** (*Romance Academy 2*).
Làm bằng **Godot 4.7**. Toàn bộ hình ảnh (nhân vật, trang phục, phụ kiện, thú cưng, bối cảnh, hiệu ứng)
đều được vẽ bằng code dạng vector mềm, không dùng ảnh sprite.

## Cách chơi

- **Rê chuột** để Minh Hân đi khắp sân trường, hành lang tầng 2 và sân thượng (lên xuống bằng cầu thang ở cuối đường).
- **Giữ chuột trái** lên một Nam Anh để phóng tia tình yêu. Chàng đổ sẽ bay lơ lửng theo sau Minh Hân.
  Ở các màn sau, chàng vẫn bước đi khi đang bị phóng tia, nên phải rê chuột bám theo.
- **Thước tình cảm 10 tim**: mỗi chàng đổ +1 tim, tim tự hao dần theo thời gian. Đầy 10 tim trước khi hết giờ để qua màn.
- **Đối thủ** (emo, bikini, mèo đen, quý cô, thủ thư, yandere, ca sĩ, diễn viên…) sẽ cướp chàng của bạn:
  bấm chuột thật nhanh để giành lại.
- **Cô quản lý** đi tuần: tán tỉnh trong tầm mắt cô là bị bắt, mất tim và một chàng hoảng sợ bỏ chạy.
- Phím **1–9** hoặc tủ đồ góc dưới để thay trang phục đã có.

10 màn khó dần. Sau mỗi màn thắng được xu và mở một trong năm hộp quà.

## Tuỳ biến và tiến trình

- 39 bộ trang phục (có 5 bộ váy dạ hội full set), 9 kiểu tóc, 10 màu tóc, 6 màu da.
- Mũ và tiara, cánh, hào quang, thú cưng đi theo, 7 kiểu tia tình yêu; món đặc biệt giá cao bằng kim cương.
- Tủ đồ & Cửa hàng mua bằng xu hoặc kim cương; cấp độ người chơi (XP) thưởng xu và kim cương khi lên cấp.
- Hộp quà dùng "túi bi": 20 lần mở có đúng 1 bộ trang phục, nên chắc chắn ra đồ trong 20 lần.
- Tiến trình lưu ở `user://profile.json`.

## Chạy game

Cần [Godot 4.7](https://godotengine.org/) (renderer Mobile/Vulkan để viền được khử răng cưa).

```bash
godot --path .
```

Trên Windows có thể nhấp đúp `play_game.bat` (cần `godot` trong PATH).

## Kiểm thử

Các bài test chạy headless:

```bash
godot --headless --path . --script res://tests/test_level_flow.gd
```

Danh sách: `test_player_controls`, `test_wardrobe`, `test_clash_input`, `test_menu_flow`, `test_round_flow`,
`test_level_flow`, `test_gift_shop`. Test dùng hồ sơ tạm, không đụng tới file lưu thật.
Các script `tests/capture_*.gd` chụp ảnh màn hình bằng GPU vào `user://captures`.

## Cấu trúc

```
scripts/
  art/        vẽ nhân vật dùng chung, trang phục, phụ kiện, bối cảnh, không khí
  entities/   Minh Hân, Nam Anh, đối thủ, cô quản lý, thú cưng, rig nhân vật
  world/      dữ liệu khu vực và màn chơi, biển cầu thang
  ui/         HUD, tranh giành, thanh tiền, ô vật phẩm
  vfx/        tia tình yêu, hiệu ứng hạt, camera rung
  autoload/   GameManager, Profile (lưu game), AudioManager, Transition
  data/       danh mục vật phẩm và giá
scenes/       menu, màn chơi, hộp quà, tủ đồ, kết thúc
tests/        test tự động và script chụp ảnh
```

## Ghi công

- Font **Inter** © The Inter Project Authors, giấy phép SIL Open Font License 1.1 (xem `assets/fonts/LICENSE-Inter.txt`).
- Ý tưởng lối chơi dựa trên *Sát thủ tình trường 2 / Romance Academy 2*; game này không dùng tài nguyên nào của bản gốc.
