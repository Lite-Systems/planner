import 'package:flutter/cupertino.dart';

/// A single sticky note pinned on the home dashboard.
///
/// Persisted locally in the `sticky_notes` table; [colorIndex] points into
/// [StickyNotePalette.colors] so the paper color survives a rebuild or theme
/// change without storing raw colors.
class StickyNote {
  final String id;
  final String content;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  StickyNote({
    required this.id,
    required this.content,
    this.colorIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'content': content,
    'colorIndex': colorIndex,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StickyNote.fromMap(Map<String, dynamic> map) => StickyNote(
    id: map['id'] as String,
    content: map['content'] as String? ?? '',
    colorIndex: (map['colorIndex'] as int?) ?? 0,
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
        DateTime.now(),
    updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
        DateTime.tryParse(map['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );

  StickyNote copyWith({
    String? id,
    String? content,
    int? colorIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StickyNote(
    id: id ?? this.id,
    content: content ?? this.content,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// The fixed paper colors a note can be pinned with.
///
/// Each entry pairs a paper fill with an ink color that stays readable on top
/// of it in both light and dark mode.
class StickyNotePalette {
  const StickyNotePalette({
    required this.base,
    required this.ink,
    required this.darkPaper,
    required this.darkInk,
  });

  final Color base;
  final Color ink;

  /// Softer, translucent paper used in dark mode.
  final Color darkPaper;
  final Color darkInk;

  static const colors = <StickyNotePalette>[
    StickyNotePalette(
      base: Color(0xFFFDE68A),
      ink: Color(0xFF713F12),
      darkPaper: Color(0xFF4D442A),
      darkInk: Color(0xFFFDE68A),
    ),
    StickyNotePalette(
      base: Color(0xFFFBCFE8),
      ink: Color(0xFF9D174D),
      darkPaper: Color(0xFF4E3345),
      darkInk: Color(0xFFFBCFE8),
    ),
    StickyNotePalette(
      base: Color(0xFFBBF7D0),
      ink: Color(0xFF14532D),
      darkPaper: Color(0xFF2F4437),
      darkInk: Color(0xFFBBF7D0),
    ),
    StickyNotePalette(
      base: Color(0xFFBFDBFE),
      ink: Color(0xFF1E3A8A),
      darkPaper: Color(0xFF2F3D4D),
      darkInk: Color(0xFFBFDBFE),
    ),
    StickyNotePalette(
      base: Color(0xFFDDD6FE),
      ink: Color(0xFF4C1D95),
      darkPaper: Color(0xFF3A3552),
      darkInk: Color(0xFFDDD6FE),
    ),
    StickyNotePalette(
      base: Color(0xFFFED7AA),
      ink: Color(0xFF7C2D12),
      darkPaper: Color(0xFF4E3B2C),
      darkInk: Color(0xFFFED7AA),
    ),
  ];
}
