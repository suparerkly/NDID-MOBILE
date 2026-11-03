// เว็บไม่มี dart:io และ ML Kit จึงใช้หน้าตรวจใบหน้าแบบจำลองแทน
export 'face_scan_screen_web.dart' if (dart.library.io) 'face_scan_screen.dart';
