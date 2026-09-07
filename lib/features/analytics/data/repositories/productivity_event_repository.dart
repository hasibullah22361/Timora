import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import '../models/productivity_event_model.dart';

final productivityEventRepositoryProvider = Provider<ProductivityEventRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProductivityEventRepository(prefs, ref);
});

class ProductivityEventRepository {
  static const String _storageKey = 'timora_productivity_events';
  final SharedPreferences _prefs;
  final Ref _ref;

  ProductivityEventRepository(this._prefs, this._ref);

  Future<List<ProductivityEventModel>> getAllEvents() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => ProductivityEventModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProductivityEventModel?> getEventById(String id) async {
    final events = await getAllEvents();
    return events.where((e) => e.id == id).firstOrNull;
  }

  Future<List<ProductivityEventModel>> getEvents({
    DateTimeRange? range,
    String? eventType,
  }) async {
    final all = await getAllEvents();
    return all.where((e) {
      if (eventType != null && e.eventType != eventType) return false;
      if (range != null) {
        if (e.timestamp.isBefore(range.start) || e.timestamp.isAfter(range.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> recordEvent(ProductivityEventModel event) async {
    final events = await getAllEvents();
    // Prepend or append event
    events.insert(0, event);

    // Keep max 2000 events locally to maintain snappy performance
    final trimmed = events.take(2000).toList();
    final jsonString = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);

    // Enqueue cloud sync
    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'productivity_events',
        entityId: event.id,
        operation: SyncOperation.create,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}
  }

  Future<void> savePulledEvent(ProductivityEventModel event) async {
    final events = await getAllEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.insert(0, event);
    }
    final trimmed = events.take(2000).toList();
    final jsonString = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<void> deleteEvent(String id) async {
    final events = await getAllEvents();
    events.removeWhere((e) => e.id == id);
    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'productivity_events',
        entityId: id,
        operation: SyncOperation.delete,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}
  }
}
