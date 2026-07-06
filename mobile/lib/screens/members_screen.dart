import 'package:flutter/material.dart';
import '../services/database_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
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
    setState(() => _loading = true);
    _members = await DatabaseService.getMembers();
    _filtered = _members;
    setState(() => _loading = false);
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member != null ? 'Editar' : 'Nuevo miembro'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                const SizedBox(height: 12),
                TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: codigoCtrl, decoration: const InputDecoration(labelText: 'Codigo universitario', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextFormField(controller: escuelaCtrl, decoration: const InputDecoration(labelText: 'Escuela profesional', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: cuerda.isNotEmpty ? cuerda : null,
                      decoration: const InputDecoration(labelText: 'Cuerda', border: OutlineInputBorder(), prefixIcon: Icon(Icons.multitrack_audio)),
                      items: ['SOPRANO', 'ALTO', 'TENOR', 'BAJO'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => cuerda = v ?? '',
                      hint: const Text('Seleccionar cuerda'),
                    ),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (ctx, setLocalState) => CheckboxListTile(
                        title: const Text('Apto para Beca Comedor'),
                        subtitle: const Text('Si no, no aparecera en el ranking de beca'),
                        value: becaEligible,
                        onChanged: (v) => setLocalState(() => becaEligible = v!),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
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
            child: Text(member != null ? 'Guardar' : 'Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('Eliminar a $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.deleteMember(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros'),
        actions: [IconButton(icon: const Icon(Icons.person_add), onPressed: () => _showForm())],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(hintText: 'Buscar...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurfaceVariant), const SizedBox(height: 16), Text('Sin miembros', style: theme.textTheme.bodyLarge)]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final m = _filtered[i];
                        final initials = (m['name'] as String).split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
                        return Dismissible(
                          key: ValueKey(m['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                          onDismissed: (_) => _delete(m['id'], m['name']),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: Text(initials, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold))),
                              title: Row(
                                children: [
                                  Expanded(child: Text(m['name'])),
                                  if ((m['beca_eligible'] ?? 1) == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('No beca', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  if (m['cuerda']?.toString().isNotEmpty == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                                      child: Text(m['cuerda'], style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text([
                                if (m['cuerda']?.toString().isNotEmpty == true) m['cuerda'],
                                if (m['codigo']?.toString().isNotEmpty == true) m['codigo'],
                                if (m['escuela']?.toString().isNotEmpty == true) m['escuela'],
                                if (m['email']?.toString().isNotEmpty == true) m['email'],
                                if (m['phone']?.toString().isNotEmpty == true) m['phone'],
                              ].join(' \u2022 ')),
                              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(member: m)),
                              isThreeLine: true,
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
