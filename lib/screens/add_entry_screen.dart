import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../widgets/custom_time_picker.dart';
import '../models/overtime_entry.dart';
import '../models/ot_template.dart';

class AddEntryScreen extends StatefulWidget {
  final DateTime? selectedMonth;
  final OvertimeEntry? editEntry;   // For editing existing entry
  final OvertimeEntry? copyFrom;    // For copying time from another entry
  
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
    // Handle overnight (e.g., 22:00 - 00:30)
    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60;
    }
    return (endMinutes - startMinutes) / 60;
  }
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late DateTime _selectedDate;
  
  // Mode: 0 = specific times, 1 = input hours, 2 = multiple slots
  int _inputMode = 0;
  
  // Single time mode
  TimeOfDay _startTime = const TimeOfDay(hour: 17, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  
  // Hours mode
  double _selectedHours = 4.0;
  final List<double> _hourOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  
  // Multiple slots mode
  List<TimeSlot> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    
    // Handle edit mode - load existing entry data
    if (widget.editEntry != null) {
      final entry = widget.editEntry!;
      _selectedDate = entry.date;
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      return;
    }
    
    // Handle copy mode - copy time, but date is today (user picks new date)
    if (widget.copyFrom != null) {
      final entry = widget.copyFrom!;
      _startTime = entry.startTime;
      _endTime = entry.endTime;
      _selectedDate = DateTime.now();
      return;
    }
    
    // Default: new entry
    final now = DateTime.now();
    if (widget.selectedMonth != null) {
      final selectedMonth = widget.selectedMonth!;
      // Nếu đang trong tháng hiện tại, chọn ngày hiện tại
      // Nếu là tháng quá khứ, chọn ngày 1
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '⚡ Chọn Template',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...OTTemplate.defaults.map((template) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(template.icon, color: template.color, size: 22),
              ),
              title: Text(template.name),
              subtitle: Text('${template.timeRangeString} (${template.hours}h)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                setState(() {
                  _startTime = template.startTime;
                  _endTime = template.endTime;
                  _inputMode = 0; // Switch to specific time mode
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã áp dụng: ${template.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  double _getTotalHours() {
    if (_inputMode == 0) {
      // Single time mode
      int startMinutes = _startTime.hour * 60 + _startTime.minute;
      int endMinutes = _endTime.hour * 60 + _endTime.minute;
      if (endMinutes <= startMinutes) {
        endMinutes += 24 * 60;
      }
      return (endMinutes - startMinutes) / 60;
    } else if (_inputMode == 1) {
      // Hours mode
      return _selectedHours;
    } else {
      // Multiple slots mode
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
        // Auto-switch to hours mode if Sunday
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
      // Calculate end time based on total hours from first slot start
      final totalMinutes = _timeSlots.first.startTime.hour * 60 + 
                           _timeSlots.first.startTime.minute + 
                           (_getTotalHours() * 60).toInt();
      return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
    }
    return _endTime;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OvertimeProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isSunday = _selectedDate.weekday == DateTime.sunday;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editEntry != null ? 'Chỉnh sửa OT' :
          widget.copyFrom != null ? 'Sao chép OT' : 'Thêm tăng ca'
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
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
              Icons.calendar_today,
              () => _selectDate(context),
              badge: isSunday ? 'x2.0' : null,
            ),
            const SizedBox(height: 20),
            
            // Mode toggle - 3 options
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeButton('Giờ cụ thể', _inputMode == 0, () {
                      setState(() => _inputMode = 0);
                    }),
                  ),
                  Expanded(
                    child: _buildModeButton('Nhập số giờ', _inputMode == 1, () {
                      setState(() => _inputMode = 1);
                    }),
                  ),
                  Expanded(
                    child: _buildModeButton('Nhiều ca', _inputMode == 2, () {
                      setState(() {
                        _inputMode = 2;
                        if (_timeSlots.isEmpty) {
                          _timeSlots.add(TimeSlot(
                            startTime: const TimeOfDay(hour: 9, minute: 30),
                            endTime: const TimeOfDay(hour: 15, minute: 0),
                          ));
                        }
                      });
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Input based on mode
            if (_inputMode == 0) ...[
              // Single time selection
              Row(
                children: [
                  Expanded(
                    child: _buildPickerTile(
                      context,
                      'Bắt đầu',
                      _startTime.format(context),
                      Icons.access_time,
                      () => _selectStartTime(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPickerTile(
                      context,
                      'Kết thúc',
                      _endTime.format(context),
                      Icons.access_time_filled,
                      () => _selectEndTime(context),
                    ),
                  ),
                ],
              ),
            ] else if (_inputMode == 1) ...[
              // Hours selection
              _buildSectionTitle('Số giờ làm việc'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _hourOptions.map((hours) {
                  final isSelected = _selectedHours == hours;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedHours = hours),
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${hours.toInt()}h',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              // Multiple slots
              _buildSectionTitle('Các ca làm việc'),
              const SizedBox(height: 12),
              ..._timeSlots.asMap().entries.map((entry) {
                final index = entry.key;
                final slot = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectSlotTime(index, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              slot.startTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectSlotTime(index, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              slot.endTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${slot.getHours().toStringAsFixed(1)}h',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (_timeSlots.length > 1)
                        GestureDetector(
                          onTap: () => _removeTimeSlot(index),
                          child: Icon(Icons.remove_circle, color: Colors.red.shade400, size: 24),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addTimeSlot,
                icon: const Icon(Icons.add),
                label: const Text('Thêm ca làm việc'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            _buildCalculationPreview(context, provider, currencyFormat),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await provider.addEntry(
                  date: _selectedDate,
                  startTime: _getEffectiveStartTime(),
                  endTime: _getEffectiveEndTime(),
                );
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Lưu bản ghi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildCalculationPreview(BuildContext context, OvertimeProvider provider, NumberFormat format) {
    final isSunday = _selectedDate.weekday == DateTime.sunday;
    final hours = _getTotalHours();
    final rate = isSunday ? 2.0 : 1.5;
    final estimatedPay = provider.hourlyRate * hours * rate;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSunday 
              ? [Colors.red.shade400, Colors.red.shade600]
              : [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_inputMode == 2 ? 'Tổng giờ:' : 'Số giờ:', style: const TextStyle(color: Colors.white70)),
              Text('${hours.toStringAsFixed(1)}h', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hệ số:', style: TextStyle(color: Colors.white70)),
              Text('x$rate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lương/h:', style: TextStyle(color: Colors.white70)),
              Text(format.format(provider.hourlyRate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ước tính:', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text(format.format(estimatedPay), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 24)),
            ],
          ),
        ],
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
