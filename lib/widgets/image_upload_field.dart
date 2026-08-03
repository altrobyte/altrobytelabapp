import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// A "Banner image" field that lets admin either pick+upload a file
/// (stored server-side, no external hosting needed) or, if they already
/// have a hosted image, paste its URL directly.
class ImageUploadField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const ImageUploadField({super.key, required this.controller, this.label = 'Banner image'});

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() => _error = null);
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open file picker: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Selected file has no data — try a different file.');
      return;
    }

    setState(() { _uploading = true; _error = null; });
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final url = await ApiService.uploadImage(bytes, file.name, contentType);
      if (!mounted) return;
      setState(() {
        widget.controller.text = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _uploading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (url.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(url, height: 100, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      height: 60,
                      alignment: Alignment.center,
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: Text('Could not load image', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    )),
          ),
        ),
      TextField(
        controller: widget.controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Paste an image URL, or upload a file',
          suffixIcon: _uploading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.upload_rounded),
                  tooltip: 'Upload from device',
                  onPressed: _pickAndUpload,
                ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
        ),
    ]);
  }
}
