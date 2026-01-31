import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// A button for picking images from gallery or camera.
class ImagePickerButton extends StatelessWidget {
  const ImagePickerButton({
    super.key,
    required this.onImagePicked,
    this.enabled = true,
  });

  final ValueChanged<Uint8List> onImagePicked;
  final bool enabled;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();

    try {
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();

      // Decode and re-encode as JPEG to ensure format
      final image = img.decodeImage(bytes);
      if (image == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to decode image')),
          );
        }
        return;
      }

      final jpegBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));
      onImagePicked(jpegBytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? () => _showPickerOptions(context) : null,
      icon: const Icon(Icons.image),
      tooltip: 'Attach image',
    );
  }
}

/// A button for recording audio.
class AudioRecorderButton extends StatefulWidget {
  const AudioRecorderButton({
    super.key,
    required this.onAudioRecorded,
    this.enabled = true,
  });

  final ValueChanged<Uint8List> onAudioRecorded;
  final bool enabled;

  @override
  State<AudioRecorderButton> createState() => _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends State<AudioRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _tempPath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _startRecording() async {
    if (!await _checkPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _tempPath =
            '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: _tempPath!,
        );

        setState(() => _isRecording = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        widget.onAudioRecorded(bytes);

        // Clean up temp file
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.enabled
          ? (_isRecording ? _stopRecording : _startRecording)
          : null,
      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
      color: _isRecording ? Theme.of(context).colorScheme.error : null,
      tooltip: _isRecording ? 'Stop recording' : 'Record audio',
    );
  }
}
