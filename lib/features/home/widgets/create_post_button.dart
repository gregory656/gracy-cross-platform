import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';

class CreatePostButton extends ConsumerStatefulWidget {
  const CreatePostButton({
    super.key,
    this.expanded = false,
    this.promptText,
  });

  final bool expanded;
  final String? promptText;

  @override
  ConsumerState<CreatePostButton> createState() => _CreatePostButtonState();
}

class _CreatePostButtonState extends ConsumerState<CreatePostButton> {
  static const Color _fabColor = Color(0xFF007AFF);
  final TextEditingController _contentController = TextEditingController();
  final List<File> _pendingCleanupImages = <File>[];
  StateSetter? _dialogSetState;
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    for (final image in _pendingCleanupImages) {
      if (image.existsSync()) {
        image.deleteSync();
      }
    }
    _contentController.dispose();
    super.dispose();
  }

  void _refreshDialog() {
    final dialogSetState = _dialogSetState;
    if (dialogSetState != null) {
      dialogSetState(() {});
    }
  }

  Future<void> _pickImage() async {
    try {
      final postService = ref.read(optimizedPostServiceProvider);
      final sourceImage = await postService.pickImage();

      if (sourceImage != null) {
        final optimizedImage = await postService.compressSelectedImage(
          sourceImage,
        );

        if (optimizedImage == null) {
          throw Exception('Image optimization failed');
        }

        final previousImage = _selectedImage;

        if (!mounted) {
          await _deleteTemporaryImage(optimizedImage);
          return;
        }

        setState(() {
          _selectedImage = optimizedImage;
        });
        _refreshDialog();

        _queueTemporaryImage(previousImage);
        if (optimizedImage.path != sourceImage.path) {
          _queueTemporaryImage(sourceImage);
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

  Future<void> _createPost(BuildContext dialogContext) async {
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
    final content = _contentController.text.trim();
    final imageToUpload = _selectedImage;

    setState(() {
      _isUploading = true;
    });
    _refreshDialog();

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    await Future<void>.delayed(Duration.zero);

    try {
      await ref.read(postsProvider.notifier).createPost(
        content: content,
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
        String errorMessage = e.toString().replaceFirst(
          'Exception: Failed to create post: ',
          '',
        );
        if (errorMessage.trim().isEmpty) {
          errorMessage = 'Failed to create post';
        }
        
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
      _queueTemporaryImage(imageToUpload);
      await _flushQueuedImages();
      await _deleteTemporaryImage(imageToUpload);
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _isUploading = false;
          _contentController.clear();
        });
        _refreshDialog();
      }
    }
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

  void _queueTemporaryImage(File? image) {
    if (image == null) {
      return;
    }

    final alreadyQueued = _pendingCleanupImages.any(
      (queuedImage) => queuedImage.path == image.path,
    );
    if (!alreadyQueued) {
      _pendingCleanupImages.add(image);
    }
  }

  Future<void> _flushQueuedImages() async {
    final filesToDelete = List<File>.from(_pendingCleanupImages);
    _pendingCleanupImages.clear();

    for (final image in filesToDelete) {
      await _deleteTemporaryImage(image);
    }
  }

  Future<void> _discardDraft(BuildContext dialogContext) async {
    final previous = _selectedImage;
    if (mounted) {
      setState(() {
        _selectedImage = null;
        _contentController.clear();
      });
      _refreshDialog();
    }

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    _queueTemporaryImage(previous);
    await _flushQueuedImages();
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal during upload
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          _dialogSetState = dialogSetState;

          return Dialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF333333)),
            ),
            child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
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
                      style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _isUploading
                          ? null
                          : () => _discardDraft(dialogContext),
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
                            onTap: _isUploading
                                ? null
                                : () async {
                                    final previous = _selectedImage;
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                    _refreshDialog();
                                    _queueTemporaryImage(previous);
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
                    onTap: _isUploading ? null : _pickImage,
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
                            'Tap to attach',
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
                        onPressed: _isUploading
                            ? null
                            : () => _discardDraft(dialogContext),
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
                        onPressed: _isUploading
                            ? null
                            : () => _createPost(dialogContext),
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
          );
        },
      ),
    ).whenComplete(() {
      _dialogSetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final isUploading = postsAsync is AsyncLoading ||
        (postsAsync.hasValue && ref.read(postsProvider.notifier).progress > 0);

    if (widget.expanded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploading ? null : _showCreatePostDialog,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.promptText ?? "What's on your mind?",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _fabColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: _fabColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
