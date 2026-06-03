import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class MysticRegisterTextField extends StatelessWidget {
  const MysticRegisterTextField({
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
    this.maxLength,
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
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.tertiaryGold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
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
            maxLength: maxLength,
            cursorColor: AppColors.tertiaryGold,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(
              color: AppColors.tertiaryGold,
              fontSize: 16,
            ),
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
              counterText: '',
              filled: true,
              fillColor: AppColors.onSurface.withValues(alpha: 0.035),
              contentPadding: const EdgeInsets.fromLTRB(4, 12, 4, 11),
              suffixIcon: suffixIcon,
              border: _underline(AppColors.glassBorder),
              enabledBorder: _underline(AppColors.glassBorder),
              focusedBorder: _underline(AppColors.tertiaryGold),
              errorBorder: _underline(
                AppColors.primaryPink.withValues(alpha: 0.72),
              ),
              focusedErrorBorder: _underline(AppColors.primaryPink),
            ),
          ),
        ),
        if (maxLength != null)
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                return Text(
                  '${value.text.length}/$maxLength',
                  style: GoogleFonts.inter(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  UnderlineInputBorder _underline(Color color) {
    return UnderlineInputBorder(borderSide: BorderSide(color: color));
  }
}
