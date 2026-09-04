import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cloud_models.dart';
import '../../services/sync_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final cloudAccountProvider = StateProvider<CloudAccount?>((ref) {
  final authUser = ref.watch(currentUserProvider);
  if (authUser != null && !authUser.isGuest) {
    return CloudAccount(
      userId: authUser.id,
      email: authUser.email,
      displayName: authUser.name,
      createdAt: authUser.createdAt,
      syncEnabled: true,
      backupEnabled: true,
    );
  }
  return null;
});

class CloudAccountScreen extends ConsumerStatefulWidget {
  const CloudAccountScreen({super.key});

  @override
  ConsumerState<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends ConsumerState<CloudAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authControllerProvider.notifier).login(email, password);
      if (success) {
        // Start initial sync
        await ref.read(syncServiceProvider).syncNow();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign In Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('You have pending offline changes. Signing out will stop sync, but local data will remain. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sign Out Anyway', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).logout();
      ref.read(cloudAccountProvider.notifier).state = null;
      ref.read(globalSyncStatusProvider.notifier).state = SyncStatus.offline;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(cloudAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Account')),
      body: account == null ? _buildSignIn() : _buildAccount(account),
    );
  }

  Widget _buildSignIn() {
    final authState = ref.watch(authControllerProvider);
    final displayedError = authState.errorMessage;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_sync, size: 64),
          const SizedBox(height: 16),
          const Text('Enable Cloud Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Keep your Timora data safely backed up and synced across all your devices with Supabase Cloud.', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          if (displayedError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayedError,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: (_isLoading || authState.isLoading) ? null : _handleSignIn,
              child: (_isLoading || authState.isLoading)
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign In to Supabase'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAccount(CloudAccount account) {
    final status = ref.watch(globalSyncStatusProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(account.displayName),
          subtitle: Text(account.email),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Cloud Sync Enabled'),
          subtitle: const Text('Upload and download changes automatically to Supabase'),
          value: account.syncEnabled,
          onChanged: (val) {
            final updated = account.copyWith(syncEnabled: val);
            ref.read(cloudAccountProvider.notifier).state = updated;
            if (val) {
              ref.read(syncServiceProvider).syncNow();
            }
          },
        ),
        ListTile(
          title: const Text('Last Synced'),
          subtitle: Text(
            status == SyncStatus.syncing 
              ? 'Syncing...' 
              : (status == SyncStatus.offline ? 'Offline' : 'Just now')
          ),
          trailing: OutlinedButton.icon(
            onPressed: status == SyncStatus.syncing ? null : () => ref.read(syncServiceProvider).syncNow(),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Now'),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          onTap: _handleSignOut,
        )
      ],
    );
  }
}

