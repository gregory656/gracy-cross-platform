import '../../core/constants/app_links.dart';
import '../models/post_model.dart';

String buildPostShareText(PostModel post) {
  final String caption = _normalizedCaption(post.content);
  final String intro = caption.isEmpty
      ? 'Check out this post on Gracy.'
      : 'Check out this post on Gracy: $caption';

  return '$intro\n\n${AppLinks.postUri(post.id)}\n\nJoin the network: ${AppLinks.playStoreUrl}';
}

String _normalizedCaption(String value) {
  final String collapsed = value
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .join(' ')
      .trim();

  if (collapsed.length <= 140) {
    return collapsed;
  }

  return '${collapsed.substring(0, 137).trimRight()}...';
}
