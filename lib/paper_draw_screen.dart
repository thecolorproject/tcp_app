import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'share_card_screen.dart';

class PaperDrawScreen extends StatefulWidget {
  const PaperDrawScreen({super.key});

  @override
  State<PaperDrawScreen> createState() => _PaperDrawScreenState();
}

class _PaperDrawScreenState extends State<PaperDrawScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);

      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => _isLoading = false);
        return;
      }

      final cropped = await ImageCropper().cropImage(
  sourcePath: picked.path,
  uiSettings: [
    AndroidUiSettings(
      toolbarTitle: 'Crop your drawing',
      aspectRatioPresets: [
        CropAspectRatioPreset.original,
      ],
    ),
    IOSUiSettings(
      title: 'Crop your drawing',
      aspectRatioPresets: [
        CropAspectRatioPreset.original,
      ],
    ),
    WebUiSettings(
      context: context,
      size: const CropperSize(width: 900, height: 1200),
    ),
  ],
);

      if (cropped == null) {
        setState(() => _isLoading = false);
        return;
      }

      final bytes = await File(cropped.path).readAsBytes();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShareCardScreen(
            drawingBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Paper draw error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 처리 중 오류가 발생했어요')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Draw'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload your drawing',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showPicker,
                    icon: const Icon(Icons.upload),
                    label: const Text('Select Image'),
                  ),
                ],
              ),
      ),
    );
  }
}