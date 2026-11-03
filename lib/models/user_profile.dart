class UserProfile {
  const UserProfile({
    required this.title,
    required this.firstName,
    required this.lastName,
    required this.citizenId,
    required this.birthDate,
    required this.phone,
    required this.email,
  });

  final String title;
  final String firstName;
  final String lastName;
  final String citizenId;
  final DateTime birthDate;
  final String phone;
  final String email;

  String get fullName => '$title$firstName $lastName';

  /// เลขบัตรแบบปิดบังบางส่วน สำหรับแสดงบนหน้าจอ
  String get maskedCitizenId =>
      '${citizenId.substring(0, 1)}-XXXX-XXXXX-${citizenId.substring(10, 12)}-${citizenId.substring(12)}';

  Map<String, Object> toJson() => {
        'title': title,
        'firstName': firstName,
        'lastName': lastName,
        'citizenId': citizenId,
        'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-'
            '${birthDate.month.toString().padLeft(2, '0')}-'
            '${birthDate.day.toString().padLeft(2, '0')}',
        'phone': phone,
        'email': email,
      };

  int ageOn(DateTime date) {
    final hadBirthday = date.month > birthDate.month ||
        (date.month == birthDate.month && date.day >= birthDate.day);
    return date.year - birthDate.year - (hadBirthday ? 0 : 1);
  }
}
