// ECG PDF Editor - Flutter Android App
// Edits patient details (Name, Age, Gender, BP) in ECG PDF reports
//
// Dependencies (add to pubspec.yaml):
//   file_picker: ^6.1.1
//   pdf: ^3.10.7
//   printing: ^5.11.1
//   path_provider: ^2.1.1
//   open_file: ^3.3.2
//   permission_handler: ^11.1.0

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(const ECGEditorApp());
}

class ECGEditorApp extends StatelessWidget {
  const ECGEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Report Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFEF4444),
          surface: const Color(0xFF0F172A),
          background: const Color(0xFF020817),
        ),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      home: const ECGEditorScreen(),
    );
  }
}

class PatientInfo {
  String name;
  String age;
  String gender;
  String bpSystolic;
  String bpDiastolic;

  PatientInfo({
    this.name = '',
    this.age = '',
    this.gender = 'Male',
    this.bpSystolic = '',
    this.bpDiastolic = '',
  });

  String get bp => '$bpSystolic/$bpDiastolic mmHg';
  bool get isValid =>
      name.isNotEmpty &&
      age.isNotEmpty &&
      bpSystolic.isNotEmpty &&
      bpDiastolic.isNotEmpty;
}

class ECGEditorScreen extends StatefulWidget {
  const ECGEditorScreen({super.key});

  @override
  State<ECGEditorScreen> createState() => _ECGEditorScreenState();
}

class _ECGEditorScreenState extends State<ECGEditorScreen> {
  int _step = 0; // 0=upload, 1=edit, 2=done
  File? _selectedFile;
  String _fileName = '';
  final PatientInfo _patient = PatientInfo();
  bool _isSaving = false;
  String? _outputPath;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _step = 1;
      });
    }
  }

  Future<void> _savePDF() async {
    if (!_patient.isValid) {
      _showSnack('Please fill in all fields');
      return;
    }
    setState(() => _isSaving = true);

    try {
      // Read the original PDF bytes
      final Uint8List originalBytes = await _selectedFile!.readAsBytes();

      // Load original PDF and create new one with updated info overlay
      final pdf = pw.Document();
      final pdfDoc = await PdfDocument.openData(originalBytes);

      for (int i = 0; i < pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i + 1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
        );
        final image = await pageImage.createImageIfNotAvailable();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (pw.Context ctx) {
              return pw.Stack(
                children: [
                  // Original PDF page as image
                  pw.Image(pw.MemoryImage(image.bytes)),
                  // Patient info overlay on first page
                  if (i == 0)
                    pw.Positioned(
                      top: 30,
                      left: 20,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.red),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _infoRow('Name', _patient.name),
                            _infoRow('Age', '${_patient.age} yrs'),
                            _infoRow('Gender', _patient.gender),
                            _infoRow('BP', _patient.bp),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
        await page.close();
      }

      // Save to Downloads
      final dir = await getExternalStorageDirectory();
      final outputFile = File(
        '${dir!.path}/ECG_${_patient.name.replaceAll(' ', '_')}_edited.pdf',
      );
      await outputFile.writeAsBytes(await pdf.save());

      setState(() {
        _outputPath = outputFile.path;
        _step = 2;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Error: ${e.toString()}');
    }
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _reset() {
    setState(() {
      _step = 0;
      _selectedFile = null;
      _fileName = '';
      _outputPath = null;
      _nameCtrl.clear();
      _ageCtrl.clear();
      _bpSysCtrl.clear();
      _bpDiaCtrl.clear();
      _patient.name = '';
      _patient.age = '';
      _patient.gender = 'Male';
      _patient.bpSystolic = '';
      _patient.bpDiastolic = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.favorite, color: Color(0xFFEF4444), size: 24),
        ),
        title: const Text(
          'ECG Report Editor',
          style: TextStyle(
            color: Color(0xFFF1F5F9),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildUploadStep();
      case 1:
        return _buildEditStep();
      case 2:
        return _buildDoneStep();
      default:
        return _buildUploadStep();
    }
  }

  Widget _buildUploadStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _pickPDF,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1E293B), width: 2),
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF0F172A),
            ),
            child: const Column(
              children: [
                Icon(Icons.picture_as_pdf, size: 64, color: Color(0xFFEF4444)),
                SizedBox(height: 16),
                Text(
                  'Select ECG PDF',
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to browse your files',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF475569), size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit Name, Age, Gender & BP in your ECG report without regenerating the whole PDF.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fileName,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _reset,
                child: const Icon(Icons.close, color: Color(0xFF475569), size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildField(
          label: 'PATIENT NAME',
          icon: Icons.person_outline,
          controller: _nameCtrl,
          onChanged: (v) => _patient.name = v,
          hint: 'Enter full name',
        ),
        _buildField(
          label: 'AGE',
          icon: Icons.cake_outlined,
          controller: _ageCtrl,
          onChanged: (v) => _patient.age = v,
          hint: 'Enter age',
          keyboardType: TextInputType.number,
          suffix: 'yrs',
        ),

        // Gender
        const SizedBox(height: 4),
        _label('GENDER', Icons.medical_services_outlined),
        const SizedBox(height: 8),
        Row(
          children: ['Male', 'Female', 'Other'].map((g) {
            final selected = _patient.gender == g;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _patient.gender = g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEF4444).withOpacity(0.12)
                          : const Color(0xFF0F172A),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF1E293B),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      g,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // BP
        _label('BLOOD PRESSURE', Icons.favorite_outline),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _bpField(
                controller: _bpSysCtrl,
                hint: '120',
                label: 'Systolic',
                onChanged: (v) => _patient.bpSystolic = v,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '/',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: _bpField(
                controller: _bpDiaCtrl,
                hint: '80',
                label: 'Diastolic',
                onChanged: (v) => _patient.bpDiastolic = v,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'mmHg',
                style: TextStyle(color: Color(0xFF475569), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _savePDF,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 8,
              shadowColor: const Color(0xFFEF4444).withOpacity(0.4),
            ),
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Saving...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  )
                : const Text(
                    'SAVE & EXPORT PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 72),
        const SizedBox(height: 16),
        const Text(
          'PDF Updated!',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Patient details applied successfully',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        const SizedBox(height: 28),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              _summaryRow('NAME', _patient.name),
              _summaryRow('AGE', '${_patient.age} yrs'),
              _summaryRow('GENDER', _patient.gender),
              _summaryRow('BP', _patient.bp),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_outputPath != null) OpenFile.open(_outputPath!);
            },
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text(
              'OPEN / SHARE PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1E293B), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Edit Another PDF',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String? hint,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, icon),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 15),
          decoration: InputD
