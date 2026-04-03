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
    this.obscureText = false,
    this.maxLines = 1,
    this.height = 48,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool obscureText;
  final int maxLines;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        readOnly: readOnly,
        obscureText: obscureText,
        maxLines: maxLines,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: prefixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
                  child: Icon(prefixIcon, size: 20),
                ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
