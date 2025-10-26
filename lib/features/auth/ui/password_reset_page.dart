import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetPage extends StatefulWidget {
  final String? initialEmail;
  const PasswordResetPage({super.key, this.initialEmail});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Ingresa tu correo';
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!re.hasMatch(s)) return 'Correo no válido';
    return null;
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final email = _emailCtrl.text.trim();

    try {
      // 1) Verificar que el correo exista y tenga método "password"
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      final hasPassword = methods.contains('password');
      if (!hasPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este correo no está registrado.')),
          );
        }
        setState(() => _sending = false);
        return;
      }

      // 2) Enviar correo de restablecimiento
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te enviamos un correo para restablecer tu contraseña. Revisa tu bandeja.'),
        ),
      );
      Navigator.of(context).pop(); // regresar al login
    } on FirebaseAuthException catch (e) {
      String msg = 'Ocurrió un error';
      if (e.code == 'user-not-found') msg = 'Este correo no está registrado.';
      else if (e.code == 'invalid-email') msg = 'Correo no válido.';
      else if (e.code == 'missing-email') msg = 'Falta el correo.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('IMG/2.jpg', fit: BoxFit.cover)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Recuperar contraseña',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.mail_outline),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2AE2E),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _sending ? null : _sendReset,
                        label: const Text('Enviar enlace de restablecimiento',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: _sending ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Volver al inicio de sesión',
                        style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('IMG/Norca.png', width: 90, fit: BoxFit.contain),
              const SizedBox(height: 6),
              const Text('Derechos Reservados 2026',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}