import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/debt.dart';
import '../services/database_service.dart';

class DebtsScreen extends StatefulWidget {
  final DatabaseService databaseService;
  const DebtsScreen({super.key, required this.databaseService});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  DebtDirection _direction = DebtDirection.owedToMe;
  final _money = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<Debt> get _items =>
      widget.databaseService.debts
          .where((e) => e.direction == _direction)
          .toList();

  @override
  Widget build(BuildContext context) {
    double total(DebtDirection direction) => widget.databaseService.debts
        .where((e) => e.direction == direction)
        .fold(0, (sum, e) => sum + e.balance);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ghi nợ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _Summary(
                    title: 'Cần thu',
                    amount: _money.format(total(DebtDirection.owedToMe)),
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Summary(
                    title: 'Cần trả',
                    amount: _money.format(total(DebtDirection.iOwe)),
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.owedToMe,
                    label: Text('Họ nợ mình'),
                    icon: Icon(Icons.call_received_rounded),
                  ),
                  ButtonSegment(
                    value: DebtDirection.iOwe,
                    label: Text('Mình nợ họ'),
                    icon: Icon(Icons.call_made_rounded),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged:
                    (value) => setState(() => _direction = value.first),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _items.isEmpty
                    ? _Empty(
                      isOwedToMe: _direction == DebtDirection.owedToMe,
                      onAdd: _addDebt,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _debtCard(_items[index]),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDebt,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Thêm khoản nợ'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _debtCard(Debt debt) {
    final color =
        debt.direction == DebtDirection.owedToMe
            ? const Color(0xFF059669)
            : const Color(0xFFE11D48);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _history(debt),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    foregroundColor: color,
                    child: Text(debt.personName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money.format(debt.balance),
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${debt.transactions.length} lần cập nhật',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adjust(debt, false),
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Đã trả bớt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _adjust(debt, true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Mượn thêm'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đã trả hết',
                    onPressed: () => _settle(debt),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDebt() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var direction = _direction;
    final newDebt = await showModalBottomSheet<Debt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Thêm khoản nợ',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<DebtDirection>(
                          segments: const [
                            ButtonSegment(
                              value: DebtDirection.owedToMe,
                              label: Text('Họ nợ mình'),
                            ),
                            ButtonSegment(
                              value: DebtDirection.iOwe,
                              label: Text('Mình nợ họ'),
                            ),
                          ],
                          selected: {direction},
                          onSelectionChanged:
                              (value) =>
                                  setSheetState(() => direction = value.first),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Tên người',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _amountField(amount),
                        const SizedBox(height: 12),
                        TextField(
                          controller: note,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú (không bắt buộc)',
                            prefixIcon: Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () {
                            final value = double.tryParse(amount.text);
                            if (name.text.trim().isEmpty ||
                                value == null ||
                                value <= 0) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập tên và số tiền hợp lệ.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final now = DateTime.now();
                            final id = now.microsecondsSinceEpoch.toString();
                            Navigator.pop(
                              sheetContext,
                              Debt(
                                id: id,
                                personName: name.text.trim(),
                                direction: direction,
                                createdAt: now,
                                transactions: [
                                  DebtTransaction(
                                    id: '${id}_first',
                                    amount: value,
                                    note:
                                        note.text.trim().isEmpty
                                            ? 'Khoản nợ ban đầu'
                                            : note.text.trim(),
                                    createdAt: now,
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 13),
                            child: Text('Lưu khoản nợ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    name.dispose();
    amount.dispose();
    note.dispose();
    if (newDebt != null && mounted) {
      setState(() => _direction = newDebt.direction);
      await widget.databaseService.addDebt(newDebt);
    }
  }

  Widget _amountField(TextEditingController controller) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: const InputDecoration(
      labelText: 'Số tiền',
      suffixText: 'đ',
      prefixIcon: Icon(Icons.payments_outlined),
      border: OutlineInputBorder(),
    ),
  );

  Future<void> _adjust(Debt debt, bool adding) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final adjustment =
        await showModalBottomSheet<({double amount, String note})>(
          context: context,
          isScrollControlled: true,
          builder:
              (sheetContext) => Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      adding
                          ? '${debt.personName} mượn thêm'
                          : 'Ghi nhận đã trả',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Hiện còn ${_money.format(debt.balance)}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    _amountField(amount),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        final value = double.tryParse(amount.text);
                        if (value == null || value <= 0) return;
                        Navigator.pop(sheetContext, (
                          amount: adding ? value : -value,
                          note: note.text.trim(),
                        ));
                      },
                      child: Text(
                        adding ? 'Cộng vào khoản nợ' : 'Trừ khỏi khoản nợ',
                      ),
                    ),
                  ],
                ),
              ),
        );
    amount.dispose();
    note.dispose();
    if (adjustment != null) {
      await widget.databaseService.adjustDebt(
        debt.id,
        adjustment.amount,
        note: adjustment.note,
      );
    }
  }

  Future<void> _settle(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.task_alt_rounded, color: Color(0xFF059669)),
            title: const Text('Đã trả hết nợ?'),
            content: Text(
              'Khoản ${_money.format(debt.balance)} với ${debt.personName} sẽ được đánh dấu đã thanh toán.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Chưa'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Đã trả hết'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await widget.databaseService.settleDebt(debt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tất toán khoản nợ với ${debt.personName}.'),
          ),
        );
      }
    }
  }

  void _history(Debt debt) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch sử · ${debt.personName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: debt.transactions.length,
                    itemBuilder: (_, index) {
                      final item = debt.transactions.reversed.elementAt(index);
                      // Older records stored the first note on the debt itself.
                      // Keep it available in history without showing it on the card.
                      final transactionNote =
                          identical(item, debt.transactions.first) &&
                                  item.note == 'Khoản nợ ban đầu' &&
                                  debt.note.isNotEmpty
                              ? debt.note
                              : item.note;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Icon(
                            item.amount > 0
                                ? Icons.add_rounded
                                : Icons.remove_rounded,
                          ),
                        ),
                        title: Text(
                          '${item.amount > 0 ? '+' : '−'}${_money.format(item.amount.abs())}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          transactionNote.isEmpty
                              ? DateFormat(
                                'dd/MM/yyyy · HH:mm',
                              ).format(item.createdAt)
                              : '$transactionNote · ${DateFormat('dd/MM/yyyy').format(item.createdAt)}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

class _Summary extends StatelessWidget {
  final String title, amount;
  final Color color;
  const _Summary({
    required this.title,
    required this.amount,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        FittedBox(
          child: Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  final bool isOwedToMe;
  final VoidCallback onAdd;
  const _Empty({required this.isOwedToMe, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.handshake_outlined,
            size: 62,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            isOwedToMe ? 'Chưa có ai nợ bạn' : 'Bạn chưa nợ ai',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thêm một khoản để theo dõi mỗi khi vay thêm hoặc trả bớt.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm ngay'),
          ),
        ],
      ),
    ),
  );
}
