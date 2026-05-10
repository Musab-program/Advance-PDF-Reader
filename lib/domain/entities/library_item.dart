// lib/domain/entities/library_item.dart

enum LibraryItemType { file, folder }

class LibraryItem {
  final String path;
  final String name;
  final LibraryItemType type;
  // For files only
  final int size;
  final String extension;

  final DateTime dateModified;

  LibraryItem({
    required this.path,
    required this.name,
    required this.type,
    this.size = 0,
    this.extension = '',
    required this.dateModified,
  });

  bool get isFolder => type == LibraryItemType.folder;
  bool get isFile => type == LibraryItemType.file;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'type': type == LibraryItemType.folder ? 'folder' : 'file',
        'size': size,
        'extension': extension,
        'dateModified': dateModified.toIso8601String(),
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        path: json['path'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] == 'folder'
            ? LibraryItemType.folder
            : LibraryItemType.file,
        size: json['size'] ?? 0,
        extension: json['extension'] ?? '',
        dateModified: json['dateModified'] != null
            ? DateTime.parse(json['dateModified'])
            : DateTime.now(),
      );
}
