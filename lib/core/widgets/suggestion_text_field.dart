import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/suggestion_service.dart';

/// A reusable text field with an auto-complete suggestion dropdown.
/// Works with the centralized [SuggestionService] for all Timora forms.
class SuggestionTextField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final int maxSuggestions;
  final Set<SuggestionSource>? sources;
  final ValueChanged<String>? onSuggestionSelected;
  final FormFieldValidator<String>? validator;
  final int? maxLength;

  const SuggestionTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.maxSuggestions = 8,
    this.sources,
    this.onSuggestionSelected,
    this.validator,
    this.maxLength,
  });

  @override
  ConsumerState<SuggestionTextField> createState() => _SuggestionTextFieldState();
}

class _SuggestionTextFieldState extends ConsumerState<SuggestionTextField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<SuggestionItem> _suggestions = [];
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay removal to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isSelecting) {
          _removeOverlay();
        }
      });
    } else if (widget.controller.text.isNotEmpty) {
      _onTextChanged();
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _fetchSuggestions(widget.controller.text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      _removeOverlay();
      return;
    }

    try {
      final service = ref.read(suggestionServiceProvider);
      final results = await service.getSuggestions(
        query,
        limit: widget.maxSuggestions,
        sources: widget.sources,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
        });

        if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (_) {}
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: _getFieldWidth(),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, _getFieldHeight() + 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              shadowColor: Colors.black26,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return _SuggestionTile(
                        item: item,
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(SuggestionItem item) {
    _isSelecting = true;
    widget.controller.text = item.name;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: item.name.length),
    );
    _removeOverlay();
    widget.onSuggestionSelected?.call(item.name);
    Future.delayed(const Duration(milliseconds: 100), () {
      _isSelecting = false;
    });
  }

  double _getFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getFieldHeight() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 56;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLength: widget.maxLength,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final SuggestionItem item;
  final VoidCallback onTap;

  const _SuggestionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
