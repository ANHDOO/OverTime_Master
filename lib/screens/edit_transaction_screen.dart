import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/overtime_provider.dart';
import '../models/cash_transaction.dart';
import '../widgets/smart_money_input.dart';

class EditTransactionScreen extends StatefulWidget {
  final CashTransaction transaction;
  
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late String _selectedProject;
  late String _paymentType;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _type = widget.transaction.type;
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(0));
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _selectedDate = widget.transaction.date;
    _selectedProject = widget.transaction.project;
    _paymentType = widget.transaction.paymentType;
    _imagePath = widget.transaction.imagePath;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _takePicture() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      await _saveImage(image);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      await _saveImage(image);
    }
  }

  Future<void> _saveImage(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
    final savedPath = path.join(directory.path, fileName);
    await File(image.path).copy(savedPath);
    setState(() => _imagePath = savedPath);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa ảnh', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    // Remove both commas and dots before parsing
    final cleanAmount = _amountController.text.replaceAll(',', '').replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung')),
      );
      return;
    }

    final updatedTransaction = widget.transaction.copyWith(
      type: _type,
      amount: amount,
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      imagePath: _imagePath,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      project: _selectedProject,
      paymentType: _paymentType,
    );

    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    await provider.updateCashTransaction(updatedTransaction);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OvertimeProvider>(context);
    
    // Get unique projects from existing transactions
    final existingProjects = provider.cashTransactions
        .map((t) => t.project)
        .toSet()
        .toList()
      ..sort();
    if (!existingProjects.contains('Mặc định')) {
      existingProjects.insert(0, 'Mặc định');
    }
    
    // Ensure selected project is in the list to avoid DropdownButton error
    if (!existingProjects.contains(_selectedProject)) {
      existingProjects.add(_selectedProject);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project Selection
            _buildSectionTitle('Dự án / Quỹ'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: existingProjects.contains(_selectedProject) ? _selectedProject : 'Mặc định',
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  ...existingProjects.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                  const DropdownMenuItem(
                    value: '__new__',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Thêm dự án mới...', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) async {
                  if (value == '__new__') {
                    final newProject = await _showAddProjectDialog();
                    if (newProject != null && newProject.isNotEmpty) {
                      setState(() => _selectedProject = newProject);
                    }
                  } else if (value != null) {
                    setState(() => _selectedProject = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Transaction Type
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton('Thu vào', Icons.arrow_downward, Colors.green, TransactionType.income),
                  ),
                  Expanded(
                    child: _buildTypeButton('Chi ra', Icons.arrow_upward, Colors.red, TransactionType.expense),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount
            _buildSectionTitle('Số tiền'),
            const SizedBox(height: 8),
            SmartMoneyInput(
              controller: _amountController,
              textColor: _type == TransactionType.income ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),

            // Date
            _buildSectionTitle('Ngày giao dịch'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            _buildSectionTitle('Nội dung'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Mô tả giao dịch',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Type
            _buildSectionTitle('Hình thức thanh toán'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Hoá đơn giấy', style: TextStyle(fontSize: 14)),
                    value: _paymentType == 'Hoá đơn giấy',
                    onChanged: (val) {
                      if (val == true) setState(() => _paymentType = 'Hoá đơn giấy');
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Chụp hình CK', style: TextStyle(fontSize: 14)),
                    value: _paymentType == 'Chụp hình chuyển khoản',
                    onChanged: (val) {
                      if (val == true) setState(() => _paymentType = 'Chụp hình chuyển khoản');
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Note
            _buildSectionTitle('Ghi chú thêm (tùy chọn)'),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ghi chú thêm về giao dịch...',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Image
            _buildSectionTitle('Hình ảnh chứng từ'),
            const SizedBox(height: 8),
            if (_imagePath != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_imagePath!), height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagePath = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _showImageOptions, icon: const Icon(Icons.edit), label: const Text('Thay đổi ảnh')),
            ] else
              InkWell(
                onTap: _showImageOptions,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Thêm ảnh', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),

            // Save Button
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, IconData icon, Color color, TransactionType type) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: isSelected ? color : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Future<String?> _showAddProjectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm dự án mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tên dự án...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              final provider = Provider.of<OvertimeProvider>(context, listen: false);
              provider.deleteCashTransaction(widget.transaction.id!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
