import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;

  const ProfileSetupScreen({super.key, required this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _uidController = TextEditingController();
  String? _selectedProgram;
  String? _selectedDept;
  String? _selectedYear;
  bool _isLoading = false;

  final List<String> _programTypes = [
    'Under Graduate Programs (UG)',
    'Post Graduate Programs (PG)',
  ];

  final Map<String, List<String>> _departments = {
    'Under Graduate Programs (UG)': [
      'Bachelor of Arts (B.A.)',
      'Bachelor of Arts in Mass Communication & Journalism (B.A.‑MCJ)',
      'Bachelor of Science (B.Sc.)',
      'Bachelor of Science in Information Technology (B.Sc. IT)',
      'Bachelor of Science in Data Science & Artificial Intelligence (B.Sc. DSAI)',
      'Bachelor of Science in Biotechnology & Computational Biology (B.Sc. BCB)',
      'Bachelor of Commerce (B.Com.)',
      'Bachelor of Commerce in Management Studies (B.Com. MS)',
      'Bachelor of Commerce in Accounting and Finance (B.A.F.)',
    ],
    'Post Graduate Programs (PG)': [
      'M.A. in Ancient Indian History, Culture & Archaeology',
      'M.A. in Public Policy',
      'M.A. in Psychology (Lifespan Counselling)',
      'M.Sc. in Botany',
      'M.Sc. in Geology',
      'M.Sc. in Life Sciences',
      'M.Sc. in Microbiology',
      'M.Sc. in Big Data Analytics',
      'M.Sc. in Biotechnology',
      'M.Sc. in Physics (Astrophysics)',
    ],
  };

  final Map<String, List<String>> _yearOptions = {
    'Under Graduate Programs (UG)': [
      'First Year',
      'Second Year',
      'Third Year',
    ],
    'Post Graduate Programs (PG)': [
      'First Year',
      'Second Year',
    ],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _rollNumberController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProgram == null ||
        _selectedDept == null ||
        _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Program, Department and Year'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticUtils.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final supabaseService = SupabaseService();
      final user = await supabaseService.getCurrentUser();

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final student = Student(
        email: widget.email,
        name: _nameController.text.trim(),
        rollNumber: _rollNumberController.text.trim(),
        uid: _uidController.text.trim(),
        dept: _selectedDept!,
        year: _selectedYear!,
      );

      await supabaseService.createStudent(student, user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryOrange,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add,
                        size: 35,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tell us about yourself',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Complete your profile to get started',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Form section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _rollNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Roll Number',
                          hintText: 'Enter your roll number',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your roll number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _uidController,
                        decoration: const InputDecoration(
                          labelText: 'UID',
                          hintText: 'Enter your UID',
                          prefixIcon: Icon(Icons.fingerprint),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your UID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedProgram,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Program Type',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: _programTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child:
                                Text(type, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProgram = value;
                            _selectedDept = null;
                            _selectedYear = null;
                          });
                          HapticUtils.selectionClick();
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your program type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedDept,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: _selectedProgram == null
                            ? []
                            : _departments[_selectedProgram]!.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                        onChanged: _selectedProgram == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedDept = value;
                                });
                                HapticUtils.selectionClick();
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your department';
                          }
                          return null;
                        },
                        hint: Text(_selectedProgram == null
                            ? 'Select Program Type first'
                            : 'Select Department'),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedYear,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        items: _selectedProgram == null
                            ? []
                            : _yearOptions[_selectedProgram]!.map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(year),
                                );
                              }).toList(),
                        onChanged: _selectedProgram == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedYear = value;
                                });
                                HapticUtils.selectionClick();
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your year';
                          }
                          return null;
                        },
                        hint: Text(_selectedProgram == null
                            ? 'Select Program Type first'
                            : 'Select Year'),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('SAVE PROFILE'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

