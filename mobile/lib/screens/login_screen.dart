import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/carreras.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

    try {
      final user = await DatabaseService.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (user != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (mounted) {
        final err = DatabaseService.lastError;
        _showError(err != null ? 'Error: ${err.length > 80 ? err.substring(0, 80) : err}' : 'Usuario o contraseña incorrectos');
      }
    } catch (e) {
      _showError('Error de conexión: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e.toString()}');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  /// Formulario OBLIGATORIO que aparece en el primer inicio de sesion con
  /// Google. El integrante completa sus datos para que salgan correctos en
  /// el ranking y el documento de beca. Si ya esta en la lista del coro,
  /// puede seleccionar su nombre para pre-llenar y NO duplicar el registro.
  /// Devuelve el id del miembro vinculado, o null si cancela.
  Future<int?> _completeGoogleProfile(String email) async {
    final unlinked = await DatabaseService.getUnlinkedMembers();
    if (!mounted) return null;

    final nameCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final escuelaOtraCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? escuela; // carrera seleccionada del desplegable
    var cuerda = '';
    var becaEligible = true;
    int? existingId; // si elige un miembro ya existente de la lista
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ModalWidthConstraint(child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 18),
                  const Text('¡Bienvenido! Completa tus datos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Se usan para el ranking y el documento de Beca Comedor.', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                  const SizedBox(height: 18),
                  if (unlinked.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: existingId,
                      isExpanded: true,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: '¿Ya estás en la lista? (opcional)', prefixIcon: Icon(Icons.how_to_reg)),
                      hint: const Text('Selecciona tu nombre', style: TextStyle(color: Colors.white54)),
                      items: unlinked.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['name'], overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) {
                        existingId = v;
                        final m = unlinked.firstWhere((e) => e['id'] == v, orElse: () => <String, dynamic>{});
                        nameCtrl.text = m['name']?.toString() ?? '';
                        codigoCtrl.text = m['codigo']?.toString() ?? '';
                        final esc = m['escuela']?.toString() ?? '';
                        if (esc.isEmpty) {
                          escuela = null;
                        } else if (carrerasUnsaac.contains(esc)) {
                          escuela = esc;
                        } else {
                          escuela = 'Otra (especificar)';
                          escuelaOtraCtrl.text = esc;
                        }
                        phoneCtrl.text = m['phone']?.toString() ?? '';
                        cuerda = m['cuerda']?.toString() ?? '';
                        becaEligible = (m['beca_eligible'] ?? 1) == 1;
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('...o llena tus datos abajo si no apareces en la lista.', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    initialValue: email,
                    readOnly: true,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codigoCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Código universitario', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: escuela,
                    isExpanded: true,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Escuela profesional (carrera)', prefixIcon: Icon(Icons.school_outlined)),
                    hint: const Text('Selecciona tu carrera', style: TextStyle(color: Colors.white54)),
                    items: carrerasUnsaac.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setSheet(() => escuela = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  if (escuela == 'Otra (especificar)') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: escuelaOtraCtrl,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Escribe tu carrera', prefixIcon: Icon(Icons.edit_outlined)),
                      validator: (v) => (escuela == 'Otra (especificar)' && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono (opcional)', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cuerda.isNotEmpty ? cuerda : null,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Cuerda', prefixIcon: Icon(Icons.multitrack_audio)),
                    items: ['SOPRANO', 'ALTO', 'TENOR', 'BAJO'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setSheet(() => cuerda = v ?? ''),
                    hint: const Text('Seleccionar', style: TextStyle(color: Colors.white54)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: becaEligible,
                    onChanged: (v) => setSheet(() => becaEligible = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Postulo a Beca Comedor', style: TextStyle(fontSize: 14, color: Colors.white)),
                    subtitle: Text('Me incluye en el ranking de beca', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final escuelaFinal = (escuela == 'Otra (especificar)')
                          ? escuelaOtraCtrl.text.trim()
                          : (escuela ?? '');
                      try {
                        int memberId;
                        if (existingId != null) {
                          await DatabaseService.updateMember(existingId!, {
                            'name': nameCtrl.text.trim(),
                            'email': email,
                            'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            'codigo': codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                            'escuela': escuelaFinal.isEmpty ? null : escuelaFinal,
                            'beca_eligible': becaEligible ? 1 : 0,
                            'cuerda': cuerda,
                          });
                          memberId = existingId!;
                        } else {
                          memberId = await DatabaseService.addMember(
                            nameCtrl.text.trim(),
                            email: email,
                            phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            codigo: codigoCtrl.text.trim().isEmpty ? null : codigoCtrl.text.trim(),
                            escuela: escuelaFinal.isEmpty ? null : escuelaFinal,
                            becaEligible: becaEligible ? 1 : 0,
                            cuerda: cuerda,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, memberId);
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.'), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Guardar y entrar'),
                  ),
                ],
              ),
            )),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final result = await DatabaseService.signInWithGoogle();
      if (!mounted) return;
      switch (result.status) {
        case GoogleAuthStatus.cancelled:
          break;
        case GoogleAuthStatus.unauthorized:
          _showError('El correo ${result.email ?? ''} no está autorizado. Usa tu correo @${DatabaseService.allowedDomain} o pide al admin que te habilite.');
          break;
        case GoogleAuthStatus.loggedIn:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          return;
        case GoogleAuthStatus.needsLink:
          final memberId = await _completeGoogleProfile(result.email!);
          if (memberId == null || !mounted) break;
          final user = await DatabaseService.registerGoogleUser(result.email!, memberId);
          if (user != null && mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            return;
          } else if (mounted) {
            _showError('No se pudo crear la cuenta. Intenta de nuevo.');
          }
          break;
        case GoogleAuthStatus.error:
          _showError('Error al iniciar con Google. Verifica tu conexión e intenta de nuevo.');
          break;
      }
    } catch (e) {
      if (mounted) _showError('Error con Google: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e.toString()}');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _googleAvailable => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: _glowBlob(280, AppColors.primary.withValues(alpha: 0.25)),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _glowBlob(300, const Color(0xFF8B0000).withValues(alpha: 0.18)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ModalWidthConstraint(maxWidth: 440, child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, Color(0xFF8B0000)],
                          ),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: 2),
                          ],
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 32, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Scala Coral', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                      const SizedBox(height: 6),
                      Text('UNSAAC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 4)),
                      const SizedBox(height: 32),

                      // ─── Tarjeta principal ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Acceso de miembros: Google ──
                            if (_googleAvailable) ...[
                              const Text('Miembros del coro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Ingresa con tu correo institucional. La primera vez completarás tus datos.', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _loading ? null : _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const _GoogleLogo(),
                                  label: const Text('Continuar con Google', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Solo correos @${DatabaseService.allowedDomain}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              const SizedBox(height: 20),
                            ],
                            // ── Acceso de administración: correo + contraseña ──
                            Row(children: [
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Administración', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                              ),
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                            ]),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Usuario / Email', prefixIcon: Icon(Icons.person_outline)),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                              obscureText: _obscurePass,
                              validator: (v) => v!.length < 4 ? 'Minimo 4 caracteres' : null,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Ingresar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Pequeño logo "G" de Google para el botón, sin depender de un asset externo.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
