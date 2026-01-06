import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SmartMoneyInput extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final TextStyle? style;
  final ValueChanged<double>? onChanged;
  final Color? textColor;

  const SmartMoneyInput({
    super.key,
    required this.controller,
    this.label,
    this.style,
    this.onChanged,
    this.textColor,
  });

  @override
  State<SmartMoneyInput> createState() => _SmartMoneyInputState();
}

class _SmartMoneyInputState extends State<SmartMoneyInput> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) {
      _removeOverlay();
      return;
    }

    // Format input with commas while typing
    final number = double.tryParse(text);
    if (number != null) {
      final formatted = NumberFormat('#,###', 'vi_VN').format(number);
      if (widget.controller.text != formatted) {
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      if (widget.onChanged != null) {
        widget.onChanged!(number);
      }
    }

    // Show suggestions if input length is small (1-3 digits) to avoid spamming on large numbers
    if (text.length >= 1 && text.length <= 3) {
      _showOverlay(text);
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay(String input) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final suggestions = _generateSuggestions(input);
    if (suggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions.map((value) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        backgroundColor: Colors.teal.shade50,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(
                          _formatCompact(value),
                          style: TextStyle(
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          final formatted = NumberFormat('#,###', 'vi_VN').format(value);
                          widget.controller.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                          if (widget.onChanged != null) {
                            widget.onChanged!(value);
                          }
                          _removeOverlay();
                          // Keep focus to allow further editing if needed, or user can tap outside
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  List<double> _generateSuggestions(String input) {
    final cleanInput = input.replaceAll(',', '').replaceAll('.', '');
    final number = double.tryParse(cleanInput);
    if (number == null || number == 0) return [];

    final suggestions = <double>[];
    
    // Multipliers to cover all cases from 100k to Billions
    final multipliers = [1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000];
    
    for (var m in multipliers) {
      final val = number * m;
      if (val >= 100000) { // Only suggest 100k and above
        suggestions.add(val);
      }
    }

    // Sort and remove duplicates, limit to 6 suggestions to keep it "gọn"
    return suggestions.toSet().toList()..sort();
  }

  String _formatCompact(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1).replaceAll('.0', '')} Tỷ';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1).replaceAll('.0', '')} Tr';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        keyboardType: TextInputType.number,
        style: widget.style ?? TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: widget.textColor ?? Colors.black,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: '0',
          suffixText: '₫',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
