import 'package:flutter/material.dart';

class ToolItem {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final bool isAvailable;
  final VoidCallback? action;

  const ToolItem({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    this.isAvailable = true,
    this.action,
  });
}
