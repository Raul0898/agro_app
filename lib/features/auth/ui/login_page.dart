// lib/features/auth/ui/login_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agro_app/features/auth/ui/pages/selector_contexto_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const kOrange = Color(0xFFF2AE2E);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _loadingReset = false; // 👈 estado de “Olvidé mi contraseña”

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onFieldsChanged);
    _passCtrl.addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onFieldsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isFormValid {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    final emailValid =
        email.isNotEmpty && email.contains('@') && email.contains('.');
    final passValid = pass.isNotEmpty;

    return emailValid && passValid;
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      debugPrint('✅ Signed in as: ${cred.user?.email}');
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SelectorContextoPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Error de autenticación';
      if (e.code == 'user-not-found') msg = 'El correo no está registrado.';
      if (e.code == 'wrong-password') msg = 'Contraseña incorrecta.';
      if (e.code == 'invalid-credential') msg = 'Credenciales inválidas.';
      if (e.code == 'invalid-email') msg = 'Correo inválido.';
      if (e.code == 'user-disabled') msg = 'Usuario deshabilitado.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      debugPrint('❌ signIn error: ${e.code} - ${e.message}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
      debugPrint('❌ signIn unknown error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    // Oculta teclado para que el SnackBar/diálogo se vean bien
    FocusScope.of(context).unfocus();

    var email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu correo para continuar.')),
      );
      return;
    }

    // Validación básica de formato
    email = email.toLowerCase();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo inválido.')),
      );
      return;
    }

    if (mounted) setState(() => _loadingReset = true);

    // Diálogo de progreso mientras se envía
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 👇 Sin pre-chequeo: enviamos siempre
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      Navigator.of(context).pop(); // cierra el diálogo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Si el correo está registrado, recibirás un mensaje para restablecer la contraseña en $email',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // cierra el diálogo
        // Mantenemos mensaje genérico para no revelar si existe o no
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Si el correo está registrado, recibirás un mensaje para restablecer la contraseña.'),
          ),
        );
      }
      // Log interno para depurar
      debugPrint('❌ reset error: ${e.code} - ${e.message}');
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // cierra el diálogo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Si el correo está registrado, recibirás un mensaje para restablecer la contraseña.'),
          ),
        );
      }
      debugPrint('❌ reset unknown error: $e');
    } finally {
      if (mounted) setState(() => _loadingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    const footerReserve = 90.0;
    final bottomPaddingSafeArea = MediaQuery.of(context).padding.bottom;
    final isFormValid = _isFormValid;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Image.asset('IMG/2.jpg', fit: BoxFit.cover),
          ),

          // Formulario (se desplaza con teclado gracias al padding dinámico)
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                26,
                26,
                26,
                26 + (keyboard > 0 ? keyboard + footerReserve : footerReserve),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Logo superior
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Image.asset(
                        'IMG/Copia de Don Raul-3.png',
                        width: MediaQuery.of(context).size.width * 0.9,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Correo
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !_loading && !_loadingReset,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.25),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white, width: 1.2),
                        ),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Requerido';
                        if (!s.contains('@') || !s.contains('.')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Contraseña
                    TextFormField(
                      controller: _passCtrl,
                      enabled: !_loading && !_loadingReset,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.25),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white, width: 1.2),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: (_loading || _loadingReset)
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 14),

                    // Olvidé mi contraseña
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: (_loading || _loadingReset) ? null : _forgotPassword,
                        child: _loadingReset
                            ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text(
                          'Olvidé mi contraseña',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Botón login
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading || _loadingReset ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFormValid ? kOrange : kOrange.withOpacity(0.35),
                          foregroundColor: isFormValid
                              ? Colors.black
                              : Colors.black.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer fijo
          Positioned(
            left: 0,
            right: 0,
            bottom: (bottomPaddingSafeArea > 0 ? bottomPaddingSafeArea : 10) + 6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Image.asset(
                    'IMG/Norca.png',
                    height: 55,
                    fit: BoxFit.contain,
                  ),
                ),
                const Text(
                  'Derechos Reservados 2026',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}