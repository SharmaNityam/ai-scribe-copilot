import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/patient.dart';
import '../../core/repositories/api_repository.dart';
import '../../features/settings/theme_language_provider.dart';
import '../../features/recording/recording_screen.dart';
import 'add_patient_screen.dart';

class PatientsListScreen extends StatefulWidget {
  final String userId;

  const PatientsListScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  final ApiRepository _apiRepository = ApiRepository();
  List<Patient> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final patients = await _apiRepository.getPatients(widget.userId);
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
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
          localizations.translate('patients'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : _patients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                        Icons.people_outline,
                          size: 60,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No patients yet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first patient to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPatients,
                  color: isDark ? Colors.white : Colors.black,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      final patient = _patients[index];
                      return _buildPatientCard(context, patient, isDark);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPatientScreen(userId: widget.userId),
            ),
          );
          if (result == true) {
            _loadPatients();
          }
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Patient',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordingScreen(
                  userId: widget.userId,
                  patientId: patient.id,
                  patientName: patient.name,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Avatar - white circle with black text
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      patient.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Patient Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (patient.phoneNumber != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              patient.phoneNumber!,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
