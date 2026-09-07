import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/career_document_model.dart';
import '../../data/repositories/career_document_repository.dart';

class CareerDocumentVaultScreen extends ConsumerStatefulWidget {
  const CareerDocumentVaultScreen({super.key});

  @override
  ConsumerState<CareerDocumentVaultScreen> createState() => _CareerDocumentVaultScreenState();
}

class _CareerDocumentVaultScreenState extends ConsumerState<CareerDocumentVaultScreen> {
  String _selectedType = 'All';
  String _searchQuery = '';

  final _docTypes = [
    'All',
    'CV',
    'Resume',
    'Cover Letter',
    'Certificate',
    'Transcript',
    'Recommendation Letter',
    'Research Paper',
    'Portfolio',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(allCareerDocumentsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Career Document Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Add Document', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _pickAndAddDocument(context),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search career documents...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: isDark ? const Color(0xFF131B2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              onChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
            ),
          ),

          // Document Type Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: _docTypes.map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = type);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Document List
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                var filtered = docs;
                if (_selectedType != 'All') {
                  filtered = filtered.where((d) => d.documentType == _selectedType).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((d) =>
                      d.fileName.toLowerCase().contains(_searchQuery) ||
                      d.description.toLowerCase().contains(_searchQuery) ||
                      d.tags.any((t) => t.toLowerCase().contains(_searchQuery))).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 14),
                          Text(
                            'No documents in this category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Add Document" to store your CV, credentials, or papers securely in Supabase cloud.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return _buildDocumentCard(context, doc, isDark);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading documents: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, CareerDocumentModel doc, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getDocColor(doc.documentType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDocIcon(doc.documentType),
              color: _getDocColor(doc.documentType),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.fileName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${doc.version}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDocColor(doc.documentType).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.documentType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getDocColor(doc.documentType),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(doc.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (doc.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    doc.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            onSelected: (val) async {
              if (val == 'open') {
                showDialog(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(doc.fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${doc.documentType}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Version: ${doc.version}'),
                        const SizedBox(height: 6),
                        Text('Uploaded: ${DateFormat.yMMMd().format(doc.uploadedAt)}'),
                        if (doc.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Notes: ${doc.description}', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        if (doc.fileUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Secure Cloud Path:\n${doc.fileUrl}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Close')),
                    ],
                  ),
                );
              } else if (val == 'delete') {
                await ref.read(careerDocumentRepositoryProvider).deleteDocument(doc.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted "${doc.fileName}"')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'open', child: Text('Open / View')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getDocIcon(String type) {
    switch (type) {
      case 'CV':
      case 'Resume':
        return Icons.badge_outlined;
      case 'Certificate':
        return Icons.verified_outlined;
      case 'Transcript':
        return Icons.school_outlined;
      case 'Research Paper':
        return Icons.article_outlined;
      case 'Cover Letter':
        return Icons.mail_outline;
      case 'Portfolio':
        return Icons.work_outline;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getDocColor(String type) {
    switch (type) {
      case 'CV':
      case 'Resume':
        return const Color(0xFF3B82F6);
      case 'Certificate':
        return const Color(0xFF10B981);
      case 'Transcript':
        return const Color(0xFF8B5CF6);
      case 'Research Paper':
        return const Color(0xFFF59E0B);
      case 'Cover Letter':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF0D9488);
    }
  }

  String _inferDocType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('resume')) return 'Resume';
    if (lower.contains('cv')) return 'CV';
    if (lower.contains('cover')) return 'Cover Letter';
    if (lower.contains('cert')) return 'Certificate';
    if (lower.contains('transcript')) return 'Transcript';
    if (lower.contains('recommend')) return 'Recommendation Letter';
    if (lower.contains('paper') || lower.contains('research')) return 'Research Paper';
    if (lower.contains('portfolio')) return 'Portfolio';
    return 'Other';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickAndAddDocument(BuildContext context) async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
      );

      if (files.isEmpty) return;
      final file = files.first;

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read file data. Please select another file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate size (max 25 MB)
      const maxSizeBytes = 25 * 1024 * 1024;
      if (bytes.length > maxSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File exceeds 25 MB limit (${_formatBytes(bytes.length)}). Please select a smaller file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate extension
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
      const allowedExts = ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'];
      if (ext.isNotEmpty && !allowedExts.contains(ext)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unsupported format ".$ext". Allowed: PDF, DOC, DOCX, TXT, PNG, JPG.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      _showUploadConfirmationDialog(context, file.name, bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadConfirmationDialog(BuildContext context, String initialFileName, Uint8List fileBytes) {
    final nameCtrl = TextEditingController(text: initialFileName);
    final descCtrl = TextEditingController();
    String docType = _inferDocType(initialFileName);
    bool isUploading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Add Career Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (!isUploading)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              initialFileName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Size: ${_formatBytes(fileBytes.length)} • Ready for secure vault',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'File / Document Name',
                    hintText: 'e.g. Senior_AI_Engineer_Resume.pdf',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: _docTypes
                      .where((t) => t != 'All')
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: isUploading ? null : (val) {
                    if (val != null) setSheetState(() => docType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'e.g. Tailored for Deep Learning roles',
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isUploading
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            setSheetState(() {
                              isUploading = true;
                              errorMessage = null;
                            });

                            try {
                              final doc = CareerDocumentModel(
                                fileName: name,
                                documentType: docType,
                                fileUrl: '',
                                fileSize: fileBytes.length,
                                description: descCtrl.text.trim(),
                              );

                              await ref.read(careerDocumentRepositoryProvider).saveDocument(
                                    doc,
                                    fileBytes: fileBytes,
                                  );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✨ "$name" added to Career Document Vault!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() {
                                isUploading = false;
                                errorMessage = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                    child: isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save to Secure Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
