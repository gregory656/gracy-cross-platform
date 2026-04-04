import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class PremiumHub extends ConsumerStatefulWidget {
  const PremiumHub({super.key});

  @override
  ConsumerState<PremiumHub> createState() => _PremiumHubState();
}

class _PremiumHubState extends ConsumerState<PremiumHub> {
  bool _isGhostMode = false;
  bool _isPremium = false;
  bool _disappearingMessages = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.onyx,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _isPremium ? AppColors.electricBlue : AppColors.borderGray,
          width: _isPremium ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isPremium ? AppColors.electricBlue : AppColors.industrialGray,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _isPremium ? Icons.diamond : Icons.lock,
                  color: AppColors.pureWhite,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPremium ? 'Premium Active' : 'Upgrade to Premium',
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _isPremium 
                          ? 'Elite features unlocked'
                          : 'Unlock exclusive features',
                      style: const TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isPremium)
                ElevatedButton(
                  onPressed: _handleUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricBlue,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text(
                    'UPGRADE',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Premium Features
          if (_isPremium) ...[
            _buildFeatureToggle(
              icon: Icons.visibility_off,
              title: 'Ghost Mode',
              subtitle: 'Hide your online status from others',
              value: _isGhostMode,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _isGhostMode = value;
                });
                _updateGhostMode(value);
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureToggle(
              icon: Icons.timer_off,
              title: 'Disappearing Messages',
              subtitle: 'Messages auto-delete after 24 hours',
              value: _disappearingMessages,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _disappearingMessages = value;
                });
                _updateDisappearingMessages(value);
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureInfo(
              icon: Icons.verified,
              title: 'Blue Verification',
              subtitle: 'Get verified as a legitimate student',
              isLocked: false,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureInfo(
              icon: Icons.cloud_upload,
              title: 'Unlimited Storage',
              subtitle: 'Store unlimited messages and media',
              isLocked: false,
            ),
          ] else ...[
            // Locked features for non-premium users
            _buildFeatureInfo(
              icon: Icons.visibility_off,
              title: 'Ghost Mode',
              subtitle: 'Hide your online status from others',
              isLocked: true,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureInfo(
              icon: Icons.timer_off,
              title: 'Disappearing Messages',
              subtitle: 'Messages auto-delete after 24 hours',
              isLocked: true,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureInfo(
              icon: Icons.verified,
              title: 'Priority Verification',
              subtitle: 'Fast-track verification process',
              isLocked: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.industrialGray,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: AppColors.electricBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.electricBlue,
        ),
      ],
    );
  }

  Widget _buildFeatureInfo({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLocked,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLocked ? AppColors.industrialGray : AppColors.electricBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: isLocked ? AppColors.lightGray : AppColors.electricBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isLocked ? AppColors.lightGray : AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: isLocked ? AppColors.lightGray.withValues(alpha: 0.7) : AppColors.lightGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (isLocked)
          Icon(
            Icons.lock,
            color: AppColors.lightGray,
            size: 20,
          ),
      ],
    );
  }

  void _handleUpgrade() {
    HapticFeedback.mediumImpact();
    // Show premium upgrade dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.borderGray),
        ),
        title: const Text(
          'Upgrade to Premium',
          style: TextStyle(
            color: AppColors.pureWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock all elite features:',
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            _FeatureItem(icon: Icons.visibility_off, text: 'Ghost Mode'),
            _FeatureItem(icon: Icons.timer_off, text: 'Disappearing Messages'),
            _FeatureItem(icon: Icons.verified, text: 'Priority Verification'),
            _FeatureItem(icon: Icons.cloud_upload, text: 'Unlimited Storage'),
            SizedBox(height: 16),
            Text(
              '\$9.99/month',
              style: TextStyle(
                color: AppColors.electricBlue,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.electricBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isPremium = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricBlue,
              foregroundColor: AppColors.pureWhite,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _updateGhostMode(bool enabled) {
    // Update user's ghost mode status in database
    // This would integrate with your user service
  }

  void _updateDisappearingMessages(bool enabled) {
    // Update disappearing messages setting
    // This would integrate with your chat service
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.electricBlue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.lightGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
