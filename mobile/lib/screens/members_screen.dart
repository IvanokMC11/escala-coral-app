import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMembers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo miembro'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              context.read<AppState>().addMember(
                    nameCtrl.text.trim(),
                    emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros'),
        actions: [
          if (context.watch<AppState>().isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar miembro...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => context.read<AppState>().filterMembers(v),
            ),
          ),
          Expanded(
            child: Consumer<AppState>(
              builder: (_, state, __) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.members.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No hay miembros registrados',
                            style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => state.loadMembers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.members.length,
                    itemBuilder: (_, i) {
                      final member = state.members[i];
                      return _MemberCard(member: member);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = member.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(initials,
              style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(member.name),
        subtitle: Text([
          if (member.email != null) member.email!,
          if (member.phone != null) member.phone!,
          if (member.isAdmin) 'Admin',
        ].join(' \u2022 ')),
        trailing: member.isAdmin
            ? Icon(Icons.admin_panel_settings,
                color: theme.colorScheme.primary, size: 20)
            : null,
        isThreeLine: member.email != null || member.phone != null,
        onTap: () => _showDetail(context, member),
      ),
    );
  }

  void _showDetail(BuildContext context, Member member) {
    final state = context.read<AppState>();
    if (!state.isAdmin) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(context, member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, member);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Member member) {
    final nameCtrl = TextEditingController(text: member.name);
    final emailCtrl = TextEditingController(text: member.email ?? '');
    final phoneCtrl = TextEditingController(text: member.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar miembro'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              context.read<AppState>().editMember(member.id, {
                'name': nameCtrl.text.trim(),
                'email':
                    emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                'phone':
                    phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar miembro'),
        content: Text('Eliminar a ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppState>().removeMember(member.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
