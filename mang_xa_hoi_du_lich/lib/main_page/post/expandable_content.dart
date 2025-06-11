import 'package:flutter/material.dart';

class ExpandableContent extends StatefulWidget {
  final String content;
  final String postId;
  final Map<String, bool> expandedContent;
  final Function(String, bool) onExpandChanged;

  const ExpandableContent({
    Key? key,
    required this.content,
    required this.postId,
    required this.expandedContent,
    required this.onExpandChanged,
  }) : super(key: key);

  @override
  _ExpandableContentState createState() => _ExpandableContentState();
}

class _ExpandableContentState extends State<ExpandableContent> {
  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.expandedContent[widget.postId] ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Create a TextPainter to measure the text
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.content,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        // Check if the text is truncated (exceeds maxLines)
        final isTextTruncated = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.content,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              maxLines: isExpanded ? null : 5,
              overflow:
                  isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isTextTruncated)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onExpandChanged(widget.postId, !isExpanded);
                  },
                  child: Text(
                    isExpanded ? 'Ẩn bớt' : 'Xem tiếp',
                    style: const TextStyle(
                      color: Color(0xFF63AB83),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
