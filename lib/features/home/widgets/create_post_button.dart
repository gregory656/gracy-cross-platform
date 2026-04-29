import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';
import '../../../shared/models/feed_category.dart';

class CreatePostButton extends ConsumerStatefulWidget {
  const CreatePostButton({super.key, this.expanded = false, this.promptText});

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
  final TextEditingController _pricePerSemesterController =
      TextEditingController();
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
          'amenities': {'wifi': _hasWifi, 'water': _hasWater},
        };
      }

      await ref
          .read(postsProvider.notifier)
          .createPost(
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
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0B0D10),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Color(0xFF1E2228))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Share with Gracy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a category to reach the right people.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Flexible(
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: kFeedCategoryChips
                    .map(
                      (category) => Material(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            setState(() {
                              _selectedCategory = category.slug;
                              _isAnonymous =
                                  category.slug ==
                                  FeedCategories.silentConfessions;
                            });
                            _showCreatePostSheet();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  color: category.color,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          _dialogSetState = dialogSetState;
          final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
          final totalHeight = MediaQuery.of(dialogContext).size.height;
          final sheetHeight = totalHeight * 0.9;

          return Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Color(0xFF0B0D10),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Color(0xFF1E2228))),
            ),
            child: Column(
              children: [
                // Minimal Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _isUploading
                            ? null
                            : () => _discardDraft(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Text(
                        'New ${feedCategoryLabelForSlug(_selectedCategory)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : () => _createPost(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _fabColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Post',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Caption takes ~60% of focus
                        TextField(
                          controller: _contentController,
                          maxLines: null,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: _isAnonymous
                                ? 'Speak your mind anonymously...'
                                : 'What\'s on your mind?',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                          ),
                          readOnly: _isUploading,
                        ),

                        const SizedBox(height: 24),

                        // Form Metadata if applicable
                        if (_selectedCategory ==
                            FeedCategories.marketplace) ...[
                          _MarketplaceForm(
                            itemNameController: _itemNameController,
                            priceController: _priceController,
                            conditionController: _conditionController,
                            contactController: _contactController,
                            locationController: _locationController,
                            universityController: _universityController,
                          ),
                        ] else if (_selectedCategory ==
                            FeedCategories.housing) ...[
                          _HousingForm(
                            hostelNameController: _hostelNameController,
                            distanceController: _distanceController,
                            pricePerSemesterController:
                                _pricePerSemesterController,
                            hasWifi: _hasWifi,
                            hasWater: _hasWater,
                            onWifiChanged: (value) =>
                                setState(() => _hasWifi = value),
                            onWaterChanged: (value) =>
                                setState(() => _hasWater = value),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Large Image Preview (30% vertical weight)
                        if (_selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: _isUploading
                                        ? null
                                        : () {
                                            final previous = _selectedImage;
                                            setState(
                                              () => _selectedImage = null,
                                            );
                                            _refreshDialog();
                                            _queueTemporaryImage(previous);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
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
                              height: keyboardHeight > 0 ? 100 : 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 48,
                                    color: _fabColor.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Enhance with Photo',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: keyboardHeight + 20),
                      ],
                    ),
                  ),
                ),
              ],
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
    final isUploading =
        postsAsync is AsyncLoading ||
        (postsAsync.hasValue && ref.read(postsProvider.notifier).progress > 0);

    if (widget.expanded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploading ? null : _showCategorySheet,
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
        onPressed: isUploading ? null : _showCategorySheet,
        tooltip: 'Create post',
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: _fabColor,
          disabledForegroundColor: Colors.grey[600],
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.attach_file, size: 26),
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
