import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/overtime_entry.dart';

class EntryDetailScreen extends StatelessWidget {
  final OvertimeEntry entry;

  const EntryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final dateFormat = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết tăng ca'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(context, dateFormat, currencyFormat),
            const SizedBox(height: 24),

            // Time Info
            _buildSectionTitle('Thời gian làm việc'),
            const SizedBox(height: 12),
            _buildTimeCard(context),
            const SizedBox(height: 24),

            // OT Breakdown
            _buildSectionTitle('Chi tiết tính lương'),
            const SizedBox(height: 12),
            _buildOTBreakdown(context, currencyFormat),
            const SizedBox(height: 24),

            // Summary
            _buildSummaryCard(context, currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat, NumberFormat currencyFormat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: entry.isSunday
              ? [const Color(0xFFE53935), const Color(0xFFC62828)]
              : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (entry.isSunday ? const Color(0xFFE53935) : const Color(0xFF1E88E5)).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.isSunday ? 'Chủ nhật (x2.0)' : 'Ngày thường',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            dateFormat.format(entry.date),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(entry.totalPay),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildTimeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimeItem(
              context,
              'Bắt đầu',
              entry.startTime.format(context),
              Icons.play_circle_outline,
              Colors.green,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildTimeItem(
              context,
              'Kết thúc',
              entry.endTime.format(context),
              Icons.stop_circle_outlined,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(BuildContext context, String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildOTBreakdown(BuildContext context, NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (entry.hours15 > 0 && !entry.isSunday)
            _buildOTRow(
              'Tăng ca x1.5',
              '17:30 - 22:00',
              entry.hours15,
              entry.hours15 * entry.hourlyRate * 1.5,
              currencyFormat,
              Colors.blue,
            ),
          if (entry.hours18 > 0 && !entry.isSunday)
            _buildOTRow(
              'Tăng ca x1.8',
              'Sau 22:00',
              entry.hours18,
              entry.hours18 * entry.hourlyRate * 1.8,
              currencyFormat,
              Colors.orange,
            ),
          if (entry.isSunday)
            _buildOTRow(
              'Chủ nhật x2.0',
              'Cả ngày',
              entry.hours20,
              entry.hours20 * entry.hourlyRate * 2.0,
              currencyFormat,
              Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildOTRow(String title, String timeRange, double hours, double pay, NumberFormat format, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(timeRange, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${hours.toStringAsFixed(1)} giờ', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(format.format(pay), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NumberFormat currencyFormat) {
    final totalHours = entry.isSunday ? entry.hours20 : (entry.hours15 + entry.hours18);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Tổng số giờ OT', '${totalHours.toStringAsFixed(1)} giờ'),
          const Divider(height: 24),
          _buildSummaryRow('Lương cơ bản/giờ', currencyFormat.format(entry.hourlyRate)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thu nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                currencyFormat.format(entry.totalPay),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
