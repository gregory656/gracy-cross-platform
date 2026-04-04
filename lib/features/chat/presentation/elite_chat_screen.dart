import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/elite_chat_providers.dart';
import '../widgets/elite_message_bubble.dart';
import '../widgets/elite_long_press_menu.dart';
import '../widgets/nairobi_date_header.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/services/nairobi_timezone_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/elite_animations.dart';

class EliteChatScreen extends ConsumerStatefulWidget {
  const EliteChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  final String chatId;
  final String chatName;

  @override
  ConsumerState<EliteChatScreen> createState() => _EliteChatScreenState();
}

class _EliteChatScreenState extends ConsumerState<EliteChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _composerAnimationController;
  String? _replyingToMessageId;
  MessageModel? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _composerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _composerAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    EliteHaptics.mediumImpact();
    ref.read(eliteChatProvider(widget.chatId).notifier).sendMessage(
      text,
      replyToId: _replyingToMessageId,
    );

    _messageController.clear();
    _clearReply();
    _scrollToBottom();
  }

  void _handleMessageLongPress(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: EliteLongPressMenu(
          message: message,
          onActionSelected: (action) {
            _handleMenuAction(action, message);
          },
        ),
      ),
    );
  }

  void _handleMenuAction(EliteMenuAction action, MessageModel message) {
    switch (action) {
      case EliteMenuAction.reply:
        setState(() {
          _replyingToMessageId = message.id;
          _replyingToMessage = message;
        });
        _composerAnimationController.forward();
        FocusScope.of(context).requestFocus(FocusNode());
        break;
      case EliteMenuAction.copy:
        EliteMenuActions.handleCopy(message);
        break;
      case EliteMenuAction.forward:
        EliteMenuActions.handleShare(message);
        break;
      case EliteMenuAction.delete:
        EliteMenuActions.handleDelete(context, message);
        break;
    }
  }

  void _clearReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToMessage = null;
    });
    _composerAnimationController.reverse();
  }

  Widget _buildMessageList(List<MessageModel> messages) {
    final timezoneService = NairobiTimezoneService.instance;
    DateTime? lastDate;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final messageDate = timezoneService.toNairobiTime(message.sentAt);
        
        // Check if we need a date header
        bool showDateHeader = false;
        if (lastDate == null || !timezoneService.isSameDay(lastDate!, messageDate)) {
          showDateHeader = true;
          lastDate = messageDate;
        }

        return Column(
          children: [
            if (showDateHeader) NairobiDateHeader(date: messageDate),
            EliteMessageBubble(
              message: message,
              onLongPress: () => _handleMessageLongPress(message),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingToMessage == null) return const SizedBox.shrink();

    return SizeTransition(
      sizeFactor: _composerAnimationController,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.industrialGray,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.borderGray,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.electricBlue,
                borderRadius: BorderRadius.all(Radius.circular(1.5)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Replying to ${_replyingToMessage!.senderName}',
                        style: const TextStyle(
                          color: AppColors.electricBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      EliteAnimatedButton(
                        onPressed: _clearReply,
                        hapticType: HapticType.light,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.lightGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _replyingToMessage!.text,
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.onyx,
        border: Border(
          top: BorderSide(
            color: AppColors.borderGray,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Reply preview
          _buildReplyPreview(),
          
          // Message input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.industrialGray,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.borderGray,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              EliteAnimatedButton(
                onPressed: _handleSendMessage,
                hapticType: HapticType.medium,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.send,
                    color: AppColors.pureWhite,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(eliteChatProvider(widget.chatId));
    final timezoneService = NairobiTimezoneService.instance;

    return Scaffold(
      backgroundColor: AppColors.onyx,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chatName,
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            if (chatState.isTyping)
              const Text(
                'typing...',
                style: TextStyle(
                  color: AppColors.electricBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              EliteHaptics.lightImpact();
              // Show chat options
            },
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.pureWhite,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Nairobi timezone indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.industrialGray,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderGray,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.electricBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  '${timezoneService.formatTime(timezoneService.now)} ${timezoneService.timezoneOffset}',
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Message list
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.electricBlue,
                    ),
                  )
                : chatState.error != null
                    ? Center(
                        child: Text(
                          'Error: ${chatState.error}',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : _buildMessageList(chatState.messages),
          ),
          
          // Message composer
          _buildMessageComposer(),
        ],
      ),
    );
  }
}
