import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "تأكيد البريد الإلكتروني",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 100),
              const SizedBox(height: 20),
              Text("تم إرسال رابط التحقق إلى:", style: TextStyle(fontSize: 18)),
              Text(
                email,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: onResendVerification,
                child: const Text("إعادة إرسال رابط التحقق"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onCheckVerification,
                child: const Text("تم التحقق، متابعة"),
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
