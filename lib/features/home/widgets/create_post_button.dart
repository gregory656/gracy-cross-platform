import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/post_providers.dart';
import '../../../shared/widgets/upload_progress_overlay.dart';


class CreatePostButton extends ConsumerStatefulWidget {
  const CreatePostButton({super.key});

  @override
  ConsumerState<CreatePostButton> createState() => _CreatePostButtonState();
}

class _CreatePostButtonState extends ConsumerState<CreatePostButton> {
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
        // Show cropping dialog
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: const Color(0xFF00D4FF),
              toolbarWidgetColor: Colors.black,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              backgroundColor: Colors.black,
              activeControlsWidgetColor: const Color(0xFF00D4FF),
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
          setState(() {
            _selectedImage = File(croppedFile.path);
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

    // Close the dialog first, but wait for it to complete
    Navigator.of(context).pop();
    
    // Add a small delay to ensure dialog is fully closed
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _isUploading = true;
    });

    try {
      await ref.read(postsProvider.notifier).createPost(
        content: _contentController.text.trim(),
        imageFile: _selectedImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedImage = null;
          _contentController.clear();
        });
      }
    }
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
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _isUploading ? null : () {
                              setState(() {
                                _selectedImage = null;
                              });
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
                          backgroundColor: const Color(0xFF00D4FF),
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
    // Watch upload progress from the posts notifier
    final postsAsync = ref.watch(postsProvider);
    final isUploading = postsAsync is AsyncLoading || 
        (postsAsync.hasValue && ref.read(postsProvider.notifier).progress > 0);
    
    double uploadProgress = 0.0;
    String uploadStatus = '';
    
    if (postsAsync.hasValue) {
      uploadProgress = ref.read(postsProvider.notifier).progress;
      uploadStatus = ref.read(postsProvider.notifier).status;
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: isUploading ? null : _showCreatePostDialog,
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
              elevation: 0,
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ),
        
        // Upload progress overlay
        if (isUploading && uploadProgress > 0)
          Positioned.fill(
            child: UploadProgressOverlay(
              progress: uploadProgress,
              status: uploadStatus,
            ),
          ),
      ],
    );
  }
}
