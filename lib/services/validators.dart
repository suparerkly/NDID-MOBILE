/// ตรวจเลขบัตรประชาชน 13 หลักด้วยเลขตรวจสอบ (หลักที่ 13)
bool isValidThaiCitizenId(String id) {
  if (!RegExp(r'^\d{13}$').hasMatch(id)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(id[i]) * (13 - i);
  }
  return (11 - sum % 11) % 10 == int.parse(id[12]);
}

String? validateCitizenId(String? value) {
  final id = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (id.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
  if (id.length != 13) return 'เลขบัตรประชาชนต้องมี 13 หลัก';
  if (!isValidThaiCitizenId(id)) return 'เลขบัตรประชาชนไม่ถูกต้อง';
  return null;
}

String? validateThaiPhone(String? value) {
  final phone = (value ?? '').trim();
  if (phone.isEmpty) return 'กรุณากรอกเบอร์มือถือ';
  if (!RegExp(r'^0[689]\d{8}$').hasMatch(phone)) {
    return 'เบอร์มือถือต้องขึ้นต้นด้วย 06, 08 หรือ 09 และมี 10 หลัก';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'กรุณากรอกอีเมล';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'รูปแบบอีเมลไม่ถูกต้อง';
  }
  return null;
}

String? validateRequired(String? value, String label) {
  return (value ?? '').trim().isEmpty ? 'กรุณากรอก$label' : null;
}
