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
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.visPassword ? _obscureText : false,
      keyboardType:
          widget.keyboardType ??
          (widget.validationType == 'email'
              ? TextInputType.emailAddress
              : TextInputType.text),
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
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: const Color.fromARGB(255, 249, 245, 237),
      ),
    );
  }
}
