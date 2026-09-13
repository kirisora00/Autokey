# Flip Coin test system

ไฟล์ชุดนี้แยกจาก target-locator.lua และทำไว้สำหรับแมพที่คุณเป็นเจ้าของใน Roblox Studio

## ไฟล์

- server.lua — ใส่เป็น Script ใน ServerScriptService
- client.lua — ใส่เป็น LocalScript ใน StarterPlayer > StarterPlayerScripts

## ติดตั้ง

1. เปิด Roblox Studio และเปิดแมพใหม่
2. สร้าง Script ใน ServerScriptService แล้ววางเนื้อหาจาก server.lua
3. สร้าง LocalScript ใน StarterPlayerScripts แล้ววางเนื้อหาจาก client.lua
4. กด Play

เมนู FLIP COIN จะอยู่ด้านขวา มีปุ่มพลิกครั้งเดียว, AUTO FLIP, ปรับช่วงเวลา, ยุบ และปิด

## ปรับความเร็ว

แก้ค่าใน server.lua:

- ManualCooldown = 0.50
- AutoMinInterval = 0.25

เซิร์ฟเวอร์จะเป็นผู้ตรวจคูลดาวน์และเพิ่ม Coins จึงไม่เกิดปัญหาที่หน้าจอเร็วแต่รางวัลไม่ทำงาน

ระบบนี้สร้าง leaderstats.Coins เพื่อการทดสอบ ถ้าแมพมีระบบเงินของตัวเอง ให้เปลี่ยน getCoinValue() ให้คืนค่า Value ของระบบเดิมแทนการสร้าง Coins ใหม่

ระบบนี้เป็นโค้ดสำหรับ Roblox Studio ในแมพของคุณเอง ไม่ใช่ตัวโหลดสำหรับเกมของผู้อื่น
