import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/backup_service.dart';
import '../../logic/providers/cash_transaction_provider.dart';
import '../../core/theme/app_theme.dart';

class SmartImage extends StatefulWidget {
  final String imagePath;
  final int? transactionId;
  final String projectName;
  final double height;
  final double width;
  final BoxFit fit;
  final Function(String)? onRestore;

  const SmartImage({
    super.key,
    required this.imagePath,
    required this.transactionId,
    required this.projectName,
    this.height = 200,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.onRestore,
  });

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  bool _isRestoring = false;
  String? _currentPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _checkAndRestore();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      setState(() {
        _currentPath = widget.imagePath;
        _error = null;
      });
      _checkAndRestore();
    }
  }

  Future<void> _checkAndRestore() async {
    if (_currentPath == null) return;

    final file = File(_currentPath!);
    if (await file.exists()) {
      return;
    }

    // File không tồn tại, thử khôi phục từ Drive
    setState(() {
      _isRestoring = true;
      _error = null;
    });

    try {
      final backupService = BackupService();
      final newPath = await backupService.downloadImageIfMissing(
        _currentPath!,
        projectName: widget.projectName,
      );

      if (newPath != null) {
        // Xóa cache ảnh cũ nếu có để đảm bảo Flutter load lại file mới
        await FileImage(File(newPath)).evict();
        
        if (mounted) {
          setState(() {
            _currentPath = newPath;
            _isRestoring = false;
          });
          
          // Cập nhật đường dẫn mới vào database để lần sau không cần tải lại
          if (widget.transactionId != null) {
            final provider = Provider.of<CashTransactionProvider>(context, listen: false);
            await provider.updateTransactionImagePath(widget.transactionId!, newPath);
          }
          
          // Báo cho màn hình cha (nếu có)
          if (widget.onRestore != null) {
            widget.onRestore!(newPath);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isRestoring = false;
            _error = 'Không tìm thấy ảnh trên Drive';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _error = 'Lỗi khi khôi phục: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isRestoring) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: AppRadius.borderLg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              'Đang khôi phục từ Drive...',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: AppColors.danger, size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: _checkAndRestore,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_currentPath == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: AppRadius.borderLg,
      child: Image.file(
        File(_currentPath!),
        key: ValueKey(_currentPath), // Force reload if path changes
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ SmartImage error loading $_currentPath: $error');
          return Container(
            height: widget.height,
            width: widget.width,
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            child: const Center(child: Icon(Icons.error_outline)),
          );
        },
      ),
    );
  }
}
