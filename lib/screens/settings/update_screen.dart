import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String _status = '';

  Future<void> _checkForUpdate() async {
    setState(() => _status = 'Đang kiểm tra...');
    final updateService = UpdateService();
    final result = await updateService.checkForUpdate();
    if (!mounted) return;
    if (result.hasUpdate && result.updateInfo != null) {
      final shouldUpdate = await updateService.showUpdateDialog(context, result.updateInfo!);
      if (shouldUpdate == true && mounted) {
        await updateService.downloadAndInstall(result.updateInfo!.downloadUrl, context);
      }
      setState(() => _status = 'Có bản cập nhật: ${result.updateInfo!.versionName}');
    } else if (result.error != null) {
      setState(() => _status = 'Lỗi: ${result.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${result.error}'), backgroundColor: Colors.red));
      }
    } else {
      setState(() => _status = 'Bạn đang sử dụng phiên bản mới nhất');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đang sử dụng phiên bản mới nhất!'), backgroundColor: Colors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật ứng dụng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final info = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phiên bản hiện tại: ${info.version} (Build ${info.buildNumber})'),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            ElevatedButton.icon(
              onPressed: _checkForUpdate,
              icon: const Icon(Icons.system_update),
              label: const Text('Kiểm tra cập nhật'),
            ),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ),
      ),
    );
  }
}


