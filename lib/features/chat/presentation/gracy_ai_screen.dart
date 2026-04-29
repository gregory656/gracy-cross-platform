import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/elite_animations.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/gemini_service.dart';
import '../widgets/gemini_ai_interface.dart';
import '../widgets/elite_chat_composer.dart';
import '../widgets/gracy_ai_logo.dart';
import '../widgets/neural_thinking_indicator.dart';

class GracyAIScreen extends ConsumerStatefulWidget {
  const GracyAIScreen({super.key, this.chatId});

  final String? chatId;

  @override
  ConsumerState<GracyAIScreen> createState() => _GracyAIScreenState();
}

class _GracyAIScreenState extends ConsumerState<GracyAIScreen>
    with TickerProviderStateMixin {
  static const String _localChatId = 'gracy-ai-local';
  static const String _assistantId = 'gracy-ai';
  static const String _assistantName = 'GracyAI';
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _composerAnimationController;

  bool _isAiThinking = false;
  Timer? _thinkingTimer;
  final List<MessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _composerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Add welcome message
    _messages.add(
      MessageModel(
        id: 'welcome',
        chatId: widget.chatId ?? _localChatId,
        senderId: _assistantId,
        text:
            "Hello! I am GracyAI, your campus intelligence. How can I help you dominate your studies or campus life today?",
        sentAt: DateTime.now(),
        isMe: false,
        senderName: _assistantName,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _composerAnimationController.dispose();
    _thinkingTimer?.cancel();
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

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final authState = ref.read(authNotifierProvider);
    final currentUserId = authState.userId;
    if (currentUserId == null) {
      return;
    }
    final String currentUserName = authState.fullName?.trim().isNotEmpty == true
        ? authState.fullName!.trim()
        : authState.username?.trim().isNotEmpty == true
        ? authState.username!.trim()
        : 'You';

    EliteHaptics.mediumImpact();

    setState(() {
      _isAiThinking = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Start thinking animation
    _thinkingTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isAiThinking = true;
        });
      }
    });

    try {
      // Add user message to list
      final userMsg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: widget.chatId ?? _localChatId,
        senderId: currentUserId,
        text: text,
        sentAt: DateTime.now(),
        isMe: true,
        senderName: currentUserName,
      );

      setState(() {
        _messages.add(userMsg);
        _isAiThinking = true;
      });
      _scrollToBottom();

      // Generate AI response
      final responseText = await GeminiService().generateResponse(
        text,
        userMessage: text,
        conversationHistory: _messages,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            MessageModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              chatId: widget.chatId ?? _localChatId,
              senderId: _assistantId,
              text: responseText,
              sentAt: DateTime.now(),
              isMe: false,
              senderName: _assistantName,
            ),
          );
          _isAiThinking = false;
        });
        _scrollToBottom();
      }
    } catch (error) {
      debugPrint('AI response error: $error');
      if (mounted) {
        setState(() {
          _messages.add(
            MessageModel(
              id: 'offline-${DateTime.now().millisecondsSinceEpoch}',
              chatId: widget.chatId ?? _localChatId,
              senderId: _assistantId,
              text: GeminiService.offlineMaintenanceMessage,
              sentAt: DateTime.now(),
              isMe: false,
              senderName: _assistantName,
            ),
          );
          _isAiThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  Widget _buildMessageList(List<MessageModel> messages) {
    if (messages.isEmpty && !_isAiThinking) {
      return GeminiAIInterface(
        onSendMessage: () => _handleSendMessage(),
        isEmpty: true,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length + (_isAiThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && _isAiThinking) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NeuralThinkingIndicator(),
          );
        }

        final message = messages[index];
        return _buildGlassmorphismMessage(message);
      },
    );
  }

  Widget _buildGlassmorphismMessage(MessageModel message) {
    final isUser = message.isMe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              child: const GracyAILogo(size: 32, glowing: true),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.electricBlue.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUser
                      ? AppColors.electricBlue.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.electricBlue.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isUser ? AppColors.electricBlue : Colors.white,
                        height: 1.4,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w900),
                      code: TextStyle(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        fontFamily: 'monospace',
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.sentAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.electricBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: AppColors.electricBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.userId;

    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.electricBlue),
        ),
      );
    }

    // For now, we'll use a mock messages list
    // In a real implementation, this would come from a provider
    final messages = _messages;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            EliteHaptics.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.chat);
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            const GracyAILogo(size: 32, glowing: true),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GracyAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Online • Ready to help',
                  style: TextStyle(
                    color: AppColors.electricBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              EliteHaptics.lightImpact();
              // Show AI settings or options
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Neural Network Background Effect
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.electricBlue.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Messages or Gemini Interface
          Expanded(child: _buildMessageList(messages)),

          // Message Composer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: EliteChatComposer(
              controller: _messageController,
              onSend: _handleSendMessage,
              hintText: 'Ask me anything about campus...',
            ),
          ),
        ],
      ),
    );
  }
}
