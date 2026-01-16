import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonTap;

  const CustomTimePicker({
    super.key,
    required this.initialTime,
    this.title = 'Chọn thời gian',
    this.secondaryButtonText,
    this.onSecondaryButtonTap,
  });

  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initialTime,
    String title = 'Chọn thời gian',
    String? secondaryButtonText,
    VoidCallback? onSecondaryButtonTap,
  }) async {
    return await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => CustomTimePicker(
        initialTime: initialTime,
        title: title,
        secondaryButtonText: secondaryButtonText,
        onSecondaryButtonTap: onSecondaryButtonTap,
      ),
    );
  }

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            
            // Labels above pickers
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text('Giờ', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Phút', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Wheel Pickers
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Selection Highlight (Two separate boxes, centered)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Pickers
                  Row(
                    children: [
                      // Hour Picker
                      Expanded(
                        child: CupertinoPicker.builder(
                          scrollController: FixedExtentScrollController(initialItem: _selectedHour),
                          itemExtent: 52,
                          magnification: 1.1,
                          useMagnifier: true,
                          selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(background: Colors.transparent),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedHour = index % 24);
                          },
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              (index % 24).toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          childCount: null, // Infinite looping
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker.builder(
                          scrollController: FixedExtentScrollController(initialItem: _selectedMinute),
                          itemExtent: 52,
                          magnification: 1.1,
                          useMagnifier: true,
                          selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(background: Colors.transparent),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedMinute = index % 60);
                          },
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              (index % 60).toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          childCount: null, // Infinite looping
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                if (widget.secondaryButtonText != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton(
                        onPressed: widget.onSecondaryButtonTap ?? () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface.withOpacity(0.05),
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(widget.secondaryButtonText!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, TimeOfDay(hour: _selectedHour, minute: _selectedMinute));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
