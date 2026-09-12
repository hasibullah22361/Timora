import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/models/admin_notification_model.dart';
import 'notification_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../profile/presentation/providers/user_profile_provider.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/providers/shared_prefs_provider.dart';

final adminNotificationsListProvider = StateNotifierProvider<
    AdminNotificationNotifier, List<AdminNotificationModel>>((ref) {
  final service = ref.watch(adminNotificationServiceProvider);
  return AdminNotificationNotifier(service);
});

class AdminNotificationNotifier
    extends StateNotifier<List<AdminNotificationModel>> {
  final AdminNotificationService _service;

  AdminNotificationNotifier(this._service) : super(_service.inMemoryList) {
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate(List<AdminNotificationModel> updated) {
    if (mounted) {
      state = updated;
    }
  }

  Future<void> syncNow() async {
    await _service.syncNotifications();
  }

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    if (mounted) {
      state = [...state];
    }
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    if (mounted) {
      state = [...state];
    }
  }

  Future<void> deleteNotification(String id) async {
    await _service.deleteNotification(id);
    if (mounted) {
      state = [...state];
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }
}

final adminNotificationServiceProvider =
    Provider<AdminNotificationService>((ref) {
  final service = AdminNotificationService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

typedef AdminNotificationListener = void Function(List<AdminNotificationModel>);

class AdminNotificationService {
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _connectivitySubscription;
  ProviderSubscription? _authSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isSubscribing = false;
  final List<AdminNotificationListener> _listeners = [];
  List<AdminNotificationModel> _inMemoryList = [];
  Set<String> _readIds = {};
  Set<String> _deliveredIds = {};
  Set<String> _deletedIds = {};

  static const String _keyDeliveredIds = 'timora_delivered_admin_notif_ids';
  static const String _keyReadIds = 'timora_read_admin_notif_ids';
  static const String _keyDeletedIds = 'timora_deleted_admin_notif_ids';
  static const String _keyCachedNotifications =
      'timora_cached_admin_notifications';

  AdminNotificationService(this._ref) {
    _init();
  }

  List<AdminNotificationModel> get inMemoryList =>
      List.unmodifiable(_inMemoryList);
  Set<String> get inMemoryReadIds => Set.unmodifiable(_readIds);
  int get unreadCount =>
      _inMemoryList.where((n) => !_readIds.contains(n.id)).length;

  void addListener(AdminNotificationListener listener) {
    _listeners.add(listener);
  }

  void removeListener(AdminNotificationListener listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final l in _listeners) {
      try {
        l(List.unmodifiable(_inMemoryList));
      } catch (_) {}
    }
  }

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    try {
      final p = _ref.read(sharedPreferencesProvider);
      return p;
    } catch (_) {
      return await SharedPreferences.getInstance();
    }
  }

  Future<void> _init() async {
    await _loadFromLocalCache();
    _listenToAuthChanges();
    _subscribeRealtime();
    _listenToConnectivity();
    // Fetch latest on startup
    syncNotifications();
  }

  void _listenToAuthChanges() {
    try {
      _authSubscription = _ref.listen<AuthState>(
        authControllerProvider,
        (previous, next) {
          final prevUser = previous?.user;
          final nextUser = next.user;
          if (prevUser?.id != nextUser?.id) {
            debugPrint(
                '[AdminNotif] Auth user changed: ${prevUser?.id} -> ${nextUser?.id}');
            if (nextUser != null) {
              _reconnectAttempts = 0;
              _subscribeRealtime();
              syncNotifications();
            } else {
              _unsubscribeRealtime();
              _inMemoryList.clear();
              _readIds.clear();
              _deliveredIds.clear();
              _notifyListeners();
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[AdminNotif] Auth listener notice: $e');
    }
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await _getPrefs();
      _readIds = (prefs.getStringList(_keyReadIds) ?? []).toSet();
      _deliveredIds = (prefs.getStringList(_keyDeliveredIds) ?? []).toSet();
      _deletedIds = (prefs.getStringList(_keyDeletedIds) ?? []).toSet();
      final jsonString = prefs.getString(_keyCachedNotifications);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> raw = jsonDecode(jsonString);
        _inMemoryList = raw
            .map((e) =>
                AdminNotificationModel.fromJson(e as Map<String, dynamic>))
            .where((n) => !_deletedIds.contains(n.id))
            .toList();
        _notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminNotif] Error loading cache: $e');
    }
  }

  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await _getPrefs();
      final list = _inMemoryList.map((n) => n.toJson()).toList();
      await prefs.setString(_keyCachedNotifications, jsonEncode(list));
    } catch (e) {
      debugPrint('[AdminNotif] Error saving cache: $e');
    }
  }

  void _listenToConnectivity() {
    try {
      final connectivity = _ref.read(connectivityServiceProvider);
      _connectivitySubscription = connectivity.statusStream.listen((status) {
        if (status == ConnectivityStatus.online) {
          debugPrint(
              '[AdminNotif] Network restored -> re-verifying realtime channel and syncing...');
          _reconnectAttempts = 0;
          _subscribeRealtime();
          syncNotifications();
        }
      });
    } catch (e) {
      debugPrint('[AdminNotif] Connectivity listener notice: $e');
    }
  }

  void _subscribeRealtime() {
    _unsubscribeRealtime();
    if (!_isSupabaseConfigured) return;
    if (_isSubscribing) return;
    _isSubscribing = true;

    try {
      final client = Supabase.instance.client;
      final userId = _getCurrentUserId();
      final channelName = userId != null && userId.isNotEmpty
          ? 'public:admin_notifications_$userId'
          : 'public:admin_notifications_live';

      _realtimeChannel = client.channel(channelName);
      _realtimeChannel!
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_notifications',
        callback: (payload) {
          final newRec = payload.newRecord;
          if (newRec.isNotEmpty) {
            try {
              final notif = AdminNotificationModel.fromJson(newRec);
              _handleIncomingNotification(notif);
            } catch (e) {
              debugPrint('[AdminNotif] Parse realtime notice: $e');
            }
          }
        },
      )
          .subscribe((status, [error]) {
        _isSubscribing = false;
        debugPrint(
            '[AdminNotif] Realtime status for $channelName: $status ${error != null ? "($error)" : ""}');
        if (status == RealtimeSubscribeStatus.subscribed) {
          _reconnectAttempts = 0;
          syncNotifications();
        } else if (status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError) {
          _scheduleReconnect();
        }
      });
      debugPrint(
          '[AdminNotif] Subscribed to app_notifications realtime channel: $channelName');
    } catch (e) {
      _isSubscribing = false;
      debugPrint('[AdminNotif] Realtime subscription notice: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 3).clamp(3, 30);
    debugPrint(
        '[AdminNotif] Scheduling realtime reconnect in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isSupabaseConfigured) {
        _subscribeRealtime();
      }
    });
  }

  void _unsubscribeRealtime() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isSubscribing = false;
    if (_realtimeChannel != null && _isSupabaseConfigured) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
  }

  String? _getCurrentUserId() {
    try {
      final user = _ref.read(currentUserProvider);
      if (user != null && user.id.isNotEmpty) return user.id;
    } catch (_) {}
    if (_isSupabaseConfigured) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) return user.id;
      } catch (_) {}
    }
    try {
      final profile = _ref.read(userProfileProvider);
      if (profile.id.isNotEmpty) return profile.id;
    } catch (_) {}
    return null;
  }

  String? _getCurrentUserEmail() {
    try {
      final user = _ref.read(currentUserProvider);
      if (user != null && user.email.isNotEmpty) return user.email;
    } catch (_) {}
    if (_isSupabaseConfigured) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && user.email != null) return user.email;
      } catch (_) {}
    }
    try {
      final profile = _ref.read(userProfileProvider);
      if (profile.email.isNotEmpty) return profile.email;
    } catch (_) {}
    return null;
  }

  Future<void> syncNotifications() async {
    if (!_isSupabaseConfigured) return;

    try {
      final client = Supabase.instance.client;
      final userId = _getCurrentUserId();
      final userEmail = _getCurrentUserEmail();

      final List<dynamic> response = await client
          .from('app_notifications')
          .select()
          .eq('status', 'sent')
          .order('created_at', ascending: false)
          .limit(30);

      final fetched = response
          .map((data) =>
              AdminNotificationModel.fromJson(data as Map<String, dynamic>))
          .where((notif) =>
              notif.isEligibleForUser(userId, userEmail) &&
              !_deletedIds.contains(notif.id))
          .toList();

      for (final notif in fetched) {
        await _handleIncomingNotification(notif);
      }
    } catch (e) {
      debugPrint('[AdminNotif] Sync notice: $e');
    }
  }

  Future<void> _handleIncomingNotification(AdminNotificationModel notif) async {
    if (_deletedIds.contains(notif.id)) return;
    final userId = _getCurrentUserId();
    final userEmail = _getCurrentUserEmail();
    if (!notif.isEligibleForUser(userId, userEmail)) return;

    final deliveredIds = await getDeliveredIds();
    final isNew = !deliveredIds.contains(notif.id);

    // Update in-memory cache
    final index = _inMemoryList.indexWhere((n) => n.id == notif.id);
    if (index >= 0) {
      _inMemoryList[index] = notif;
    } else {
      _inMemoryList.insert(0, notif);
      // Keep up to 50
      if (_inMemoryList.length > 50) {
        _inMemoryList = _inMemoryList.sublist(0, 50);
      }
    }
    await _saveToLocalCache();
    _notifyListeners();

    if (isNew) {
      await _deliverToDevice(notif);
    }
  }

  Future<void> _deliverToDevice(AdminNotificationModel notif) async {
    try {
      _deliveredIds.add(notif.id);
      final prefs = await _getPrefs();
      await prefs.setStringList(_keyDeliveredIds, _deliveredIds.toList());

      // 1. Post native system notification with default sound (TTS is never used for admin alerts)
      final notifService = _ref.read(notificationServiceProvider);
      final int notifId = notif.id.hashCode.abs() % 100000;
      final payloadData = jsonEncode({
        'type': 'admin_notification',
        'id': notif.id,
        'deepLink': notif.deepLink,
      });

      await notifService.showImmediateNotification(
        notifId,
        notif.title,
        notif.message,
        channelId: 'timora_admin',
        payload: payloadData,
        playSound: true,
        enableVibration: true,
      );
    } catch (e) {
      debugPrint('[AdminNotif] Delivery error: $e');
    }
  }

  Future<Set<String>> getDeliveredIds() async {
    if (_deliveredIds.isNotEmpty) return Set.from(_deliveredIds);
    try {
      final prefs = await _getPrefs();
      _deliveredIds = (prefs.getStringList(_keyDeliveredIds) ?? []).toSet();
      return Set.from(_deliveredIds);
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> getReadIds() async {
    if (_readIds.isNotEmpty) return Set.from(_readIds);
    try {
      final prefs = await _getPrefs();
      _readIds = (prefs.getStringList(_keyReadIds) ?? []).toSet();
      return Set.from(_readIds);
    } catch (_) {
      return {};
    }
  }

  Future<void> markAsRead(String notifId) async {
    try {
      _readIds.add(notifId);
      final prefs = await _getPrefs();
      await prefs.setStringList(_keyReadIds, _readIds.toList());
      _notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      for (final n in _inMemoryList) {
        _readIds.add(n.id);
      }
      final prefs = await _getPrefs();
      await prefs.setStringList(_keyReadIds, _readIds.toList());
      _notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNotification(String notifId) async {
    try {
      _deletedIds.add(notifId);
      final prefs = await _getPrefs();
      await prefs.setStringList(_keyDeletedIds, _deletedIds.toList());
      _inMemoryList.removeWhere((n) => n.id == notifId);
      await _saveToLocalCache();
      _notifyListeners();
    } catch (_) {}
  }

  Future<List<AdminNotificationModel>> getCachedNotifications() async {
    return List.unmodifiable(_inMemoryList);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _authSubscription?.close();
    _unsubscribeRealtime();
    _connectivitySubscription?.cancel();
    _listeners.clear();
  }
}
