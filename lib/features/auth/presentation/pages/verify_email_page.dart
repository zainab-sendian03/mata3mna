import 'package:flutter/material.dart';
import 'package:mata3mna/config/themes/app_colors.dart';
import 'package:mata3mna/core/constants/customButton.dart';

class VerifyEmailScreen extends StatelessWidget {
  final String email;
  final VoidCallback onResendVerification;
  final VoidCallback onCheckVerification;
  final VoidCallback onLogout;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onResendVerification,
    required this.onCheckVerification,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "تأكيد البريد الإلكتروني",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 100),
              const SizedBox(height: 20),
              Text(
                "تم إرسال رابط التحقق إلى بريدك الإلكتروني:",
                style: TextStyle(fontSize: 18),
              ),
              Text(
                email,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                "يرجى تفقد صندوق الرسائل الواردة لديك لإتمام التحقق",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              CustomButton(
                onPressed: onResendVerification,
                theme: theme,
                label: "إعادة إرسال رابط التحقق",
                color: AppColors.primaryLight,
                icon: null,
              ),

              const SizedBox(height: 10),
              CustomButton(
                onPressed: onCheckVerification,
                theme: theme,
                label: "تم التحقق، متابعة",
                color: AppColors.primaryLight,
                icon: null,
                isOutline: true,
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: onLogout,
                child: const Text("تسجيل الخروج"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
