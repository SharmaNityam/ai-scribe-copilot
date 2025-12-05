import 'package:flutter/material.dart';
import '../../core/models/patient.dart';
import '../../core/repositories/api_repository.dart';
import '../../features/settings/theme_language_provider.dart';
import 'package:provider/provider.dart';

class AddPatientScreen extends StatefulWidget {
  final String userId;

  const AddPatientScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _apiRepository = ApiRepository();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final patient = Patient(
        userId: widget.userId,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );

      await _apiRepository.addPatient(patient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding patient: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          localizations.translate('add_patient'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
        key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
          children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add,
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add New Patient',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter patient information to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Form Fields
              _buildTextField(
                context,
                controller: _nameController,
                label: localizations.translate('patient_name'),
                icon: Icons.person,
                isDark: isDark,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
              _buildTextField(
                context,
              controller: _phoneController,
                label: localizations.translate('phone_number'),
                icon: Icons.phone,
                isDark: isDark,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
              _buildTextField(
                context,
              controller: _emailController,
                label: localizations.translate('email'),
                icon: Icons.email,
                isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
              
              // Save Button - white button with black text
              SizedBox(
                height: 56,
                child: ElevatedButton(
              onPressed: _isSaving ? null : _savePatient,
              style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                    )
                      : Text(
                          localizations.translate('save'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black87,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
