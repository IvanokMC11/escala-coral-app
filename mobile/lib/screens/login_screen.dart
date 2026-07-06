import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegister = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();

    if (_isRegister) {
      await state.register(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
    } else {
      await state.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Escala Coral', style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 8),
                  Text('UNSAAC', style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
                  const SizedBox(height: 48),
                  if (_isRegister)
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  if (_isRegister) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Requerido';
                      if (!v.contains('@')) return 'Email invalido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v!.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Minimo 6 caracteres';
                      return null;
                    },
                  ),
                  if (_isRegister) const SizedBox(height: 16),
                  if (_isRegister)
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Telefono (opcional)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  const SizedBox(height: 24),
                  Consumer<AppState>(
                    builder: (_, state, __) => FilledButton(
                      onPressed: state.loading ? null : _submit,
                      child: state.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegister ? 'Registrarse' : 'Iniciar sesion'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister
                        ? 'Ya tengo cuenta'
                        : 'Registrarme por primera vez'),
                  ),
                  Consumer<AppState>(
                    builder: (_, state, __) {
                      if (state.error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(state.error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
