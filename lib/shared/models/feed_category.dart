import 'package:flutter/material.dart';

/// Values stored in Supabase `posts.category` (text).
abstract final class FeedCategories {
  const FeedCategories._();

  static const String silentConfessions = 'silent_confessions';
  static const String discussions = 'discussions';
  static const String marketplace = 'marketplace';
  static const String housing = 'housing';
  static const String eventsParties = 'events_parties';
  static const String projects = 'projects';

  static const List<String> allSlugs = <String>[
    silentConfessions,
    discussions,
    marketplace,
    housing,
    eventsParties,
    projects,
  ];
}

/// UI metadata for the horizontal chip bar (excluding synthetic "All").
class FeedCategoryChip {
  const FeedCategoryChip({
    required this.slug,
    required this.label,
    required this.tag,
    required this.icon,
  });

  final String slug;
  final String label;

  /// Short hashtag shown on cards in the global "All" feed (e.g. #Marketplace).
  final String tag;
  final IconData icon;
}

/// Chip definitions for the campus super-app feed.
const List<FeedCategoryChip> kFeedCategoryChips = <FeedCategoryChip>[
  FeedCategoryChip(
    slug: FeedCategories.silentConfessions,
    label: 'Silent Confessions',
    tag: '#Confession',
    icon: Icons.nights_stay_outlined,
  ),
  FeedCategoryChip(
    slug: FeedCategories.discussions,
    label: 'Discussions',
    tag: '#Discussion',
    icon: Icons.forum_outlined,
  ),
  FeedCategoryChip(
    slug: FeedCategories.marketplace,
    label: 'Marketplace',
    tag: '#Marketplace',
    icon: Icons.storefront_outlined,
  ),
  FeedCategoryChip(
    slug: FeedCategories.housing,
    label: 'Housing',
    tag: '#Housing',
    icon: Icons.home_work_outlined,
  ),
  FeedCategoryChip(
    slug: FeedCategories.eventsParties,
    label: 'Events/Parties',
    tag: '#Events',
    icon: Icons.celebration_outlined,
  ),
  FeedCategoryChip(
    slug: FeedCategories.projects,
    label: 'Projects',
    tag: '#Projects',
    icon: Icons.rocket_launch_outlined,
  ),
];

String feedCategoryTagForSlug(String slug) {
  for (final FeedCategoryChip c in kFeedCategoryChips) {
    if (c.slug == slug) {
      return c.tag;
    }
  }
  return '#Campus';
}

String feedCategoryLabelForSlug(String slug) {
  for (final FeedCategoryChip c in kFeedCategoryChips) {
    if (c.slug == slug) {
      return c.label;
    }
  }
  return 'Campus';
}
