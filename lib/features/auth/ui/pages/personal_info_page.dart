// lib/features/auth/ui/pages/personal_info_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  // --- Estado del widget ---
  bool _isLoading = true;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos del formulario
  final _nombreCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  // Variables para la imagen de perfil
  File? _imageFile;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  /// Carga los datos del usuario actual desde Firestore
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nombreCtrl.text = data['nombre'] ?? '';
        _dirCtrl.text = data['direccion'] ?? '';
        _telCtrl.text = data['telefono'] ?? '';
        setState(() {
          _currentPhotoUrl = data['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Abre la galería para seleccionar una imagen
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  /// Guarda los cambios en Firebase
  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) return;

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      String? newPhotoUrl;
      // 1. Si se seleccionó una nueva imagen, subirla a Firebase Storage
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_pictures').child('${user.uid}.jpg');
        await ref.putFile(_imageFile!);
        newPhotoUrl = await ref.getDownloadURL();
      }

      // 2. Preparar los datos a actualizar en Firestore
      final Map<String, dynamic> dataToUpdate = {
        'nombre': _nombreCtrl.text.trim(),
        'direccion': _dirCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
        if (newPhotoUrl != null) 'photoUrl': newPhotoUrl,
      };

      // 3. Actualizar el documento del usuario en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(dataToUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información actualizada con éxito.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información Personal'),
        backgroundColor: const Color(0xFFF2AE2E),
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- Selector de Foto de Perfil ---
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null) as ImageProvider?,
                    child: _imageFile == null && _currentPhotoUrl == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFF2AE2E),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.black),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Campos de Texto ---
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre Completo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dirCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telCtrl,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),

              // --- Botón de Guardar ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Guardar Cambios'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFF2AE2E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              // --- NUEVO: Imagen de footer ---
              const SizedBox(height: 10), // Espacio para separar
              SizedBox(
                height: 225, // Altura para que se vea bien
                child: Image.asset(
                  'IMG/Copia de Don Raul.png',
                  fit: BoxFit.contain,
                ),
              ),
              // --- FIN DE LA ADICIÓN ---
            ],
          ),
        ),
      ),
    );
  }
}