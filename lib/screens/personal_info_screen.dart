import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/validators.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'idp_select_screen.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const _titles = ['นาย', 'นาง', 'นางสาว'];

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _citizenId = TextEditingController();
  final _birthDateText = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String _title = _titles.first;
  DateTime? _birthDate;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _citizenId.dispose();
    _birthDateText.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'เลือกวันเกิด',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateText.text = formatThaiDate(picked);
    });
    if (_autovalidate != AutovalidateMode.disabled) {
      _formKey.currentState!.validate();
    }
  }

  /// กรอกข้อมูลสมมติ เลขบัตรขึ้นต้นด้วย 9 ซึ่งไม่ใช่รูปแบบที่ออกให้บุคคลจริงโดยทั่วไป
  void _fillSampleData() {
    final birthDate = DateTime(1990);
    setState(() {
      _title = _titles.first;
      _firstName.text = 'ตัวอย่าง';
      _lastName.text = 'ทดสอบ';
      _citizenId.text = '9000000000004';
      _birthDate = birthDate;
      _birthDateText.text = formatThaiDate(birthDate);
      _phone.text = '0900000000';
      _email.text = 'sample@example.com';
    });
    _formKey.currentState!.validate();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      // หลังกดส่งครั้งแรก ให้ error หายทันทีเมื่อแก้ข้อมูล
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final profile = UserProfile(
      title: _title,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      citizenId: _citizenId.text,
      birthDate: _birthDate!,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IdpSelectScreen(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          // ใช้ Column เพื่อให้ฟอร์มตรวจได้ครบทุกช่อง แม้ช่องนั้นเลื่อนพ้นจอ
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepHeader(current: 1, title: 'กรอกข้อมูลส่วนตัว'),
                const SizedBox(height: 16),
                const SimulationBanner(
                  text: 'แอปนี้เป็นการจำลอง กรุณาอย่ากรอกข้อมูลจริง '
                      'ใช้ข้อมูลตัวอย่างแทนได้',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    onPressed: _fillSampleData,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('กรอกข้อมูลตัวอย่าง'),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 1,
                  child: DropdownButtonFormField<String>(
                    value: _title,
                    borderRadius: BorderRadius.circular(appRadius),
                    dropdownColor: AppColors.surface,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    decoration: const InputDecoration(labelText: 'คำนำหน้า'),
                    items: [
                      for (final title in _titles)
                        DropdownMenuItem(value: title, child: Text(title)),
                    ],
                    onChanged: (value) => setState(() => _title = value!),
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 2,
                  child: TextFormField(
                    key: const Key('firstName'),
                    controller: _firstName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'ชื่อ'),
                    validator: (value) => validateRequired(value, 'ชื่อ'),
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 3,
                  child: TextFormField(
                    key: const Key('lastName'),
                    controller: _lastName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'นามสกุล'),
                    validator: (value) => validateRequired(value, 'นามสกุล'),
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 4,
                  child: TextFormField(
                    key: const Key('citizenId'),
                    controller: _citizenId,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'เลขบัตรประชาชน 13 หลัก',
                    ),
                    validator: validateCitizenId,
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 5,
                  child: TextFormField(
                    key: const Key('birthDate'),
                    controller: _birthDateText,
                    readOnly: true,
                    onTap: _pickBirthDate,
                    decoration: const InputDecoration(
                      labelText: 'วันเกิด',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                    validator: (_) =>
                        _birthDate == null ? 'กรุณาเลือกวันเกิด' : null,
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 6,
                  child: TextFormField(
                    key: const Key('phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(labelText: 'เบอร์มือถือ'),
                    validator: validateThaiPhone,
                  ),
                ),
                gap,
                FadeSlideIn(
                  index: 7,
                  child: TextFormField(
                    key: const Key('email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'อีเมล'),
                    validator: validateEmail,
                  ),
                ),
                const SizedBox(height: 24),
                FadeSlideIn(
                  index: 8,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('ถัดไป'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
