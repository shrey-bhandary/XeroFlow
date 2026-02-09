import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;

  // Print Options
  int _copies = 1;
  bool _isColorPrint = false;
  bool _isDoubleSided = false;
  String _paperSize = 'A4';
  String _orientation = 'Portrait';

  // Pickup Slot Selection
  DateTime? _selectedSlotTime;
  List<DateTime> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableSlots();
  }

  void _generateAvailableSlots() {
    final slots = <DateTime>[];
    final now = DateTime.now();
    
    // Generate slots for the next 3 days
    for (int day = 0; day < 3; day++) {
      final date = now.add(Duration(days: day));
      
      // Slots from 9 AM to 5 PM (hourly)
      for (int hour = 9; hour <= 17; hour++) {
        final slotTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          0,
        );
        
        // Only add future slots
        if (slotTime.isAfter(now.add(const Duration(hours: 1)))) {
          slots.add(slotTime);
        }
      }
    }
    
    setState(() {
      _availableSlots = slots;
      // Default to first available slot
      if (slots.isNotEmpty) {
        _selectedSlotTime = slots.first;
      }
    });
  }

  String _formatSlotTime(DateTime slot) {
    final now = DateTime.now();
    final isToday = slot.day == now.day && slot.month == now.month && slot.year == now.year;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = slot.day == tomorrow.day && slot.month == tomorrow.month && slot.year == tomorrow.year;
    
    String dayLabel;
    if (isToday) {
      dayLabel = 'Today';
    } else if (isTomorrow) {
      dayLabel = 'Tomorrow';
    } else {
      dayLabel = '${slot.day}/${slot.month}';
    }
    
    final hour = slot.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$dayLabel, $displayHour:00 $period';
  }

  Future<void> _pickFiles() async {
    try {
      HapticUtils.mediumImpact();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    HapticUtils.lightImpact();
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadAndSubmitOrder() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select files to print',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    HapticUtils.heavyImpact();
    setState(() => _isUploading = true);

    try {
      // Upload files to Supabase Storage and get URLs
      final fileUrls = await _uploadFilesToStorage();
      
      if (fileUrls.isEmpty && _selectedFiles.isNotEmpty) {
        throw Exception('Failed to upload files');
      }

      // Add the order to the OrderService (now saves to Supabase)
      final order = await OrderService().addOrder(
        fileNames: _selectedFiles.map((f) => f.name).toList(),
        fileUrls: fileUrls,
        copies: _copies,
        isColor: _isColorPrint,
        isDoubleSided: _isDoubleSided,
        paperSize: _paperSize,
        totalAmount: _calculateEstimate(),
        slotTime: _selectedSlotTime,
      );

      setState(() => _isUploading = false);

      if (mounted && order != null) {
        _showOrderConfirmationDialog(order.orderNumber);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit order. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _uploadFilesToStorage() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null) {
      debugPrint('No user logged in for file upload');
      return [];
    }

    final fileUrls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final file in _selectedFiles) {
      try {
        Uint8List fileBytes;
        if (kIsWeb) {
          if (file.bytes == null) {
            debugPrint('File bytes are null (Web) for: ${file.name}');
            continue;
          }
          fileBytes = file.bytes!;
        } else {
          if (file.path == null) {
            debugPrint('File path is null for: ${file.name}');
            continue;
          }
          fileBytes = await File(file.path!).readAsBytes();
        }

        final fileName = '${timestamp}_${file.name}'.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final filePath = '$userId/$fileName';

        // Upload to Supabase Storage 'print-files' bucket
        await supabase.storage
            .from('print-files')
            .uploadBinary(filePath, fileBytes);

        // Get public URL
        final publicUrl = supabase.storage
            .from('print-files')
            .getPublicUrl(filePath);

        fileUrls.add(publicUrl);
        debugPrint('Uploaded: $filePath -> $publicUrl');
      } catch (e) {
        debugPrint('Error uploading file ${file.name}: $e');
        // Continue with other files even if one fails
      }
    }

    return fileUrls;
  }

  void _showOrderConfirmationDialog(String orderNumber) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Order Submitted!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  orderNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your print order has been submitted. Track it in the Orders tab!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedFiles = [];
                    _copies = 1;
                    _isColorPrint = false;
                    _isDoubleSided = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.green;
      default:
        return AppTheme.primaryBlue;
    }
  }

  int _calculateEstimate() {
    int basePrice = _isColorPrint ? 10 : 2;
    int totalPages = _selectedFiles.length * _copies;
    if (_isDoubleSided) {
      totalPages = (totalPages / 2).ceil();
    }
    return basePrice * totalPages;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Gradient Header (matching Dashboard)
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryOrange,
                    AppTheme.darkOrange,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Print Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Upload Files',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          // Info Icon
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                HapticUtils.lightImpact();
                                _showInfoBottomSheet();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Upload Stats
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildHeaderStat(
                              icon: Icons.insert_drive_file_rounded,
                              label: 'Files',
                              value: '${_selectedFiles.length}',
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildHeaderStat(
                              icon: Icons.copy_rounded,
                              label: 'Copies',
                              value: '$_copies',
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildHeaderStat(
                              icon: Icons.currency_rupee_rounded,
                              label: 'Estimate',
                              value: '₹${_selectedFiles.isEmpty ? 0 : _calculateEstimate()}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Upload Area Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Files',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildUploadCard(isDark),
                ],
              ),
            ),
          ),

          // Selected Files Section
          if (_selectedFiles.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Files (${_selectedFiles.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedFiles = []);
                          },
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_selectedFiles.length, (index) {
                      final file = _selectedFiles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFileCard(file, index, isDark),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Print Options Section
          if (_selectedFiles.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Print Options',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildOptionsCard(isDark),
                  ],
                ),
              ),
            ),

          // Submit Button
          if (_selectedFiles.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildSubmitButton(isDark),
              ),
            ),

          // Quick Actions (When No Files)
          if (_selectedFiles.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported Formats',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormatCard(
                            icon: Icons.picture_as_pdf_rounded,
                            label: 'PDF',
                            color: Colors.red,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormatCard(
                            icon: Icons.description_rounded,
                            label: 'DOC',
                            color: Colors.blue,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormatCard(
                            icon: Icons.image_rounded,
                            label: 'Images',
                            color: Colors.green,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Tips Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _buildTipsCard(isDark),
            ),
          ),

          // Bottom Padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickFiles,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryOrange.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryOrange.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.15),
                      AppTheme.primaryBlue.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 48,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tap to Select Files',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF, DOC, DOCX, JPG, PNG',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(PlatformFile file, int index, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getFileIconColor(file.extension).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getFileIcon(file.extension),
              color: _getFileIconColor(file.extension),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(file.size),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeFile(index),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Copies
          _buildOptionRow(
            icon: Icons.copy_rounded,
            label: 'Copies',
            isDark: isDark,
            child: Row(
              children: [
                _buildCounterButton(
                  icon: Icons.remove,
                  onPressed: _copies > 1
                      ? () => setState(() => _copies--)
                      : null,
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_copies',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                _buildCounterButton(
                  icon: Icons.add,
                  onPressed: _copies < 100
                      ? () => setState(() => _copies++)
                      : null,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          _buildDivider(isDark),
          // Color Print
          _buildOptionRow(
            icon: Icons.palette_rounded,
            label: 'Color Print',
            isDark: isDark,
            child: Switch.adaptive(
              value: _isColorPrint,
              onChanged: (value) {
                HapticUtils.selectionClick();
                setState(() => _isColorPrint = value);
              },
              activeColor: AppTheme.primaryOrange,
            ),
          ),
          _buildDivider(isDark),
          // Double Sided
          _buildOptionRow(
            icon: Icons.flip_rounded,
            label: 'Double Sided',
            isDark: isDark,
            child: Switch.adaptive(
              value: _isDoubleSided,
              onChanged: (value) {
                HapticUtils.selectionClick();
                setState(() => _isDoubleSided = value);
              },
              activeColor: AppTheme.primaryOrange,
            ),
          ),
          _buildDivider(isDark),
          // Paper Size
          _buildOptionRow(
            icon: Icons.straighten_rounded,
            label: 'Paper Size',
            isDark: isDark,
            child: _buildDropdown(
              value: _paperSize,
              items: ['A4', 'A3', 'Letter', 'Legal'],
              onChanged: (value) => setState(() => _paperSize = value!),
              isDark: isDark,
            ),
          ),
          _buildDivider(isDark),
          // Pickup Slot
          _buildSlotSelector(isDark),
        ],
      ),
    );
  }

  Widget _buildSlotSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.schedule_rounded, color: AppTheme.primaryBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              'Pickup Slot',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableSlots.length,
            itemBuilder: (context, index) {
              final slot = _availableSlots[index];
              final isSelected = _selectedSlotTime == slot;
              
              return GestureDetector(
                onTap: () {
                  HapticUtils.selectionClick();
                  setState(() => _selectedSlotTime = slot);
                },
                child: Container(
                  margin: EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryBlue 
                        : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      _formatSlotTime(slot),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required bool isDark,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 24,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onPressed,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed != null
            ? AppTheme.primaryOrange.withOpacity(0.12)
            : (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: onPressed != null
              ? AppTheme.primaryOrange
              : (isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Column(
      children: [
        // Price Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryOrange.withOpacity(0.1),
                AppTheme.primaryBlue.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryOrange.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primaryOrange,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Total Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${_calculateEstimate()}',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadAndSubmitOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primaryOrange.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isUploading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Submitting...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.print_rounded, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Submit Print Order',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Tips',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('PDF files give the best print quality', isDark),
          _buildTipItem('Double-sided printing saves paper & money', isDark),
          _buildTipItem('B&W prints: ₹2/page • Color: ₹10/page', isDark),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'How it works',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoStep('1', 'Select your files', 'PDF, DOC, or images', isDark),
            _buildInfoStep('2', 'Choose print options', 'Copies, color, paper size', isDark),
            _buildInfoStep('3', 'Submit your order', 'Pay at the xerox shop', isDark),
            _buildInfoStep('4', 'Pick up your prints', 'Within shop hours', isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoStep(String number, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
