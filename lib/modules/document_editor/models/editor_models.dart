import 'dart:typed_data';
import 'package:flutter/material.dart';

enum EditorTab { none, annotate, fillSign, edit, convert }

enum AnnotateTool { select, pen, highlighter, underline, strikeout, eraser, rect, circle, line, arrow, stickyNote }

enum FillSignTool { signature, quickText, check, cross, dot, dateStamp }

enum EditTool { formattedText, whiteout }

enum StampType {
  signature,
  check,
  cross,
  dot,
  dateStamp,
  quickText,
  formattedTextBox,
  rectShape,
  circleShape,
  lineShape,
  arrowShape,
  whiteout,
  highlightRect,
  underlineRect,
  strikeoutRect,
}

class DrawnStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;
  final bool isEraser;
  final int pageIndex;
  final Size pageViewSize;

  const DrawnStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isHighlighter = false,
    this.isEraser = false,
    required this.pageIndex,
    this.pageViewSize = const Size(350, 500),
  });

  DrawnStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    bool? isHighlighter,
    bool? isEraser,
    int? pageIndex,
    Size? pageViewSize,
  }) {
    return DrawnStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isHighlighter: isHighlighter ?? this.isHighlighter,
      isEraser: isEraser ?? this.isEraser,
      pageIndex: pageIndex ?? this.pageIndex,
      pageViewSize: pageViewSize ?? this.pageViewSize,
    );
  }
}

class PlacedStamp {
  final String id;
  final StampType type;
  final int pageIndex;
  Offset position;
  Size size;
  String? text;
  Uint8List? imageBytes;
  List<List<Offset>>? rawSignatureLines;
  Color color;
  Color? backgroundColor;
  Color? borderColor;
  double fontSize;
  double strokeWidth;
  bool isBold;
  TextAlign alignment;
  Size pageViewSize;
  List<Rect>? lineRects;

  PlacedStamp({
    required this.id,
    required this.type,
    required this.pageIndex,
    required this.position,
    required this.size,
    this.text,
    this.imageBytes,
    this.rawSignatureLines,
    this.color = Colors.black,
    this.backgroundColor,
    this.borderColor,
    this.fontSize = 14,
    this.strokeWidth = 3.0,
    this.isBold = false,
    this.alignment = TextAlign.right,
    this.pageViewSize = const Size(350, 500),
    this.lineRects,
  });

  PlacedStamp copy() {
    return PlacedStamp(
      id: id,
      type: type,
      pageIndex: pageIndex,
      position: position,
      size: size,
      text: text,
      imageBytes: imageBytes,
      rawSignatureLines: rawSignatureLines?.map((line) => List<Offset>.from(line)).toList(),
      color: color,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      fontSize: fontSize,
      strokeWidth: strokeWidth,
      isBold: isBold,
      alignment: alignment,
      pageViewSize: pageViewSize,
      lineRects: lineRects != null ? List<Rect>.from(lineRects!) : null,
    );
  }
}

/// Atomic undo/redo record representing an eraser sweep that removed strokes and/or stamps.
class EraseAction {
  final List<DrawnStroke> erasedStrokes;
  final List<PlacedStamp> erasedStamps;

  const EraseAction({
    this.erasedStrokes = const [],
    this.erasedStamps = const [],
  });

  bool get isEmpty => erasedStrokes.isEmpty && erasedStamps.isEmpty;
}
