import 'package:flutter/material.dart';

class CurvyImageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String imageUrl;
  final double height;
  final Widget icon;

  const CurvyImageAppBar({
    super.key,
    required this.imageUrl,
    this.height = 245,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: ClipPath(
        clipper: CurvyClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            /// Background Image
            Image.asset(imageUrl, fit: BoxFit.cover),

            /// Dark Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: icon,
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}

/// WAVE / CURLY SHAPE
class CurvyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height - 55);

    /// First curve
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height,
      size.width * 0.5,
      size.height - 40,
    );

    /// Second curve
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height - 80,
      size.width,
      size.height - 40,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
