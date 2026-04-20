import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_model.dart';

enum ChatVisibility { visible, hidden, archived, deleted }

class ChatVisibilityNotifier extends Notifier<Map<String, ChatVisibility>> {
  @override
  Map<String, ChatVisibility> build() => <String, ChatVisibility>{};

  Future<void> setVisibility(String roomId, ChatVisibility visibility) async {
    state = {...state, roomId: visibility};
  }

  Future<void> loadVisibilityFromDatabase() async {}
}

final chatVisibilityProvider = NotifierProvider<ChatVisibilityNotifier, Map<String, ChatVisibility>>(
  ChatVisibilityNotifier.new,
);

final localReadChatsProvider = NotifierProvider<LocalReadChatsNotifier, Map<String, DateTime>>(
  LocalReadChatsNotifier.new,
);

class LocalReadChatsNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => <String, DateTime>{};

  void markRead(String roomId) {
    state = {...state, roomId: DateTime.now()};
  }
}

final locallyReadNotificationIdsProvider = NotifierProvider<LocalReadNotificationIdsNotifier, Set<int>>(
  LocalReadNotificationIdsNotifier.new,
);

class LocalReadNotificationIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void markRead(int id) {
    state = {...state, id};
  }
}

class EliteChatState {
  const EliteChatState({
    this.messages = const <MessageModel>[],
    this.isLoading = false,
    this.isTyping = false,
    this.error,
  });

  final List<MessageModel> messages;
  final bool isLoading;
  final bool isTyping;
  final Object? error;

  EliteChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isTyping,
    Object? error,
  }) {
    return EliteChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
      error: error ?? this.error,
    );
  }
}
