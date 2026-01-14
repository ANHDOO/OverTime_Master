import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/overtime_entry.dart';
import '../theme/app_theme.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'interest_calculator_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OT Master', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_rounded),
            tooltip: 'Tính lãi nợ lương',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InterestCalculatorScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<OvertimeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return Column(
            children: [
              _buildSummaryCard(context, provider, currencyFormat, isDark),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Gần đây',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text('${provider.entries.length} bản ghi', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.entries.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: provider.entries.length,
                        itemBuilder: (context, index) {
                          final entry = provider.entries[index];
                          return _buildEntryCard(context, provider, entry, currencyFormat, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.heroBlue,
          borderRadius: AppRadius.borderFull,
          boxShadow: AppShadows.heroLight,
        ),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEntryScreen())),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_rounded, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
          const SizedBox(height: 20),
          Text('Chưa có dữ liệu tăng ca', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Nhấn + để thêm bản ghi đầu tiên', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, OvertimeProvider provider, NumberFormat format, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroLight,
      ),
      child: Stack(
        children: [
          Positioned(top: -30, right: -30, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
          Positioned(bottom: -20, left: -20, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: AppRadius.borderSm),
                          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text('Tổng thu nhập tăng ca', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: AppRadius.borderFull),
                      child: Text(DateFormat('MM/yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(format.format(provider.totalMonthlyPay), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildMiniStat('Số buổi', provider.entries.length.toString(), Icons.event_note_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMiniStat('Lương/h', format.format(provider.hourlyRate), Icons.payments_rounded)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: AppRadius.borderMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: AppRadius.borderSm),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, OvertimeProvider provider, OvertimeEntry entry, NumberFormat format, bool isDark) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Dismissible(
      key: Key('entry_${entry.id}'),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.info, AppColors.infoDark]), borderRadius: AppRadius.borderLg),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          children: [Icon(Icons.edit_rounded, color: Colors.white, size: 24), SizedBox(width: 8), Text('Sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.dangerLight, AppColors.danger]), borderRadius: AppRadius.borderLg),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), SizedBox(width: 8), Icon(Icons.delete_rounded, color: Colors.white, size: 24)],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmDialog(context, isDark);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(editEntry: entry)));
          return false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final deletedEntry = entry;
          provider.deleteEntry(entry.id!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.delete_rounded, color: Colors.white), const SizedBox(width: 12), Text('Đã xóa OT ngày ${DateFormat('dd/MM').format(deletedEntry.date)}')]),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              action: SnackBarAction(label: 'Hoàn tác', textColor: Colors.white, onPressed: () => provider.addEntryObject(deletedEntry)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: borderColor.withOpacity(0.5)),
          boxShadow: isDark ? null : AppShadows.cardLight,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EntryDetailScreen(entry: entry))),
            onLongPress: () => _showEntryActionsSheet(context, provider, entry, isDark),
            borderRadius: AppRadius.borderLg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: entry.isSunday ? AppGradients.heroDanger : AppGradients.heroBlue,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('dd').format(entry.date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(DateFormat('MMM', 'vi').format(entry.date), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(entry.date),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            const SizedBox(width: 4),
                            Text('${entry.startTime.format(context)} - ${entry.endTime.format(context)}', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(format.format(entry.totalPay), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (entry.isSunday ? AppColors.danger : entry.hours18 > 0 ? AppColors.accent : AppColors.primary).withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          entry.isSunday ? 'x2.0' : entry.hours18 > 0 ? 'x1.8' : 'x1.5',
                          style: TextStyle(fontSize: 10, color: entry.isSunday ? AppColors.danger : entry.hours18 > 0 ? AppColors.accent : AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context, bool isDark) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xóa bản ghi?', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Bạn có chắc chắn muốn xóa bản ghi này?', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    ) ?? false;
  }

  void _showEntryActionsSheet(BuildContext context, OvertimeProvider provider, OvertimeEntry entry, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, borderRadius: AppRadius.borderFull)),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.info.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd), child: Icon(Icons.copy_rounded, color: AppColors.info)),
              title: Text('Sao chép sang ngày khác', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              subtitle: Text('${entry.startTime.format(context)} - ${entry.endTime.format(context)}', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(copyFrom: entry))); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd), child: Icon(Icons.edit_rounded, color: AppColors.accent)),
              title: Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(editEntry: entry))); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.danger.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd), child: Icon(Icons.delete_rounded, color: AppColors.danger)),
              title: Text('Xóa', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showDeleteConfirmDialog(context, isDark);
                if (confirm) {
                  provider.deleteEntry(entry.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(children: [const Icon(Icons.delete_rounded, color: Colors.white), const SizedBox(width: 12), Text('Đã xóa OT ngày ${DateFormat('dd/MM').format(entry.date)}')]),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                        action: SnackBarAction(label: 'Hoàn tác', textColor: Colors.white, onPressed: () => provider.restoreEntry(entry)),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
