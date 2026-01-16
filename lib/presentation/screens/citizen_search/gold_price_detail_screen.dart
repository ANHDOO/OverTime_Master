import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../logic/providers/gold_provider.dart';
import '../../../data/models/gold_investment.dart';
import '../../widgets/smart_money_input.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/gold_highlight_card.dart';
import 'widgets/gold_price_list.dart';
import 'widgets/gold_investment_list.dart';
import 'widgets/gold_portfolio_summary.dart';

class GoldPriceDetailScreen extends StatefulWidget {
  const GoldPriceDetailScreen({super.key});

  @override
  State<GoldPriceDetailScreen> createState() => _GoldPriceDetailScreenState();
}

class _GoldPriceDetailScreenState extends State<GoldPriceDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Vàng Tám Nhung'),
          elevation: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Giá hiện tại', icon: Icon(Icons.show_chart_rounded, size: 20)),
              Tab(text: 'Sổ đầu tư', icon: Icon(Icons.account_balance_wallet_rounded, size: 20)),
            ],
            indicatorColor: isDark ? Colors.white : AppColors.primary,
            indicatorWeight: 3,
            labelColor: isDark ? Colors.white : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white.withOpacity(0.7) : AppColors.lightTextSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => Provider.of<GoldProvider>(context, listen: false).fetchGoldData(),
            ),
          ],
        ),
        body: Consumer<GoldProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
            return TabBarView(
              children: [
                _buildCurrentPricesTab(context, provider, isDark),
                _buildInvestmentTab(context, provider, isDark),
              ],
            );
          },
        ),
        floatingActionButton: _buildFAB(context, isDark),
      ),
    );
  }

  Widget _buildCurrentPricesTab(BuildContext context, GoldProvider provider, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                const SizedBox(width: 6),
                Text(
                  'Cập nhật lúc: ${provider.lastUpdated}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ],
            ),
          ),
        GoldHighlightCard(isDark: isDark),
        const SizedBox(height: 24),
        GoldPriceList(isDark: isDark),
        const SizedBox(height: 100), // Space for FAB
      ],
    );
  }

  Widget _buildInvestmentTab(BuildContext context, GoldProvider provider, bool isDark) {
    return Column(
      children: [
        if (provider.investments.isNotEmpty) GoldPortfolioSummary(isDark: isDark),
        Expanded(
          child: GoldInvestmentList(
            isDark: isDark,
            onEdit: (inv) => _showAddInvestmentDialog(context, investment: inv as GoldInvestment),
            onDelete: (id) => _confirmDelete(context, id, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroOrange,
        shape: BoxShape.circle,
        boxShadow: AppShadows.heroOrangeLight,
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddInvestmentDialog(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  void _showAddInvestmentDialog(BuildContext context, {GoldInvestment? investment}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<GoldProvider>(context, listen: false);
    
    String? selectedType = investment?.goldType ?? (provider.maoThietPrices.isNotEmpty ? provider.maoThietPrices[0]['type'] : null);
    final quantityController = TextEditingController(text: investment?.quantity.toString() ?? '');
    final priceController = TextEditingController(text: investment != null ? NumberFormat('#,###').format(investment.buyPrice) : '');
    final noteController = TextEditingController(text: investment?.note ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Icon(investment == null ? Icons.add_rounded : Icons.edit_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        investment == null ? 'Thêm giao dịch mua' : 'Sửa giao dịch mua',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Loại vàng', isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        items: provider.maoThietPrices.map((p) => DropdownMenuItem<String>(
                          value: p['type'],
                          child: Text(
                            p['type'] ?? '',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedType = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Số lượng (chỉ)', isDark),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
                    decoration: _buildInputDecoration('VD: 0.5, 1.0...', isDark),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Giá mua (đ/chỉ)', isDark),
                  const SizedBox(height: 8),
                  SmartMoneyInput(controller: priceController, label: 'Giá mua'),
                  const SizedBox(height: 16),
                  _buildLabel('Ghi chú (tùy chọn)', isDark),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
                    decoration: _buildInputDecoration('Nơi mua, lý do...', isDark),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(gradient: AppGradients.heroOrange, borderRadius: AppRadius.borderMd, boxShadow: AppShadows.heroOrangeLight),
                          child: ElevatedButton(
                            onPressed: () async {
                              if (selectedType != null && quantityController.text.isNotEmpty && priceController.text.isNotEmpty) {
                                double inputPrice = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                                if (inputPrice < 1000000) inputPrice *= 1000;
                                
                                final inv = GoldInvestment(
                                  id: investment?.id,
                                  goldType: selectedType!,
                                  quantity: double.tryParse(quantityController.text) ?? 0,
                                  buyPrice: inputPrice,
                                  date: investment?.date ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                                  note: noteController.text,
                                );
                                
                                if (investment == null) await provider.addInvestment(inv);
                                else await provider.updateInvestment(inv);
                                
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Lưu giao dịch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
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

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, letterSpacing: 1),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted.withOpacity(0.5) : AppColors.lightTextMuted.withOpacity(0.5), fontSize: 14),
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
      border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int id, bool isDark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xóa giao dịch?', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w800)),
        content: Text('Bạn có chắc chắn muốn xóa giao dịch này không? Hành động này không thể hoàn tác.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa ngay', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      Provider.of<GoldProvider>(context, listen: false).deleteInvestment(id);
    }
  }
}
