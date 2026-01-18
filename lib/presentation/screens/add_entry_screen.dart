import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../logic/providers/overtime_provider.dart';
import '../widgets/custom_time_picker.dart';
import '../../data/models/overtime_entry.dart';
import '../../data/models/ot_template.dart';
import '../../core/theme/app_theme.dart';

class AddEntryScreen extends StatefulWidget {
  final DateTime? selectedMonth;
  final OvertimeEntry? editEntry;
  final OvertimeEntry? copyFrom;
  
  const AddEntryScreen({
    super.key, 
    this.selectedMonth,
    this.editEntry,
    this.copyFrom,
  });

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  
  TimeSlot({required this.startTime, required this.endTime});
  
  double getHours() {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60;
    }
    return (endMinutes - startMinutes) / 60;
  }
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late DateTime _selectedDate;
  int _inputMode = 0;
  
  TimeOfDay _startTime = const TimeOfDay(hour: 17, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  
  double _selectedHours = 4.0;
  final List<double> _hourOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  
  List<TimeSlot> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    
    if (widget.editEntry != null) {
      final entry = widget.editEntry!;
      _selectedDate = entry.date;
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      
      if (entry.shiftsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(entry.shiftsJson!);
          _timeSlots = decoded.map((s) => TimeSlot(
            startTime: TimeOfDay(hour: s['start_hour'], minute: s['start_minute']),
            endTime: TimeOfDay(hour: s['end_hour'], minute: s['end_minute']),
          )).toList();
          _inputMode = 2;
        } catch (e) {
          debugPrint('Error decoding shiftsJson: $e');
        }
      }
      return;
    }
    
    if (widget.copyFrom != null) {
      final entry = widget.copyFrom!;
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      _selectedDate = DateTime.now();
      return;
    }
    
    final now = DateTime.now();
    if (widget.selectedMonth != null) {
      final selectedMonth = widget.selectedMonth!;
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlots.add(TimeSlot(
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0),
      ));
    });
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots.removeAt(index);
    });
  }

  void _showTemplateSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: AppRadius.borderFull,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppGradients.heroBlue,
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chọn Template',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...OTTemplate.defaults.map((template) => ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: template.color.withOpacity(isDark ? 0.2 : 0.12),
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: Icon(template.icon, color: template.color, size: 22),
                        ),
                        title: Text(
                          template.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${template.timeRangeString} (${template.hours}h)',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        onTap: () {
                          setState(() {
                            _startTime = template.startTime;
                            _endTime = template.endTime;
                            _inputMode = 0;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text('Đã áp dụng: ${template.name}'),
                                ],
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                            ),
                          );
                        },
                      )),
                      const SizedBox(height: 24), // Bottom padding to avoid cut-off
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getTotalHours() {
    if (_inputMode == 0) {
      int startMinutes = _startTime.hour * 60 + _startTime.minute;
      int endMinutes = _endTime.hour * 60 + _endTime.minute;
      if (endMinutes <= startMinutes) {
        endMinutes += 24 * 60;
      }
      return (endMinutes - startMinutes) / 60;
    } else if (_inputMode == 1) {
      return _selectedHours;
    } else {
      return _timeSlots.fold(0.0, (sum, slot) => sum + slot.getHours());
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime firstDate;
    DateTime lastDate;
    
    if (widget.selectedMonth != null) {
      firstDate = DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month, 1);
      lastDate = DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month + 1, 0);
    } else {
      firstDate = DateTime(2020);
      lastDate = DateTime(2101);
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: widget.selectedMonth != null 
          ? 'Chọn ngày trong tháng ${DateFormat('MM/yyyy').format(widget.selectedMonth!)}'
          : null,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        if (_selectedDate.weekday == DateTime.sunday && _inputMode == 0) {
          _inputMode = 1;
          _selectedHours = 8.0;
        }
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await CustomTimePicker.show(
      context,
      initialTime: _startTime,
      title: 'Giờ bắt đầu',
      secondaryButtonText: 'Hủy',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await CustomTimePicker.show(
      context,
      initialTime: _endTime,
      title: 'Giờ kết thúc',
      secondaryButtonText: 'Hủy',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _selectSlotTime(int index, bool isStart) async {
    final slot = _timeSlots[index];
    final TimeOfDay? picked = await CustomTimePicker.show(
      context,
      initialTime: isStart ? slot.startTime : slot.endTime,
      title: isStart ? 'Giờ bắt đầu (Ca ${index + 1})' : 'Giờ kết thúc (Ca ${index + 1})',
      secondaryButtonText: 'Hủy',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _timeSlots[index].startTime = picked;
        } else {
          _timeSlots[index].endTime = picked;
        }
      });
    }
  }

  TimeOfDay _getEffectiveStartTime() {
    if (_inputMode == 1) {
      return const TimeOfDay(hour: 8, minute: 0);
    } else if (_inputMode == 2 && _timeSlots.isNotEmpty) {
      return _timeSlots.first.startTime;
    }
    return _startTime;
  }

  TimeOfDay _getEffectiveEndTime() {
    if (_inputMode == 1) {
      final totalMinutes = 8 * 60 + (_selectedHours * 60).toInt();
      return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
    } else if (_inputMode == 2 && _timeSlots.isNotEmpty) {
      return _timeSlots.last.endTime;
    }
    return _endTime;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OvertimeProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isSunday = _selectedDate.weekday == DateTime.sunday;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editEntry != null ? 'Chỉnh sửa OT' :
          widget.copyFrom != null ? 'Sao chép OT' : 'Thêm tăng ca'
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Template nhanh',
            onPressed: _showTemplateSelector,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPickerTile(
              context,
              'Ngày làm việc',
              DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
              Icons.calendar_today_rounded,
              () => _selectDate(context),
              badge: isSunday ? 'x2.0' : null,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            
            // Mode toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: AppRadius.borderMd,
              ),
              child: Row(
                children: [
                  Expanded(child: _buildModeButton('Giờ cụ thể', _inputMode == 0, isDark, () => setState(() => _inputMode = 0))),
                  Expanded(child: _buildModeButton('Nhập số giờ', _inputMode == 1, isDark, () => setState(() => _inputMode = 1))),
                  Expanded(
                    child: _buildModeButton('Nhiều ca', _inputMode == 2, isDark, () {
                      setState(() {
                        _inputMode = 2;
                        if (_timeSlots.isEmpty) {
                          _timeSlots.add(TimeSlot(
                            startTime: _startTime,
                            endTime: _endTime,
                          ));
                        }
                      });
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Input based on mode
            if (_inputMode == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPickerTile(
                      context,
                      'Bắt đầu',
                      _startTime.format(context),
                      Icons.schedule_rounded,
                      () => _selectStartTime(context),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPickerTile(
                      context,
                      'Kết thúc',
                      _endTime.format(context),
                      Icons.schedule_rounded,
                      () => _selectEndTime(context),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ] else if (_inputMode == 1) ...[
              _buildSectionTitle('Số giờ làm việc', isDark),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _hourOptions.map((hours) {
                  final isSelected = _selectedHours == hours;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedHours = hours),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppGradients.heroBlue : null,
                        color: isSelected ? null : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                        borderRadius: AppRadius.borderMd,
                        border: isSelected ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        boxShadow: isSelected ? AppShadows.buttonLight : null,
                      ),
                      child: Text(
                        '${hours.toInt()}h',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              _buildSectionTitle('Các ca làm việc', isDark),
              const SizedBox(height: 12),
              ..._timeSlots.asMap().entries.map((entry) {
                final index = entry.key;
                final slot = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppGradients.heroBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectSlotTime(index, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Text(
                              slot.startTime.format(context),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectSlotTime(index, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Text(
                              slot.endTime.format(context),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          '${slot.getHours().toStringAsFixed(1)}h',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_timeSlots.length > 1)
                        GestureDetector(
                          onTap: () => _removeTimeSlot(index),
                          child: Icon(Icons.remove_circle_rounded, color: AppColors.danger, size: 24),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addTimeSlot,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm ca làm việc'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                ),
              ),
            ],
            
            const SizedBox(height: 28),
            _buildCalculationPreview(context, provider, currencyFormat, isDark),
            const SizedBox(height: 32),
            _buildSaveButton(context, provider, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.heroBlue : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: AppRadius.borderSm,
          boxShadow: isSelected ? [
            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildCalculationPreview(BuildContext context, OvertimeProvider provider, NumberFormat format, bool isDark) {
    final isSunday = _selectedDate.weekday == DateTime.sunday;
    final hours = _getTotalHours();
    final rate = isSunday ? 2.0 : 1.5;
    final estimatedPay = provider.hourlyRate * hours * rate;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isSunday ? AppGradients.heroOrange : AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: isSunday ? AppShadows.heroOrangeLight : AppShadows.heroLight,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isSunday ? 'Làm Chủ Nhật' : 'Tính tiền OT',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        'x$rate',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Column(
                    children: [
                      _buildPreviewRow('Số giờ', '${hours.toStringAsFixed(1)}h'),
                      const SizedBox(height: 8),
                      _buildPreviewRow('Lương/h', format.format(provider.hourlyRate)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ƯỚC TÍNH',
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        format.format(estimatedPay),
                        style: TextStyle(
                          color: AppColors.successLight,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, OvertimeProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderMd,
        boxShadow: AppShadows.buttonLight,
      ),
      child: ElevatedButton(
        onPressed: () async {
          String? shiftsJson;
          if (_inputMode == 2 && _timeSlots.isNotEmpty) {
            shiftsJson = jsonEncode(_timeSlots.map((s) => {
              'start_hour': s.startTime.hour,
              'start_minute': s.startTime.minute,
              'end_hour': s.endTime.hour,
              'end_minute': s.endTime.minute,
            }).toList());
          }

          await provider.addEntry(
            date: _selectedDate,
            startTime: _getEffectiveStartTime(),
            endTime: _getEffectiveEndTime(),
            shiftsJson: shiftsJson,
            id: widget.editEntry?.id,
          );
          if (mounted) Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Lưu bản ghi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap, {
    String? badge,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          borderRadius: AppRadius.borderMd,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroOrange,
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ],
        ),
      ),
    );
  }
}
