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
  List<double> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 1. Update suggestions first to ensure UI is ready
    List<double> newSuggestions = [];
    if (text.isNotEmpty && text.length <= 3) {
      newSuggestions = _generateSuggestions(text);
    }
    
    if (_suggestions.toString() != newSuggestions.toString()) {
      setState(() => _suggestions = newSuggestions);
    }

    // 2. Handle empty case
    if (text.isEmpty) {
      if (widget.onChanged != null) {
        widget.onChanged!(0);
      }
      return;
    }

    // 3. Parse and Format
    final number = double.tryParse(text);
    if (number != null) {
      // Vietnamese format uses dot as thousand separator
      final formatted = NumberFormat('#,###', 'vi_VN').format(number);
      
      if (widget.controller.text != formatted) {
        widget.controller.removeListener(_onTextChanged);
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        widget.controller.addListener(_onTextChanged);
      }
      
      // 4. Notify parent to trigger calculations
      if (widget.onChanged != null) {
        widget.onChanged!(number);
      }
    }
  }

  void _selectSuggestion(double value) {
    final formatted = NumberFormat('#,###', 'vi_VN').format(value);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    if (widget.onChanged != null) {
      widget.onChanged!(value);
    }
    setState(() => _suggestions = []);
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

    // Sort and remove duplicates, limit to 6 suggestions
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Suggestions shown ABOVE the TextField
        if (_suggestions.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestions.map((value) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    backgroundColor: Colors.blue.shade100,
                    side: BorderSide(color: Colors.blue.shade300),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    label: Text(
                      _formatCompact(value),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => _selectSuggestion(value),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
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
      ],
    );
  }
}
