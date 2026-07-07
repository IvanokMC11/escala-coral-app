import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePass = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_isRegister) {
      final unlinked = await DatabaseService.getUnlinkedMembers();
      if (!mounted) return;
      if (unlinked.isEmpty) {
        _showError('No hay miembros disponibles para vincular. Contacta al administrador.');
        setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      final selected = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Selecciona tu perfil'),
          children: unlinked.map((m) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m['id'] as int),
            child: Row(children: [
              CircleAvatar(radius: 16, child: Text((m['name'] as String).split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join(), style: const TextStyle(fontSize: 11))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['name'], style: const TextStyle(fontSize: 14)),
                if (m['cuerda']?.toString().isNotEmpty == true) Text(m['cuerda'], style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
            ]),
          )).toList(),
        ),
      );
      if (selected == null || !mounted) { setState(() => _loading = false); return; }
      final user = await DatabaseService.register(_emailCtrl.text.trim(), _passCtrl.text, memberId: selected, role: 'miembro');
      if (user != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (mounted) {
        _showError('El email ya esta registrado');
      }
    } else {
      final user = await DatabaseService.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (user != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (mounted) {
        _showError('Email o contraseña incorrectos');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85), theme.colorScheme.surface],
            stops: const [0.0, 0.3, 0.8],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/icon.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 44, color: Color(0xFF6C3FB5)))),
                    ),
                    const SizedBox(height: 24),
                    Text('Scala Coral', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _isRegister ? theme.colorScheme.onSurface : Colors.white)),
                    const SizedBox(height: 4),
                    Text('UNSAAC', style: TextStyle(fontSize: 14, color: _isRegister ? theme.colorScheme.onSurfaceVariant : Colors.white.withValues(alpha: 0.8), letterSpacing: 3)),
                    const SizedBox(height: 40),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesion', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePass = !_obscurePass))),
                              obscureText: _obscurePass,
                              validator: (v) => v!.length < 4 ? 'Minimo 4 caracteres' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isRegister ? 'Registrarse' : 'Ingresar'))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isRegister)
                      TextButton(onPressed: () => setState(() => _isRegister = true), child: const Text('¿No tienes cuenta? Registrate')),
                    if (_isRegister)
                      TextButton(onPressed: () => setState(() => _isRegister = false), child: const Text('¿Ya tienes cuenta? Inicia sesion')),
                    const SizedBox(height: 32),
                    Text('Admin por defecto: admin / admin123', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
