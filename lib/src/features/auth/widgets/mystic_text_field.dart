import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class MysticTextField extends StatelessWidget {
  const MysticTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? errorText;
  final bool obscureText;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: label,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            enableSuggestions: enableSuggestions,
            autocorrect: false,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppColors.secondaryLavender.withValues(alpha: 0.52),
                fontSize: 14,
              ),
              errorText: errorText,
              errorMaxLines: 2,
              errorStyle: GoogleFonts.inter(
                color: AppColors.primaryPink,
                fontSize: 11,
                height: 1.3,
              ),
              filled: true,
              fillColor: AppColors.glassBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: suffixIcon,
              border: _border(AppColors.glassBorder),
              enabledBorder: _border(AppColors.glassBorder),
              focusedBorder: _border(
                AppColors.primaryPink.withValues(alpha: 0.78),
              ),
              errorBorder: _border(
                AppColors.primaryPink.withValues(alpha: 0.68),
              ),
              focusedErrorBorder: _border(AppColors.primaryPink),
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }
}
