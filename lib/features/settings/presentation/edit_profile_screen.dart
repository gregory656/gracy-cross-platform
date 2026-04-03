import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(
          fullName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
        );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: AppColors.background),
              SizedBox(width: 8),
              Text('Profile successfully updated!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: <Widget>[
          const SizedBox(height: 16),
          Text(
            'Full Name',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bio',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write a short bio about yourself...',
            ),
          ),
          const SizedBox(height: 32),
          CustomButton(
            label: _isLoading ? 'Saving...' : 'Save Changes',
            icon: Icons.save_rounded,
            onPressed: _isLoading ? () {} : () => _saveProfile(),
          ),
        ],
      ),
    );
  }
}
