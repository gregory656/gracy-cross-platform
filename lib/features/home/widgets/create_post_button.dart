import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';
import '../../../shared/models/feed_category.dart';

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
  String _selectedCategory = FeedCategories.discussions;
  bool _isAnonymous = false;
  
  // Marketplace fields
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  
  // Housing fields
  final TextEditingController _hostelNameController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _pricePerSemesterController = TextEditingController();
  bool _hasWifi = false;
  bool _hasWater = false;

  @override
  void dispose() {
    for (final image in _pendingCleanupImages) {
      if (image.existsSync()) {
        image.deleteSync();
      }
    }
    _contentController.dispose();
    _itemNameController.dispose();
    _priceController.dispose();
    _conditionController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _universityController.dispose();
    _hostelNameController.dispose();
    _distanceController.dispose();
    _pricePerSemesterController.dispose();
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
      Map<String, dynamic>? extra;
      
      if (_selectedCategory == FeedCategories.marketplace) {
        extra = {
          'item_name': _itemNameController.text.trim(),
          'price': _priceController.text.trim(),
          'condition': _conditionController.text.trim(),
          'contact': _contactController.text.trim(),
          'location': _locationController.text.trim(),
          'university': _universityController.text.trim(),
        };
      } else if (_selectedCategory == FeedCategories.housing) {
        extra = {
          'hostel_name': _hostelNameController.text.trim(),
          'distance_from_campus': _distanceController.text.trim(),
          'price_per_semester': _pricePerSemesterController.text.trim(),
          'amenities': {
            'wifi': _hasWifi,
            'water': _hasWater,
          },
        };
      }
      
      await ref.read(postsProvider.notifier).createPost(
        content: content,
        imageFile: imageToUpload,
        category: _selectedCategory,
        isAnonymous: _isAnonymous,
        extra: extra,
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
          _itemNameController.clear();
          _priceController.clear();
          _conditionController.clear();
          _contactController.clear();
          _locationController.clear();
          _universityController.clear();
          _hostelNameController.clear();
          _distanceController.clear();
          _pricePerSemesterController.clear();
          _hasWifi = false;
          _hasWater = false;
          _selectedCategory = FeedCategories.discussions;
          _isAnonymous = false;
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
        _itemNameController.clear();
        _priceController.clear();
        _conditionController.clear();
        _contactController.clear();
        _locationController.clear();
        _universityController.clear();
        _hostelNameController.clear();
        _distanceController.clear();
        _pricePerSemesterController.clear();
        _hasWifi = false;
        _hasWater = false;
        _selectedCategory = FeedCategories.discussions;
        _isAnonymous = false;
      });
      _refreshDialog();
    }

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    _queueTemporaryImage(previous);
    await _flushQueuedImages();
  }

  void _showCategorySelector() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What are you sharing today?',
                      style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Category options
              ...kFeedCategoryChips.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryOption(
                  category: category,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _selectedCategory = category.slug;
                      _isAnonymous = category.slug == FeedCategories.silentConfessions;
                    });
                    _showCreatePostDialog();
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
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
                width: MediaQuery.of(dialogContext).size.width * 0.85,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Create ${feedCategoryLabelForSlug(_selectedCategory)}',
                            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isUploading
                              ? null
                              : () => _discardDraft(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Content Input
                    TextField(
                      controller: _contentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _isAnonymous ? 'Share your confession anonymously...' : 'What\'s on your mind?',
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
                    
                    const SizedBox(height: 12),
                    
                    // Category-specific fields
                    if (_selectedCategory == FeedCategories.marketplace) ...[
                      _MarketplaceForm(
                        itemNameController: _itemNameController,
                        priceController: _priceController,
                        conditionController: _conditionController,
                        contactController: _contactController,
                        locationController: _locationController,
                        universityController: _universityController,
                      ),
                      const SizedBox(height: 12),
                    ] else if (_selectedCategory == FeedCategories.housing) ...[
                      _HousingForm(
                        hostelNameController: _hostelNameController,
                        distanceController: _distanceController,
                        pricePerSemesterController: _pricePerSemesterController,
                        hasWifi: _hasWifi,
                        hasWater: _hasWater,
                        onWifiChanged: (value) => setState(() => _hasWifi = value),
                        onWaterChanged: (value) => setState(() => _hasWater = value),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Image Preview / Picker
                    if (_selectedImage != null)
                      Container(
                        height: 150,
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
                          height: 100,
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
                
                const SizedBox(height: 12),
                
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
          onTap: isUploading ? null : _showCategorySelector,
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

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.onTap,
  });

  final FeedCategoryChip category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.icon,
                color: const Color(0xFF007AFF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.tag,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceForm extends StatelessWidget {
  const _MarketplaceForm({
    required this.itemNameController,
    required this.priceController,
    required this.conditionController,
    required this.contactController,
    required this.locationController,
    required this.universityController,
  });

  final TextEditingController itemNameController;
  final TextEditingController priceController;
  final TextEditingController conditionController;
  final TextEditingController contactController;
  final TextEditingController locationController;
  final TextEditingController universityController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marketplace Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        
        // Item Name
        TextField(
          controller: itemNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Item Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., iPhone 13, Textbooks',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Price
        TextField(
          controller: priceController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Price',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., KES 5,000',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Condition
        TextField(
          controller: conditionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Condition',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., Like New, Good, Fair',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Contact
        TextField(
          controller: contactController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Contact Info',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'Phone number or WhatsApp',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Location
        TextField(
          controller: locationController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Location',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., Nairobi CBD',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // University
        TextField(
          controller: universityController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'University',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., University of Nairobi',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
      ],
    );
  }
}

class _HousingForm extends StatelessWidget {
  const _HousingForm({
    required this.hostelNameController,
    required this.distanceController,
    required this.pricePerSemesterController,
    required this.hasWifi,
    required this.hasWater,
    required this.onWifiChanged,
    required this.onWaterChanged,
  });

  final TextEditingController hostelNameController;
  final TextEditingController distanceController;
  final TextEditingController pricePerSemesterController;
  final bool hasWifi;
  final bool hasWater;
  final Function(bool) onWifiChanged;
  final Function(bool) onWaterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Housing Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        
        // Hostel Name
        TextField(
          controller: hostelNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Hostel Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., Campus View Hostels',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Distance from Campus
        TextField(
          controller: distanceController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Distance from Campus',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., 5 minutes walk',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Price per Semester
        TextField(
          controller: pricePerSemesterController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Price per Semester',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'e.g., KES 45,000',
            hintStyle: TextStyle(color: Colors.grey[600]),
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
        ),
        const SizedBox(height: 12),
        
        // Amenities
        Text(
          'Amenities',
          style: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text(
                  'Wi-Fi',
                  style: TextStyle(color: Colors.white),
                ),
                value: hasWifi,
                onChanged: (value) => onWifiChanged(value ?? false),
                activeColor: const Color(0xFF007AFF),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: const Text(
                  'Water',
                  style: TextStyle(color: Colors.white),
                ),
                value: hasWater,
                onChanged: (value) => onWaterChanged(value ?? false),
                activeColor: const Color(0xFF007AFF),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
