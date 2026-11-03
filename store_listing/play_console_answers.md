# ร่างคำตอบแบบฟอร์ม Play Console

เป็นร่างจากโค้ดและเอกสารของ Google ณ พฤศจิกายน 2026 คำถามจริงอาจเปลี่ยนชื่อหรือลำดับ คุณเป็นผู้รับผิดชอบคำตอบที่ส่ง จึงควรอ่านให้ตรงกับแอปก่อนกดส่ง

## App content

| แบบฟอร์ม | คำตอบที่แนะนำ | เหตุผล |
|---|---|---|
| App access | All functionality is available without special access | แอปไม่มีการล็อกอิน |
| Ads | No, my app does not contain ads | ไม่มีโฆษณา |
| Target audience | 18 ปีขึ้นไป | เกี่ยวกับการยืนยันตัวตนและประกัน |
| News app | No | |
| Government app | No | แอปไม่ได้พัฒนาโดยหรือในนามหน่วยงานรัฐ |
| Health apps | ไม่มีฟีเจอร์สุขภาพ | แบบประกันสุขภาพเป็นเพียงตัวอย่าง |
| Financial features | ดูหัวข้อด้านล่าง | ต้องตัดสินใจ |
| Content rating | ตอบตามจริงว่าไม่มีความรุนแรง เนื้อหาทางเพศ การพนัน หรือการแชร์ข้อมูลระหว่างผู้ใช้ | ใช้ประเภท Utility/Other |

### Financial features

ร่างคำตอบ: **My app doesn't provide any financial features** เพราะไม่มีการขายประกัน การรับเงิน หรือการเชื่อมต่อสถาบันการเงินจริง

แอปมีหน้าซื้อประกันและชำระเงินจำลอง ผู้ตรวจอาจมองต่างออกไป จึงควรอธิบายใน App access หรือ Notes ว่าเป็นการจำลอง ข้อความแนะนำ:

```text
This is a demo app. All insurance plans, payments and policies are simulated. It sells no insurance, takes no payment and connects to no bank or identity network. Reviewers can tap "กรอกข้อมูลตัวอย่าง" on the personal details screen to use sample data. The face check needs a front camera and a real face: align, blink, then turn the head and look straight again.
```

## Data safety

### คำถามภาพรวม

| คำถาม | คำตอบ | เหตุผล |
|---|---|---|
| Does your app collect or share required user data types? | Yes | ML Kit ส่งข้อมูลการวินิจฉัยไปยัง Google |
| Is all collected data encrypted in transit? | Yes | Google ระบุว่าส่งผ่าน HTTPS |
| Do you provide a way for users to request deletion? | ตอบตามการตั้งค่าของคุณ | ผู้พัฒนาไม่ได้เก็บข้อมูล และเอกสาร ML Kit ไม่ได้ระบุวิธีขอลบ ต้องอ่านเงื่อนไขในฟอร์มก่อนตอบ |

### ประเภทข้อมูลที่ต้องประกาศ

ทุกรายการ: Collected = Yes, Shared = No, Processed ephemerally = No, Required = Required, Purpose = Analytics

| หมวดในฟอร์ม | ข้อมูลจาก ML Kit |
|---|---|
| Device or other IDs | ตัวระบุการติดตั้ง |
| App info and performance > Diagnostics | ตัววัดประสิทธิภาพ เช่น latency |
| App info and performance > Crash logs หรือ Other app performance data | รหัสข้อผิดพลาดของเหตุการณ์ เลือกหมวดที่ตรงที่สุดเมื่อเห็นคำจำกัดความในฟอร์ม |
| App activity > Other actions | ประเภทเหตุการณ์ เช่น การเริ่มทำงานและการตรวจจับ |

ข้อมูลอุปกรณ์และแอป เช่น รุ่น เวอร์ชันระบบ และชื่อแพ็กเกจ ไม่มีหมวดตรงตัว ให้เทียบกับคำอธิบายในฟอร์มอีกครั้ง

### ข้อมูลที่ไม่ต้องประกาศว่าเก็บ

ข้อมูลเหล่านี้ไม่ออกจากเครื่อง จึงไม่เข้าข่าย "collected" ตามนิยามของ Google:

- ภาพจากกล้อง
- ชื่อ เลขบัตรประชาชน วันเกิด เบอร์มือถือ อีเมล และผู้รับผลประโยชน์

## สิทธิ์ในแอป

| สิทธิ์ | ใช้ทำอะไร |
|---|---|
| `CAMERA` | สแกนใบหน้าบนเครื่อง |
| `INTERNET`, `ACCESS_NETWORK_STATE` | ติดมากับ ML Kit เพื่อส่งข้อมูลการวินิจฉัย โค้ดของแอปไม่ได้ใช้ |

## ข้อมูลอ้างอิง

- [ML Kit data disclosure](https://developers.google.com/ml-kit/android-data-disclosure)
- [ML Kit terms and privacy](https://developers.google.com/ml-kit/terms)
- [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271)
- [Preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
