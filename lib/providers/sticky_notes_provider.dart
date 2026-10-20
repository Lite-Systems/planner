import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/services/database_helper.dart';
import '../models/sticky_note.dart';

/// Loads, edits and stores the sticky notes pinned on the dashboard.
class StickyNotesProvider with ChangeNotifier {
  List<StickyNote> _notes = [];
  bool _isLoaded = false;

  List<StickyNote> get notes => _notes;
  bool get isLoaded => _isLoaded;

  Future<void> loadData() async {
    try {
      _notes = await DatabaseHelper.instance.getStickyNotes();
      _isLoaded = true;
    } catch (e) {
      log('StickyNotesProvider loadData error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _insert(StickyNote note) async {
    try {
      await DatabaseHelper.instance.insertStickyNote(note);
      _notes.insert(0, note);
      notifyListeners();
    } catch (e) {
      log('StickyNotesProvider add error: $e');
    }
  }

  Future<void> _update(StickyNote note) async {
    try {
      await DatabaseHelper.instance.updateStickyNote(note);
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        if (index > 0) {
          _notes.removeAt(index);
          _notes.insert(0, note);
        } else {
          _notes[index] = note;
        }
      }
      notifyListeners();
    } catch (e) {
      log('StickyNotesProvider update error: $e');
    }
  }

  /// Saves the note: creates it when [StickyNote.id] is empty, otherwise
  /// updates the existing record.
  Future<void> save(StickyNote note) async {
    if (note.id.isEmpty) {
      await _insert(
        StickyNote(
          id: const Uuid().v4(),
          content: note.content,
          colorIndex: note.colorIndex,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await _update(
        note.copyWith(updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> delete(String id) async {
    try {
      await DatabaseHelper.instance.deleteStickyNote(id);
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      log('StickyNotesProvider delete error: $e');
    }
  }
}
