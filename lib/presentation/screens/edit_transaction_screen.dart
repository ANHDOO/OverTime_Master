import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../logic/providers/cash_transaction_provider.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/backup_service.dart';
import '../widgets/smart_money_input.dart';
import '../widgets/smart_image.dart';
import '../../core/theme/app_theme.dart';

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
  late int _taxRate;
  late bool _isVatCollected;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _type = widget.transaction.type;
    _amountController = TextEditingController(
      text: NumberFormat.decimalPattern('vi_VN').format(widget.transaction.amount.round())
    );
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _selectedDate = widget.transaction.date;
    _selectedProject = widget.transaction.project;
    _paymentType = widget.transaction.paymentType;
    _taxRate = widget.transaction.taxRate;
    _isVatCollected = widget.transaction.isVatCollected;
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
    // Mở crop trước khi lưu
    final croppedFile = await _cropImage(image.path);
    if (croppedFile == null) return; // User cancelled crop
    
    final directory = await getApplicationDocumentsDirectory();
    String savedPath;
    
    // Nếu đã có ảnh cũ, giữ nguyên tên file để Drive ghi đè
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      savedPath = _imagePath!;
      // Xóa file cũ trước khi ghi đè
      try {
        final oldFile = File(savedPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting old image: $e');
      }
    } else {
      // File mới hoàn toàn
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      savedPath = path.join(directory.path, fileName);
    }
    
    // Copy file đã crop vào vị trí mới
    await File(croppedFile.path).copy(savedPath);
    debugPrint('Saved image to: $savedPath (same name for Drive override)');
    
    setState(() => _imagePath = savedPath);
  }

  /// Crop ảnh trước khi lưu
  Future<CroppedFile?> _cropImage(String sourcePath) async {
    return await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt ảnh chứng từ',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Cắt ảnh chứng từ',
          cancelButtonTitle: 'Hủy',
          doneButtonTitle: 'Xong',
        ),
      ],
    );
  }

  /// Cắt ảnh đang có trong thẻ
  Future<void> _cropExistingImage() async {
    if (_imagePath == null) return;
    
    final croppedFile = await _cropImage(_imagePath!);
    if (croppedFile == null) return; // User cancelled
    
    // Xóa file cũ và ghi đè bằng file đã crop
    try {
      final oldFile = File(_imagePath!);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      // Copy file đã crop vào vị trí cũ (cùng tên)
      await File(croppedFile.path).copy(_imagePath!);
      
      // Upload ảnh đã cắt lên Drive (nền)
      final backupService = BackupService();
      backupService.isSignedIn().then((isSignedIn) {
        if (isSignedIn) {
          backupService.backupImages([_imagePath!], projectName: _selectedProject);
          debugPrint('📤 Uploading cropped image to Drive: $_imagePath');
        }
      });
      
      // Buộc refresh UI
      setState(() {
        // Xóa cache image để load lại
        imageCache.clear();
        imageCache.clearLiveImages();
      });
      
      debugPrint('✅ Cropped existing image: $_imagePath');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cắt ảnh và đang đồng bộ lên Drive...')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error cropping existing image: $e');
    }
  }

  void _showImageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: AppRadius.borderFull,
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: AppRadius.borderMd),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: Text('Chụp ảnh', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: AppRadius.borderMd),
                child: Icon(Icons.photo_library_rounded, color: AppColors.info),
              ),
              title: Text('Chọn từ thư viện', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: AppRadius.borderMd),
                  child: Icon(Icons.crop_rounded, color: AppColors.warning),
                ),
                title: Text('Cắt ảnh hiện tại', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _cropExistingImage();
                },
              ),
            if (_imagePath != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: AppRadius.borderMd),
                  child: Icon(Icons.delete_rounded, color: AppColors.danger),
                ),
                title: Text('Xóa ảnh', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final cleanAmount = _amountController.text.replaceAll(',', '').replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [const Icon(Icons.error_outline_rounded, color: Colors.white), const SizedBox(width: 12), const Text('Vui lòng nhập số tiền hợp lệ')],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [const Icon(Icons.error_outline_rounded, color: Colors.white), const SizedBox(width: 12), const Text('Vui lòng nhập nội dung')],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
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
      taxRate: _taxRate,
      isVatCollected: _isVatCollected,
    );

    // Nếu đã đánh dấu lấy VAT, hủy nhắc nhở
    if (_isVatCollected && widget.transaction.id != null) {
      NotificationService().cancelVatReminder(widget.transaction.id!);
    }

    final provider = Provider.of<CashTransactionProvider>(context, listen: false);
    await provider.updateCashTransaction(updatedTransaction);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CashTransactionProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final existingProjects = provider.cashTransactions.map((t) => t.project).toSet().toList()..sort();
    if (!existingProjects.contains('Mặc định')) existingProjects.insert(0, 'Mặc định');
    if (!existingProjects.contains(_selectedProject)) existingProjects.add(_selectedProject);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa giao dịch'),
        actions: [
          IconButton(icon: Icon(Icons.delete_rounded, color: AppColors.danger), onPressed: () => _showDeleteDialog(isDark)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project Selection
            _buildSectionTitle('Dự án / Quỹ', isDark),
            const SizedBox(height: 10),
            _buildProjectSelector(existingProjects, isDark),
            const SizedBox(height: 24),

            // Transaction Type
            _buildTypeToggle(isDark),
            const SizedBox(height: 24),

            // Amount
            _buildSectionTitle('Số tiền', isDark),
            const SizedBox(height: 10),
            SmartMoneyInput(
              controller: _amountController,
              textColor: _type == TransactionType.income ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(height: 24),

            // Date
            _buildSectionTitle('Ngày giao dịch', isDark),
            const SizedBox(height: 10),
            _buildDatePicker(isDark),
            const SizedBox(height: 24),

            // Description
            _buildSectionTitle('Nội dung', isDark),
            const SizedBox(height: 10),
            _buildTextField(_descriptionController, 'Mô tả giao dịch', isDark, maxLines: 2),
            const SizedBox(height: 24),

            // Payment Type
            _buildSectionTitle('Hình thức thanh toán', isDark),
            const SizedBox(height: 10),
            _buildPaymentTypeSelector(isDark),
            const SizedBox(height: 24),

            // Tax Rate
            if (_type == TransactionType.expense) ...[
              _buildSectionTitle('Thuế suất (%)', isDark),
              const SizedBox(height: 10),
              _buildTaxRateSelector(isDark),
              const SizedBox(height: 16),
              // Checkbox đã lấy VAT (chỉ hiện khi có thuế)
              if (_taxRate > 0) _buildVatCollectedCheckbox(isDark),
              const SizedBox(height: 24),
            ],

            // Note
            _buildSectionTitle(_type == TransactionType.expense ? 'Nhà cung cấp (tùy chọn)' : 'Ghi chú thêm (tùy chọn)', isDark),
            const SizedBox(height: 10),
            _type == TransactionType.expense 
              ? _buildAutocompleteField(_noteController, 'Tên nhà cung cấp...', isDark, options: provider.cashTransactions.where((t) => t.note != null && t.note!.isNotEmpty).map((t) => t.note!).toSet().toList()..sort())
              : _buildTextField(_noteController, 'Ghi chú thêm về giao dịch...', isDark, maxLines: 3),
            const SizedBox(height: 24),

            // Image
            _buildSectionTitle('Hình ảnh chứng từ', isDark),
            const SizedBox(height: 10),
            _buildImageSection(isDark),
            const SizedBox(height: 32),

            // Save Button
            _buildSaveButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProjectSelector(List<String> projects, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: DropdownButton<String>(
        value: projects.contains(_selectedProject) ? _selectedProject : 'Mặc định',
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        items: [
          ...projects.map((p) => DropdownMenuItem(
            value: p,
            child: Text(p, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          )),
          DropdownMenuItem(
            value: '__new__',
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Thêm dự án mới...', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        onChanged: (value) async {
          if (value == '__new__') {
            final newProject = await _showAddProjectDialog(isDark);
            if (newProject != null && newProject.isNotEmpty) setState(() => _selectedProject = newProject);
          } else if (value != null) {
            setState(() => _selectedProject = value);
          }
        },
      ),
    );
  }

  Widget _buildTypeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: AppRadius.borderMd,
      ),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton('Thu vào', Icons.south_rounded, AppColors.success, TransactionType.income, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _buildTypeButton('Chi ra', Icons.north_rounded, AppColors.danger, TransactionType.expense, isDark)),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, IconData icon, Color color, TransactionType type, bool isDark) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: AppRadius.borderSm,
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm),
              child: Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  Widget _buildAutocompleteField(TextEditingController controller, String hint, bool isDark, {required List<String> options}) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return options.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Initialize textController with current value if empty
        if (textController.text.isEmpty && controller.text.isNotEmpty) {
          textController.text = controller.text;
        }

        return TextField(
          controller: textController,
          focusNode: focusNode,
          onChanged: (value) => controller.text = value,
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: AppRadius.borderMd,
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentTypeSelector(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildPaymentOption('Hoá đơn giấy', Icons.receipt_long_rounded, 'Hoá đơn giấy', isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildPaymentOption('Chụp CK', Icons.camera_alt_rounded, 'Chụp hình chuyển khoản', isDark)),
      ],
    );
  }

  Widget _buildPaymentOption(String label, IconData icon, String value, bool isDark) {
    final isSelected = _paymentType == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.1) : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
          ],
        ),
      ),
    );
  }

  Widget _buildVatCollectedCheckbox(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _isVatCollected = !_isVatCollected),
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isVatCollected 
            ? AppColors.success.withOpacity(isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: _isVatCollected ? AppColors.success : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _isVatCollected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _isVatCollected ? AppColors.success : Colors.transparent,
                borderRadius: AppRadius.borderSm,
                border: Border.all(
                  color: _isVatCollected ? AppColors.success : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  width: 2,
                ),
              ),
              child: _isVatCollected 
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã lấy hóa đơn VAT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _isVatCollected 
                        ? AppColors.success 
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isVatCollected 
                      ? 'Sẽ không nhắc lấy VAT nữa' 
                      : 'Nhấn để đánh dấu đã lấy hóa đơn',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_isVatCollected)
              Icon(Icons.receipt_long_rounded, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    if (_imagePath != null) {
      return Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.borderLg,
                child: SmartImage(
                  imagePath: _imagePath!,
                  transactionId: widget.transaction.id!,
                  projectName: _selectedProject,
                  height: 200,
                  onRestore: (newPath) {
                    setState(() {
                      _imagePath = newPath;
                    });
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imagePath = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _showImageOptions,
            icon: Icon(Icons.edit_rounded, color: AppColors.primary),
            label: Text('Thay đổi ảnh', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _showImageOptions,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, size: 32, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 8),
            Text('Thêm ảnh', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.heroBlue, borderRadius: AppRadius.borderMd, boxShadow: AppShadows.heroLight),
      child: ElevatedButton(
        onPressed: _saveTransaction,
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
            const Text('Lưu thay đổi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRateSelector(bool isDark) {
    return Row(
      children: [
        _buildTaxOption(0, isDark),
        const SizedBox(width: 12),
        _buildTaxOption(8, isDark),
        const SizedBox(width: 12),
        _buildTaxOption(10, isDark),
      ],
    );
  }

  Widget _buildTaxOption(int rate, bool isDark) {
    final isSelected = _taxRate == rate;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _taxRate = rate),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.1) : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(
              '$rate%',
              style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showAddProjectDialog(bool isDark) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Thêm dự án mới', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'Tên dự án...',
            hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Thêm', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xóa giao dịch?', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Bạn có chắc chắn muốn xóa giao dịch này không?', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(
            onPressed: () {
              final provider = Provider.of<CashTransactionProvider>(context, listen: false);
              provider.deleteCashTransaction(widget.transaction.id!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Xóa', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
