import 'package:flutter/material.dart';

class CustomTextFormField extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final String? validationType;
  final bool visPassword;
  final bool showVisPasswordToggle;
  final int min;
  final int max;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const CustomTextFormField({
    super.key,
    required this.hintText,
    required this.controller,
    this.validationType,
    this.visPassword = false,
    this.showVisPasswordToggle = false,
    this.min = 1,
    this.max = 100,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final fontSize = isDesktop
        ? 14.0
        : isTablet
        ? 15.0
        : 16.0;
    return Container(
      height: isDesktop ? 60 : null,
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.visPassword ? _obscureText : false,
        keyboardType:
            widget.keyboardType ??
            (widget.validationType == 'email'
                ? TextInputType.emailAddress
                : TextInputType.text),
        style: TextStyle(
          fontSize: fontSize, // نفس حجم الخط للـ hintStyle
          height: 1.2, // يقلل من ارتفاع السطر ويصغر cursor
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'حقل ${widget.hintText} مطلوب';
          }

          if (value.length < widget.min) {
            return '${widget.hintText} يجب أن يكون على الأقل ${widget.min} حروف';
          }

          if (value.length > widget.max) {
            return '${widget.hintText} يجب أن يكون أقل من ${widget.max} حروف';
          }

          if (widget.validationType == 'email') {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'الرجاء إدخال بريد إلكتروني صالح';
            }
          }

          if (widget.validationType == 'password') {
            if (value.length < 8) {
              return 'كلمة المرور يجب أن تكون 8 حروف على الأقل';
            }
            if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
              return 'كلمة المرور يجب أن تحتوي على حرف كبير، حرف صغير، ورقم واحد على الأقل';
            }
          }

          return null;
        },

        decoration: InputDecoration(
          hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade500),
          errorStyle: TextStyle(fontSize: fontSize * 0.9, color: Colors.red),

          hintText: widget.hintText,

          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.showVisPasswordToggle
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : widget.suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: isDesktop
              ? EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isDesktop ? 12 : 8,
                )
              : EdgeInsets.symmetric(horizontal: 16, vertical: 14),

          filled: true,
          fillColor: const Color.fromARGB(255, 249, 245, 237),
        ),
      ),
    );
  }
}
