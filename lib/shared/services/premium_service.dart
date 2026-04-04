import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum PremiumTier { free, premium }

enum PremiumFeature { ghostMode, disappearingMessages, verifiedBadge, prioritySupport }

extension PremiumTierExtension on PremiumTier {
  String get name {
    switch (this) {
      case PremiumTier.free:
        return 'Free';
      case PremiumTier.premium:
        return 'Premium';
    }
  }

  String get description {
    switch (this) {
      case PremiumTier.free:
        return 'Basic features for everyday use';
      case PremiumTier.premium:
        return 'Unlock all premium features';
    }
  }

  String get price {
    switch (this) {
      case PremiumTier.free:
        return 'KES 0/month';
      case PremiumTier.premium:
        return 'KES 299/month';
    }
  }

  List<PremiumFeature> get features {
    switch (this) {
      case PremiumTier.free:
        return [];
      case PremiumTier.premium:
        return PremiumFeature.values;
    }
  }
}

extension PremiumFeatureExtension on PremiumFeature {
  String get name {
    switch (this) {
      case PremiumFeature.ghostMode:
        return 'Ghost Mode';
      case PremiumFeature.disappearingMessages:
        return 'Disappearing Messages';
      case PremiumFeature.verifiedBadge:
        return 'Blue Verified Badge';
      case PremiumFeature.prioritySupport:
        return 'Priority Support';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.ghostMode:
        return 'Hide your online status from others';
      case PremiumFeature.disappearingMessages:
        return 'Set messages to disappear after viewing';
      case PremiumFeature.verifiedBadge:
        return 'Get a blue verification badge';
      case PremiumFeature.prioritySupport:
        return 'Get faster customer support';
    }
  }

  IconData get icon {
    switch (this) {
      case PremiumFeature.ghostMode:
        return Icons.visibility_off_rounded;
      case PremiumFeature.disappearingMessages:
        return Icons.timer_rounded;
      case PremiumFeature.verifiedBadge:
        return Icons.verified_rounded;
      case PremiumFeature.prioritySupport:
        return Icons.support_agent_rounded;
    }
  }
}

final premiumServiceProvider = Provider<PremiumService>((ref) => PremiumService());

class PremiumService {
  // IntaSend configuration
  static const String _sandboxUrl = 'https://sandbox.intasend.co.ke';
  
  Future<bool> startSubscription(PremiumTier tier) async {
    if (tier == PremiumTier.free) {
      return true; // Free tier doesn't need payment
    }

    final String checkoutUrl = _generateCheckoutUrl(tier);
    
    try {
      final Uri uri = Uri.parse(checkoutUrl);
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        // In a real app, you would listen for webhook callbacks
        // to confirm the subscription was successful
        return await _simulatePaymentSuccess();
      }
      return false;
    } catch (e) {
      // Handle error silently
      // print('Error checking premium status: $e');
      return false;
    }
  }

  String _generateCheckoutUrl(PremiumTier tier) {
    // This is a placeholder URL. In a real implementation,
    // you would generate a proper IntaSend checkout URL
    // with the correct parameters for your product
    
    switch (tier) {
      case PremiumTier.premium:
        return '$_sandboxUrl/checkout?product=gracy_premium&amount=29900&currency=KES';
      case PremiumTier.free:
        return '';
    }
  }

  Future<bool> _simulatePaymentSuccess() async {
    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 3));
    
    // In a real implementation, this would be handled by webhook callbacks
    // from IntaSend confirming the payment was successful
    return true;
  }

  Future<void> showPremiumDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const PremiumSubscriptionDialog(),
    );
  }

  bool hasFeature(PremiumFeature feature, PremiumTier currentTier) {
    return currentTier.features.contains(feature);
  }
}

class PremiumSubscriptionDialog extends StatelessWidget {
  const PremiumSubscriptionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Premium',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Unlock all features',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...PremiumTier.values.map((tier) => _TierCard(tier: tier)),
            const SizedBox(height: 16),
            Text(
              'Payment processed securely by IntaSend',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});

  final PremiumTier tier;

  @override
  Widget build(BuildContext context) {
    final bool isPremium = tier == PremiumTier.premium;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPremium 
              ? Colors.amber 
              : Theme.of(context).dividerTheme.color ?? Colors.grey,
          width: isPremium ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isPremium 
            ? Colors.amber.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPremium ? Colors.amber[800] : null,
                ),
              ),
              if (isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tier.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            tier.price,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPremium ? Colors.amber[800] : null,
            ),
          ),
          if (tier.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...tier.features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    feature.icon,
                    size: 16,
                    color: isPremium ? Colors.amber[800] : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Handle subscription
              },
              style: FilledButton.styleFrom(
                backgroundColor: isPremium ? Colors.amber : null,
                foregroundColor: isPremium ? Colors.black : null,
              ),
              child: Text(isPremium ? 'Subscribe Now' : 'Current Plan'),
            ),
          ),
        ],
      ),
    );
  }
}
