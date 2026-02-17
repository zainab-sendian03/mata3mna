import 'package:flutter/material.dart';

/// A widget that displays text with "Read more" / "Read less" functionality
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final String readMoreText;
  final String readLessText;
  final TextStyle? linkStyle;
  final TextAlign textAlign;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.style,
    this.readMoreText = 'اقرأ المزيد',
    this.readLessText = 'اقرأ أقل',
    this.linkStyle,
    this.textAlign = TextAlign.start,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _showReadMore = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Use simple heuristic: if text is long or has multiple lines, show read more
    _showReadMore = widget.text.length > 100 ||
        widget.text.split('\n').length > widget.maxLines;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if text actually overflows using TextPainter
        if (!_showReadMore && constraints.maxWidth > 0 && constraints.maxWidth != double.infinity) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _showReadMore) return;
            
            final textPainter = TextPainter(
              text: TextSpan(
                text: widget.text,
                style: widget.style,
              ),
              maxLines: widget.maxLines,
              textDirection: TextDirection.rtl,
            );

            textPainter.layout(maxWidth: constraints.maxWidth);
            if (textPainter.didExceedMaxLines) {
              if (mounted) {
                setState(() {
                  _showReadMore = true;
                });
              }
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: Text(
                widget.text,
                key: _textKey,
                style: widget.style,
                maxLines: _isExpanded ? null : widget.maxLines,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                textAlign: widget.textAlign,
                softWrap: true,
              ),
            ),
            if (_showReadMore) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? widget.readLessText : widget.readMoreText,
                  style: widget.linkStyle ??
                      widget.style?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

