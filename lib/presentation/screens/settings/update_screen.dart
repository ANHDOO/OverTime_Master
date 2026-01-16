import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/overtime_provider.dart';
import '../../../logic/providers/cash_transaction_provider.dart';
import '../../../data/services/update_service.dart';
import '../../../core/theme/app_theme.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final _updateService = UpdateService();
  double _cacheSize = 0;
  double _imagesSize = 0;

  @override
  void initState() {
    super.initState();
    _updateService.init();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    final cache = await _updateService.getUpdateCacheSize();
    final images = await Provider.of<CashTransactionProvider>(context, listen: false).getImagesSize();
    if (mounted) {
      setState(() {
        _cacheSize = cache;
        _imagesSize = images;
      });
    }
  }

  Future<void> _cleanup() async {
    await _updateService.clearUpdateCache();
    await Provider.of<CashTransactionProvider>(context, listen: false).cleanupOrphanedImages();
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Đã dọn dẹp bộ nhớ thành công'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật ứng dụng')),
      body: RefreshIndicator(
        onRefresh: () => _updateService.checkForUpdate(),
        color: AppColors.primary,
        child: ListenableBuilder(
          listenable: _updateService,
          builder: (context, _) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             AppBar().preferredSize.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(isDark),
                    const SizedBox(height: 20),
                    _buildStorageSection(isDark),
                    const SizedBox(height: 24),
                    _buildFeaturesSection(isDark),
                    const SizedBox(height: 24),
                    _buildStatusSection(isDark),
                    const SizedBox(height: 24),
                    _buildActionButtons(isDark),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final info = snapshot.data!;
        final lastCheck = _updateService.lastCheckTime != null
            ? DateFormat('HH:mm - dd/MM/yyyy').format(_updateService.lastCheckTime!)
            : 'Chưa kiểm tra';

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                AppColors.primaryDark.withOpacity(isDark ? 0.1 : 0.05),
              ],
            ),
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppGradients.heroBlue,
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: const Icon(Icons.phonelink_setup_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phiên bản hiện tại',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${info.version} (Build ${info.buildNumber})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 32, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kiểm tra lần cuối:',
                      style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13),
                    ),
                    Text(
                      lastCheck,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageSection(bool isDark) {
    final totalSize = _cacheSize + _imagesSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quản lý bộ nhớ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              _buildStorageItem('Bộ nhớ đệm cập nhật', _cacheSize, Icons.system_update_alt_rounded, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
              ),
              _buildStorageItem('Ảnh chứng từ giao dịch', _imagesSize, Icons.image_outlined, isDark),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: totalSize > 0.1 ? AppGradients.heroOrange : null,
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: totalSize > 0.1 ? _cleanup : null,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: Text(totalSize > 0.1 ? 'Dọn dẹp ngay (${totalSize.toStringAsFixed(1)} MB)' : 'Bộ nhớ đã sạch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: totalSize > 0.1 ? Colors.transparent : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                      foregroundColor: totalSize > 0.1 ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhật ký phiên bản hiện tại',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: _updateService.currentChangelog != null && _updateService.currentChangelog!.isNotEmpty
              ? _buildChangelogContent(_updateService.currentChangelog!, isDark)
              : Center(
                  child: Text(
                    'Kéo xuống để kiểm tra cập nhật',
                    style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildChangelogContent(String changelog, bool isDark) {
    final lines = changelog.split('\n');
    final widgets = <Widget>[];
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      if (line.startsWith('# ')) {
        widgets.add(Text(
          line.substring(2),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
        ));
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(Text(
          line.substring(3),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
      } else if (line.startsWith('### ')) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(Text(
          line.substring(4),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
        ));
        widgets.add(const SizedBox(height: 2));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              Expanded(
                child: Text(
                  line.substring(2).replaceAll('**', ''),
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildStorageItem(String label, double size, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, size: 18, color: AppColors.info),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            borderRadius: AppRadius.borderFull,
          ),
          child: Text(
            '${size.toStringAsFixed(1)} MB',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(bool isDark) {
    if (_updateService.status == DownloadStatus.checking) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Đang kiểm tra cập nhật...',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ],
        ),
      );
    }

    if (_updateService.status == DownloadStatus.downloading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Đang tải bản cập nhật...',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: AppRadius.borderFull,
              child: LinearProgressIndicator(
                value: _updateService.progress,
                minHeight: 8,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tiến độ: ${(_updateService.progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_updateService.status == DownloadStatus.readyToInstall) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success.withOpacity(isDark ? 0.15 : 0.1), AppColors.successDark.withOpacity(isDark ? 0.1 : 0.05)],
          ),
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: AppRadius.borderSm),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Bản cập nhật đã sẵn sàng để cài đặt!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (_updateService.status == DownloadStatus.error) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_rounded, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lỗi: ${_updateService.error}',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_updateService.hasUpdate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroBlue,
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Icon(Icons.new_releases_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bản cập nhật mới',
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                  Text(
                    _updateService.updateInfo!.versionName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhật ký thay đổi:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _updateService.newChangelog ?? _updateService.updateInfo!.changelog,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (_updateService.updateInfo!.fileSize.isNotEmpty) ...[
                  Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  Text(
                    'Dung lượng tải về: ${_updateService.updateInfo!.fileSize}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontStyle: FontStyle.italic),
                  ),
                ]
              ],
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            'Ứng dụng đã ở phiên bản mới nhất',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    if (_updateService.status == DownloadStatus.downloading) {
      return const SizedBox.shrink();
    }

    if (_updateService.status == DownloadStatus.readyToInstall) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppGradients.heroGreen,
          borderRadius: AppRadius.borderMd,
          boxShadow: AppShadows.heroGreenLight,
        ),
        child: ElevatedButton.icon(
          onPressed: () => _updateService.installUpdate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
          icon: const Icon(Icons.install_mobile_rounded, color: Colors.white),
          label: const Text('Cài đặt ngay bây giờ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      );
    }

    if (_updateService.hasUpdate) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppGradients.heroBlue,
          borderRadius: AppRadius.borderMd,
          boxShadow: AppShadows.heroLight,
        ),
        child: ElevatedButton.icon(
          onPressed: () => _updateService.downloadInBackground(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          label: const Text('Tải về bản cập nhật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _updateService.checkForUpdate(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Kiểm tra cập nhật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
