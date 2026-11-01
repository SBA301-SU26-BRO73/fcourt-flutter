import 'dart:convert';

String? validateStaffName(String? value) =>
    value == null || value.trim().isEmpty || value.trim().length > 150
    ? 'Nhập họ tên, tối đa 150 ký tự'
    : null;

String? validateStaffEmail(String? value) =>
    value == null ||
        value.trim().length > 255 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Nhập email hợp lệ'
    : null;

String? validateStaffPhone(String? value) =>
    value == null || !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value.trim())
    ? 'Nhập SĐT từ 9–15 chữ số'
    : null;

String? validateStaffPassword(String? value) =>
    value == null ||
        value.length < 12 ||
        value.length > 72 ||
        utf8.encode(value).length > 72 ||
        !RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)
    ? 'Mật khẩu 12–72 byte, gồm chữ và số'
    : null;
