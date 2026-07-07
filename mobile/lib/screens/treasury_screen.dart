import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  late int _year, _month;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _memberDebts = [];
  List<Map<String, dynamic>> _filteredDebts = [];
  Map<String, double> _summary = {'total_income': 0, 'total_expense': 0, 'balance': 0};
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterDebts(String q) {
    setState(() {
      if (q.isEmpty) {
        _filteredDebts = _memberDebts.where((d) => d['total_debt'] > 0).toList();
      } else {
        _filteredDebts = _memberDebts.where((d) =>
          d['total_debt'] > 0 && (d['name'] as String).toLowerCase().contains(q.toLowerCase())
        ).toList();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _transactions = await DatabaseService.getTreasury(month: _month, year: _year);
    _summary = await DatabaseService.getTreasurySummary(month: _month, year: _year);
    _memberDebts = await DatabaseService.getMemberDebts();
    _filteredDebts = _memberDebts.where((d) => d['total_debt'] > 0).toList();
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      else if (_month < 1) { _month = 12; _year--; }
    });
    _load();
  }

  void _addFine() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var selectedMember = _memberDebts.isNotEmpty ? _memberDebts.first['id'] as int : 0;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Nueva multa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Miembro', prefixIcon: Icon(Icons.person)),
                    items: _memberDebts.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['name']))).toList(),
                    onChanged: (v) => setDialogState(() => selectedMember = v ?? 0),
                    initialValue: selectedMember,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto (S/)', prefixIcon: Icon(Icons.monetization_on)), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Motivo', prefixIcon: Icon(Icons.description)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await DatabaseService.addMemberFine(selectedMember, double.parse(amountCtrl.text.trim()), reasonCtrl.text.trim());
                    Navigator.pop(ctx);
                    _load();
                  }, child: const Text('Agregar multa'))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addExpense() {
    final amountCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo gasto'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: conceptCtrl, decoration: const InputDecoration(labelText: 'Concepto', prefixIcon: Icon(Icons.edit)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto (S/)', prefixIcon: Icon(Icons.money_off)), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripcion', prefixIcon: Icon(Icons.description))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await DatabaseService.addTreasuryEntry('expense', conceptCtrl.text.trim(), double.parse(amountCtrl.text.trim()), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  void _addExternalFund() {
    final amountCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fondo externo'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: conceptCtrl, decoration: const InputDecoration(labelText: 'Concepto', prefixIcon: Icon(Icons.edit)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto (S/)', prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await DatabaseService.addTreasuryEntry('income', conceptCtrl.text.trim(), double.parse(amountCtrl.text.trim()), description: 'Fondo externo');
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  Future<void> _collect(int memberId, String name, double totalDebt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobrar deuda'),
        content: Text('Cobrar S/ ${totalDebt.toStringAsFixed(2)} a $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.collectMemberDebt(memberId, totalDebt, 'Cobro de deuda - $name');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime(_year, _month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tesorería', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.monetization_on), onPressed: _addFine, tooltip: 'Multa'),
          PopupMenuButton(itemBuilder: (_) => [
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.add_circle, color: Colors.green), title: Text('Fondo externo'), dense: true), onTap: () => _addExternalFund()),
            PopupMenuItem(child: const ListTile(leading: Icon(Icons.remove_circle, color: Colors.red), title: Text('Gasto'), dense: true), onTap: () => _addExpense()),
          ]),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                        Text(monthName[0].toUpperCase() + monthName.substring(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    _StatCard(theme: theme, icon: Icons.arrow_upward, label: 'Ingresos', value: 'S/ ${_summary['total_income']!.toStringAsFixed(2)}', color: Colors.green),
                    const SizedBox(width: 8),
                    _StatCard(theme: theme, icon: Icons.arrow_downward, label: 'Gastos', value: 'S/ ${_summary['total_expense']!.toStringAsFixed(2)}', color: Colors.red),
                    const SizedBox(width: 8),
                    _StatCard(theme: theme, icon: Icons.account_balance, label: 'Balance', value: 'S/ ${_summary['balance']!.toStringAsFixed(2)}', color: _summary['balance']! >= 0 ? Colors.green : Colors.red),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Icon(Icons.people, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Deudas de miembros', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(hintText: 'Buscar deudor...', prefixIcon: Icon(Icons.search)),
                    onChanged: _filterDebts,
                  ),
                  const SizedBox(height: 8),
                  if (_memberDebts.where((d) => d['total_debt'] > 0).isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Column(children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green),
                          const SizedBox(height: 8),
                          Text('Sin deudas pendientes', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ])),
                      ),
                    )
                  else if (_filteredDebts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Sin resultados', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                      ),
                    )
                  else
                    ...(_filteredDebts..sort((a, b) => (b['total_debt'] as num).compareTo(a['total_debt'] as num))).map((d) {
                      final total = (d['total_debt'] as num).toDouble();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(d['name'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                  Text('S/ ${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.error)),
                                ]),
                              ),
                              FilledButton(onPressed: () => _collect(d['id'], d['name'], total), child: const Text('Cobrar')),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Row(children: [
                    Icon(Icons.receipt_long, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Movimientos del mes', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Sin movimientos este mes', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                      ),
                    )
                  else
                    ..._transactions.map((t) {
                      final isIncome = t['type'] == 'income';
                      final amount = (t['amount'] as num).toDouble();
                      final date = DateTime.tryParse(t['created_at']);
                      final time = date != null ? DateFormat('d MMM HH:mm', 'es').format(date) : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15)),
                            child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.green : Colors.red, size: 18),
                          ),
                          title: Text(t['concept'] ?? '', style: const TextStyle(fontSize: 13)),
                          subtitle: Text(time, style: const TextStyle(fontSize: 11)),
                          trailing: Text('${isIncome ? '+' : '-'}S/ ${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 14)),
                          dense: true,
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.theme, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ]),
        ),
      ),
    );
  }
}
