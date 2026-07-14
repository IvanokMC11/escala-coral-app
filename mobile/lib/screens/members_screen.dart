import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _initialLoad = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _members = await DatabaseService.getMembers(forceRefresh: true);
      _filtered = _members;
    } catch (_) {
      _error = 'Error al cargar miembros';
    }
    setState(() { _loading = false; _initialLoad = false; });
  }

  void _filter(String q) {
    if (q.isEmpty) {
      _filtered = _members;
    } else {
      _filtered = _members.where((m) =>
        (m['name'] as String).toLowerCase().contains(q.toLowerCase())
      ).toList();
    }
    setState(() {});
  }

  void _showForm({Map<String, dynamic>? member}) {
    final nameCtrl = TextEditingController(text: member?['name'] ?? '');
    final emailCtrl = TextEditingController(text: member?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: member?['phone'] ?? '');
    final codigoCtrl = TextEditingController(text: member?['codigo'] ?? '');
    final escuelaCtrl = TextEditingController(text: member?['escuela'] ?? '');
    var becaEligible = (member?['beca_eligible'] ?? 1) == 1;
    var cuerda = member?['cuerda'] as String? ?? '';
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
              child: ModalWidthConstraint(child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(member != null ? 'Editar miembro' : 'Nuevo miembro', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 14),
                  TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefono', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 14),
                  TextFormField(controller: codigoCtrl, decoration: const InputDecoration(labelText: 'Codigo universitario', prefixIcon: Icon(Icons.badge))),
                  const SizedBox(height: 14),
                  TextFormField(controller: escuelaCtrl, decoration: const InputDecoration(labelText: 'Escuela profesional', prefixIcon: Icon(Icons.school))),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: cuerda.isNotEmpty ? cuerda : null,
                    decoration: const InputDecoration(labelText: 'Cuerda', prefixIcon: Icon(Icons.multitrack_audio)),
                    items: ['SOPRANO', 'ALTO', 'TENOR', 'BAJO'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => cuerda = v ?? ''),
                    hint: const Text('Seleccionar cuerda'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Apto para Beca Comedor'),
                    subtitle: const Text('Si no, no aparecera en el ranking de beca'),
                    value: becaEligible,
                    onChanged: (v) => setDialogState(() => becaEligible = v!),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        if (member != null) {
                          await DatabaseService.updateMember(member['id'], {
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            'codigo': codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                            'escuela': escuelaCtrl.text.trim().isEmpty ? null : escuelaCtrl.text.trim(),
                            'beca_eligible': becaEligible ? 1 : 0,
                            'cuerda': cuerda.isEmpty ? null : cuerda,
                          });
                        } else {
                          await DatabaseService.addMember(nameCtrl.text.trim(), email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(), phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(), codigo: codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(), escuela: escuelaCtrl.text.trim().isEmpty ? null : escuelaCtrl.text.trim(), cuerda: cuerda.isEmpty ? null : cuerda);
                        }
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(member != null ? 'Guardar cambios' : 'Agregar miembro'),
                    ),
                  ),
                ]),
              )),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: DatabaseService.isStaff
          ? [Container(margin: const EdgeInsets.only(right: 4), child: IconButton.filled(icon: const Icon(Icons.person_add), onPressed: () => _showForm()))]
          : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(hintText: 'Buscar miembro...', prefixIcon: const Icon(Icons.search)),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _loading && _initialLoad
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? ErrorRetry(message: _error!, onRetry: _load)
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: _searchCtrl.text.isEmpty ? 'Sin miembros' : 'Sin resultados',
                    subtitle: _searchCtrl.text.isEmpty ? 'Agrega los miembros del coro' : 'Intenta con otro nombre',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final m = _filtered[i];
                        final initials = (m['name'] as String).split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: DatabaseService.isStaff ? () => _showForm(member: m) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    child: Text(initials, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        if ((m['beca_eligible'] ?? 1) == 0)
                                          Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Text('No beca', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold))),
                                        if (m['cuerda']?.toString().isNotEmpty == true)
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(m['cuerda'], style: const TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold))),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text([if (m['codigo']?.toString().isNotEmpty == true) m['codigo'], if (m['escuela']?.toString().isNotEmpty == true) m['escuela'], if (m['email']?.toString().isNotEmpty == true) m['email']].join(' \u2022 '), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ]),
                                  ),
                                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
