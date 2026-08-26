import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_models.dart';
import '../../services/ai_service.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    
    setState(() => _isLoading = true);
    // Auto-scroll
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    await ref.read(aiMessagesProvider.notifier).sendMessage(text);
    
    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiMessagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () => ref.read(aiMessagesProvider.notifier).clearHistory(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(messages[index], theme);
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  final List<String> _promptSuggestions = [
    'Plan my day',
    'Create a routine',
    'Break a goal into tasks',
    'Help me prioritize',
    'Reschedule my day',
    'Analyze my productivity',
    'Suggest a better schedule',
    'Create tomorrow\'s plan',
    'Create weekly plan',
    'Suggest breaks',
    'Ask anything about my routine',
  ];

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'TIMORA AI',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How can I help you today?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _promptSuggestions.map((label) {
                return _buildSuggestionChip(label, theme);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String label, ThemeData theme) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
      onPressed: () => _sendMessage(label),
    );
  }

  Widget _buildMessage(AIMessage msg, ThemeData theme) {
    final isUser = msg.role == AIMessageRole.user;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
              bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.content,
                style: TextStyle(color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
              ),
              if (msg.actionPayload != null) ...[
                const SizedBox(height: 16),
                _buildActionPreview(msg.actionPayload!, theme),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionPreview(AIActionPayload payload, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('AI Proposed Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('Confidence: ${payload.confidence}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Divider(),
          Text(payload.summary, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          ...payload.actions.map((a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('${a.type.name}: ${a.data['title']}', style: const TextStyle(fontSize: 12))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Actions Cancelled')));
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref.read(aiActionServiceProvider).applyActions(payload.actions);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan Applied!')));
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask Timora AI...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
              onPressed: () => _sendMessage(_controller.text),
            ),
          )
        ],
      ),
    );
  }
}
