import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/overtime_provider.dart';
import '../../services/update_service.dart';

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
    final images = await Provider.of<OvertimeProvider>(context, listen: false).getImagesSize();
    if (mounted) {
      setState(() {
        _cacheSize = cache;
        _imagesSize = images;
      });
    }
  }

  Future<void> _cleanup() async {
    await _updateService.clearUpdateCache();
    await Provider.of<OvertimeProvider>(context, listen: false).cleanupOrphanedImages();
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dọn dẹp bộ nhớ thành công')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật ứng dụng')),
      body: RefreshIndicator(
        onRefresh: () => _updateService.checkForUpdate(),
        child: AnimatedBuilder(
          animation: _updateService,
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
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    _buildStorageSection(),
                    const SizedBox(height: 24),
                    _buildFeaturesSection(),
                    const SizedBox(height: 24),
                    _buildStatusSection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final info = snapshot.data!;
        final lastCheck = _updateService.lastCheckTime != null
            ? DateFormat('HH:mm - dd/MM/yyyy').format(_updateService.lastCheckTime!)
            : 'Chưa kiểm tra';

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.1))),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.phonelink_setup, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phiên bản hiện tại',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'v${info.version} (Build ${info.buildNumber})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kiểm tra lần cuối:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(lastCheck, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageSection() {
    final totalSize = _cacheSize + _imagesSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quản lý bộ nhớ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildStorageItem('Bộ nhớ đệm cập nhật', _cacheSize, Icons.system_update_alt),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              _buildStorageItem('Ảnh chứng từ giao dịch', _imagesSize, Icons.image_outlined),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: totalSize > 0.1 ? _cleanup : null,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: Text(totalSize > 0.1 ? 'Dọn dẹp ngay (${totalSize.toStringAsFixed(1)} MB)' : 'Bộ nhớ đã sạch'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    backgroundColor: Colors.orange.shade50.withOpacity(totalSize > 0.1 ? 1 : 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nhật ký phiên bản hiện tại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: _updateService.currentChangelog != null && _updateService.currentChangelog!.isNotEmpty
              ? _buildChangelogContent(_updateService.currentChangelog!)
              : const Center(
                  child: Text(
                    'Kéo xuống để kiểm tra cập nhật',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildChangelogContent(String changelog) {
    // Parse changelog markdown-style content
    final lines = changelog.split('\n');
    final widgets = <Widget>[];
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      if (line.startsWith('# ')) {
        // Main title
        widgets.add(Text(
          line.substring(2),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
        ));
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        // Section header
        widgets.add(const SizedBox(height: 8));
        widgets.add(Text(
          line.substring(3),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ));
        widgets.add(const SizedBox(height: 4));
      } else if (line.startsWith('### ')) {
        // Sub-section with icon
        final iconMatch = RegExp(r'^### (.+?) (.+)$').firstMatch(line);
        if (iconMatch != null) {
          widgets.add(const SizedBox(height: 6));
          widgets.add(Text(
            iconMatch.group(0)!.substring(4),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
          ));
          widgets.add(const SizedBox(height: 2));
        }
      } else if (line.startsWith('- ')) {
        // Bullet point
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  line.substring(2).replaceAll('**', ''),
                  style: const TextStyle(fontSize: 12),
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

  Widget _buildFeatureItem(String title, String desc, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageItem(String label, double size, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          '${size.toStringAsFixed(1)} MB',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (_updateService.status == DownloadStatus.checking) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang kiểm tra cập nhật...'),
          ],
        ),
      );
    }

    if (_updateService.status == DownloadStatus.downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đang tải bản cập nhật...', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _updateService.progress,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiến độ: ${(_updateService.progress * 100).toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_updateService.updateInfo != null) ...[
            const SizedBox(height: 16),
            Text('Dung lượng: ${_updateService.updateInfo!.fileSize}', 
                 style: const TextStyle(fontSize: 12)),
          ]
        ],
      );
    }

    if (_updateService.status == DownloadStatus.readyToInstall) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bản cập nhật đã sẵn sàng để cài đặt!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (_updateService.status == DownloadStatus.error) {
      return Text(
        'Lỗi: ${_updateService.error}',
        style: const TextStyle(color: Colors.red),
      );
    }

    if (_updateService.hasUpdate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.new_releases, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Bản cập nhật mới: ${_updateService.updateInfo!.versionName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nhật ký thay đổi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _updateService.newChangelog ?? _updateService.updateInfo!.changelog,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                if (_updateService.updateInfo!.fileSize.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text('Dung lượng tải về: ${_updateService.updateInfo!.fileSize}', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ]
              ],
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text('Ứng dụng đã ở phiên bản mới nhất'),
    );
  }

  Widget _buildActionButtons() {
    if (_updateService.status == DownloadStatus.downloading) {
      return const SizedBox.shrink();
    }

    if (_updateService.status == DownloadStatus.readyToInstall) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _updateService.installUpdate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.install_mobile),
          label: const Text('Cài đặt ngay bây giờ', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    if (_updateService.hasUpdate) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _updateService.downloadInBackground(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.download),
          label: const Text('Tải về bản cập nhật', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _updateService.checkForUpdate(),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.refresh),
        label: const Text('Kiểm tra cập nhật', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
