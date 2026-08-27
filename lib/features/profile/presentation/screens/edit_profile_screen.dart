import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/user_profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;

  late String _selectedAvatar;
  late Color _selectedAvatarColor;
  String? _customImagePath;
  late String _selectedTimezone;
  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;
  late double _dailyGoalHours;
  late int _dailyTaskGoal;
  late String _routinePreference;
  bool _isSaving = false;

  final List<String> _avatarPresets = [
    '⚡', '🚀', '💡', '🌱', '🔥', '🎯', '👨‍💻', '👩‍💻',
    '🧠', '🦁', '🦉', '⭐', '🏆', '💎', '🎨', '🏖️'
  ];

  final List<Color> _colorPresets = [
    const Color(0xFF2563EB), // Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Coral Red
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF0D9488), // Teal
    const Color(0xFF64748B), // Slate
  ];

  final List<String> _timezones = [
    'UTC+05:00 - Islamabad, Karachi',
    'UTC+00:00 - London, Dublin',
    'UTC+01:00 - Berlin, Paris, Rome',
    'UTC+02:00 - Cairo, Athens',
    'UTC+03:00 - Riyadh, Moscow, Istanbul',
    'UTC+04:00 - Dubai, Baku',
    'UTC+05:30 - New Delhi, Mumbai',
    'UTC+06:00 - Dhaka, Almaty',
    'UTC+07:00 - Bangkok, Jakarta',
    'UTC+08:00 - Singapore, Beijing, Perth',
    'UTC+09:00 - Tokyo, Seoul',
    'UTC+10:00 - Sydney, Melbourne',
    'UTC-05:00 - New York, Toronto',
    'UTC-06:00 - Chicago, Mexico City',
    'UTC-07:00 - Denver, Phoenix',
    'UTC-08:00 - Los Angeles, Vancouver',
  ];

  final List<String> _routineStyles = [
    'Time-blocking',
    'Flexible Flow',
    'Goal-driven',
    'Habit-based',
  ];

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider);
    _fullNameController = TextEditingController(text: p.fullName);
    _usernameController = TextEditingController(text: p.username);
    _emailController = TextEditingController(text: p.email);
    _bioController = TextEditingController(text: p.bio);

    _selectedAvatar = p.avatarPreset;
    _selectedAvatarColor = p.avatarColor;
    _customImagePath = p.customImagePath;
    _selectedTimezone = _timezones.contains(p.timezone) ? p.timezone : _timezones.first;
    _workStart = p.workHoursStart;
    _workEnd = p.workHoursEnd;
    _dailyGoalHours = p.dailyGoalHours;
    _dailyTaskGoal = p.dailyTaskGoal;
    _routinePreference = p.routinePreference;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 88,
      );

      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
        
        setState(() {
          _customImagePath = savedImage.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Change Profile Photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_customImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _customImagePath = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final current = ref.read(userProfileProvider);
    final updated = current.copyWith(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim().replaceAll('@', ''),
      email: _emailController.text.trim(),
      bio: _bioController.text.trim(),
      avatarPreset: _selectedAvatar,
      avatarColorValue: _selectedAvatarColor.toARGB32(),
      customImagePath: _customImagePath,
      clearCustomImage: _customImagePath == null,
      timezone: _selectedTimezone,
      workHoursStartMinutes: _workStart.hour * 60 + _workStart.minute,
      workHoursEndMinutes: _workEnd.hour * 60 + _workEnd.minute,
      dailyGoalHours: _dailyGoalHours,
      dailyTaskGoal: _dailyTaskGoal,
      routinePreference: _routinePreference,
    );

    await ref.read(userProfileProvider.notifier).updateProfile(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile changes saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustom = _customImagePath != null && File(_customImagePath!).existsSync();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // -------------------------------------------------------------
            // Profile Picture & Avatar Selector Card
            // -------------------------------------------------------------
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: _selectedAvatarColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: _selectedAvatarColor, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: hasCustom
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(48),
                                child: Image.file(
                                  File(_customImagePath!),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(_selectedAvatar, style: const TextStyle(fontSize: 48)),
                      ),
                      PositionedDirectional(
                        bottom: 0,
                        end: 0,
                        child: InkWell(
                          onTap: _showImageSourceDialog,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(hasCustom ? 'Change Photo' : 'Upload Photo'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      if (hasCustom) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Remove Photo',
                          onPressed: () => setState(() => _customImagePath = null),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Avatar Emoji preset selector (used when no custom image or as fallback)
            Text('Or Choose Emoji Avatar Preset', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _avatarPresets.map((emoji) {
                final isSel = !hasCustom && _selectedAvatar == emoji;
                return InkWell(
                  onTap: () => setState(() {
                    _selectedAvatar = emoji;
                    _customImagePath = null; // Switching to emoji preset
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSel ? _selectedAvatarColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? _selectedAvatarColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Avatar Color selector
            Row(
              children: _colorPresets.map((col) {
                final isSel = _selectedAvatarColor == col;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedAvatarColor = col),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSel
                            ? [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                            : null,
                      ),
                      child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // -------------------------------------------------------------
            // Personal Info Fields
            // -------------------------------------------------------------
            _buildSectionTitle(context, 'Basic Information'),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Full Name',
              hint: 'Your full name',
              controller: _fullNameController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Username',
                    hint: 'username',
                    prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    controller: _usernameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Username required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Email',
                    hint: 'email@example.com',
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Bio / Productivity Motto',
              hint: 'A short note about your goals and focus style',
              controller: _bioController,
              maxLines: 2,
            ),
            const SizedBox(height: 28),

            // -------------------------------------------------------------
            // Timezone & Working Hours
            // -------------------------------------------------------------
            _buildSectionTitle(context, 'Timezone & Schedule Preferences'),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timezone', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.8)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedTimezone,
                      items: _timezones.map((tz) {
                        return DropdownMenuItem(value: tz, child: Text(tz, style: const TextStyle(fontSize: 14)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTimezone = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker(
                    context,
                    'Work Start Time',
                    _workStart,
                    (t) => setState(() => _workStart = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePicker(
                    context,
                    'Work End Time',
                    _workEnd,
                    (t) => setState(() => _workEnd = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // -------------------------------------------------------------
            // Productivity Goals & Style
            // -------------------------------------------------------------
            _buildSectionTitle(context, 'Daily Productivity Goals'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily Focus Target', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${_dailyGoalHours.toStringAsFixed(1)} hours / day',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ],
            ),
            Slider(
              value: _dailyGoalHours,
              min: 1.0,
              max: 14.0,
              divisions: 26,
              label: '${_dailyGoalHours.toStringAsFixed(1)} hrs',
              onChanged: (val) => setState(() => _dailyGoalHours = val),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily Task Target', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _dailyTaskGoal > 1 ? () => setState(() => _dailyTaskGoal--) : null,
                    ),
                    Text('$_dailyTaskGoal tasks', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _dailyTaskGoal < 30 ? () => setState(() => _dailyTaskGoal++) : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Routine Style', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _routineStyles.map((style) {
                final isSel = _routinePreference == style;
                return ChoiceChip(
                  label: Text(style),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _routinePreference = style);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            // Save Button
            PrimaryButton(
              text: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) onChanged(t);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
