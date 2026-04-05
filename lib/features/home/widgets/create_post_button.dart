import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../providers/post_providers.dart';

class CreatePostButton extends ConsumerStatefulWidget {
  const CreatePostButton({super.key});

  @override
  ConsumerState<CreatePostButton> createState() => _CreatePostButtonState();
}

class _CreatePostButtonState extends ConsumerState<CreatePostButton> {
  static const Color _fabColor = Color(0xFF007AFF);
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    try {
      final postService = ref.read(optimizedPostServiceProvider);
      final image = await postService.pickImage();

      if (image != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: _fabColor,
              toolbarWidgetColor: Colors.black,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              backgroundColor: Colors.black,
              activeControlsWidgetColor: _fabColor,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio16x9,
                CropAspectRatioPreset.original,
              ],
            ),
            IOSUiSettings(
              title: 'Crop Image',
              cancelButtonTitle: 'Cancel',
              doneButtonTitle: 'Done',
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio16x9,
                CropAspectRatioPreset.original,
              ],
            ),
          ],
        );

        if (croppedFile != null) {
          final optimizedImage = await postService.compressSelectedImage(
            File(croppedFile.path),
          );

          if (optimizedImage == null) {
            throw Exception('Image optimization failed');
          }

          await _disposeSelectedImage();

          setState(() {
            _selectedImage = optimizedImage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add content or an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isUploading = true;
    });

    await Future<void>.delayed(Duration.zero);

    final imageToUpload = _selectedImage;
    _selectedImage = null;
    await _disposePreviewImage(imageToUpload);
    navigator.pop();

    try {
      await ref.read(postsProvider.notifier).createPost(
        content: _contentController.text.trim(),
        imageFile: imageToUpload,
      );

      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to create post';
        
        if (e.toString().contains('timeout')) {
          errorMessage = 'Upload timed out. Check your connection.';
        } else if (e.toString().contains('compression')) {
          errorMessage = 'Image compression failed. Try a different image.';
        } else if (e.toString().contains('upload')) {
          errorMessage = 'Upload failed. Please try again.';
        }
        
        messenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _deleteTemporaryImage(imageToUpload);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _contentController.clear();
        });
      }
    }
  }

  Future<void> _disposePreviewImage(File? image) async {
    if (image == null) {
      return;
    }

    final provider = FileImage(image);
    await provider.evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _deleteTemporaryImage(File? image) async {
    if (image == null) {
      return;
    }

    try {
      if (await image.exists()) {
        await image.delete();
      }
    } catch (_) {}
  }

  Future<void> _disposeSelectedImage() async {
    final previous = _selectedImage;
    _selectedImage = null;
    await _disposePreviewImage(previous);
    await _deleteTemporaryImage(previous);
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal during upload
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'Create Post',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Content Input
                TextField(
                  controller: _contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF444444)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 5,
                  minLines: 3,
                  readOnly: _isUploading, // Disable input during upload
                ),
                
                const SizedBox(height: 16),
                
                // Image Preview / Picker
                if (_selectedImage != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            cacheWidth: 1080,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _isUploading ? null : () {
                              _disposeSelectedImage();
                              setState(() {});
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _isUploading ? null : _pickAndCropImage,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: _isUploading ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: TextStyle(
                              color: _isUploading ? Colors.grey[600] : Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to crop & edit',
                            style: TextStyle(
                              color: _isUploading ? Colors.grey[700] : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF333333)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _isUploading ? Colors.grey[600] : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _fabColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[600],
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Post',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final isUploading = postsAsync is AsyncLoading ||
        (postsAsync.hasValue && ref.read(postsProvider.notifier).progress > 0);

    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: isUploading ? null : _showCreatePostDialog,
        tooltip: 'Create post',
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: _fabColor,
          disabledForegroundColor: Colors.grey[600],
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(
          Icons.attach_file,
          size: 26,
        ),
      ),
    );
  }
}
