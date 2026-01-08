import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final _updateService = UpdateService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật ứng dụng')),
      body: AnimatedBuilder(
        animation: _updateService,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildStatusSection(),
                const Spacer(),
                _buildActionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final info = snapshot.data!;
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phiên bản hiện tại',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '${info.version} (Build ${info.buildNumber})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          Text(
            'Có bản cập nhật mới: ${_updateService.updateInfo!.versionName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            _updateService.updateInfo!.changelog,
            style: const TextStyle(fontSize: 14),
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
