import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.readOnly = false,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

