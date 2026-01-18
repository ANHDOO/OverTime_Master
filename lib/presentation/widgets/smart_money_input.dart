import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../core/theme/app_theme.dart';

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
  int _lastInputLength = 0;
  int? _lastBase;
  double _lastLargest = 0;

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
    
    // 1. Parse base early and decide prevLargest behavior (reset when input shrinks)
    final cleanInput = text;
    final currentLen = cleanInput.length;
    final base = int.tryParse(cleanInput) ?? 0;
    // detect appended char when user types
    String? appendedChar;
    if (currentLen > _lastInputLength && cleanInput.isNotEmpty) {
      appendedChar = cleanInput.substring(cleanInput.length - 1);
    }

    double prevLargest = 0;
    bool allowEscalation = true;
    // If user deleted characters or reduced the base, reset prevLargest to allow smaller suggestions again
    if (currentLen < _lastInputLength || (base > 0 && _lastBase != null && base < _lastBase!)) {
      prevLargest = 0;
      // on deletion or when base decreased, do not escalate automatically
      allowEscalation = false;
    } else {
      prevLargest = _lastLargest;
      // Only allow escalation when user appended a zero or no previous largest (initial)
      if (appendedChar != null && appendedChar != '0') {
        allowEscalation = false;
      }
    }

    // Update suggestions first to ensure UI is ready
    List<double> newSuggestions = [];
    if (text.isNotEmpty && text.length <= 6) {
      newSuggestions = _generateSuggestions(text, prevLargest, allowEscalation);
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
      // Use standard decimal pattern for the locale (Vietnamese uses . as thousand separator)
      final formatted = NumberFormat.decimalPattern('vi_VN').format(number);
      
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

    // update last trackers
    _lastInputLength = currentLen;
    _lastBase = base == 0 ? null : base;
    _lastLargest = (_suggestions.isNotEmpty ? _suggestions.last : 0.0);
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

  List<double> _generateSuggestions(String input, [double prevLargest = 0, bool allowEscalation = true]) {
    final cleanInput = input.replaceAll(',', '').replaceAll('.', '');
    final base = int.tryParse(cleanInput);
    if (base == null || base == 0) return [];

    // Determine number of digits
    final digits = base.toString().length;

    int exp;
    if (digits == 1) {
      exp = 4; // e.g. 5 -> 50.000
    } else if (digits == 2) {
      exp = 3; // e.g. 18 -> 18.000
    } else if (digits == 3) {
      exp = 3; // keep same behavior for 3-digit base (180->180.000)
    } else {
      exp = 1; // for >=4 digits, shift minimally (5236 -> 52.360)
    }

    final suggestions = <double>[];
    // Generate suggestions and ensure they do not decrease compared to previous largest
    // If escalation is not allowed, produce a single set based on current exp.
    if (allowEscalation) {
      for (;;) {
        suggestions.clear();
        for (int i = 0; i < 3; i++) {
          final val = base * pow(10, exp + i);
          suggestions.add(val.toDouble());
        }
        suggestions.sort();
        if (prevLargest <= 0 || suggestions.last > prevLargest) {
          break;
        }
        exp += 1;
        // guard
        if (exp > 12) break;
      }
    } else {
      // single generation without escalating exp
      // If user appended non-zero digit, shift one step lower for the first suggestion
      int startExp = exp;
      if (startExp > 0) startExp = exp - 1;
      for (int i = 0; i < 3; i++) {
        final val = base * pow(10, startExp + i);
        suggestions.add(val.toDouble());
      }
    }

    // Ensure unique and sorted ascending
    final unique = suggestions.toSet().toList()..sort();
    return unique;
  }

  String _formatCurrencyLabel(double number) {
    try {
      return '${NumberFormat.decimalPattern('vi_VN').format(number)} đ';
    } catch (_) {
      return '${number.toStringAsFixed(0)} đ';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Limit suggestions to top 3 highest values for display
    final displaySuggestions = (_suggestions.toList()..sort((a, b) => a.compareTo(b))).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: widget.style ?? TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: widget.textColor ?? Colors.black,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: '0',
            suffixText: '₫',
          ),
        ),

        // Suggestions shown BELOW the TextField as pill buttons
        const SizedBox(height: 8),
        SizedBox(
          height: 48, // Fixed height to prevent dialog jump
          child: displaySuggestions.isEmpty 
            ? const SizedBox() // Empty space buffer
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: displaySuggestions.map((value) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _selectSuggestion(value),
                        child: Text(
                          _formatCurrencyLabel(value),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
        ),
      ],
    );
  }
}
