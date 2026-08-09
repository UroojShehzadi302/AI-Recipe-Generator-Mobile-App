import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/markdown_text.dart';
import '../core/widgets/primary_button.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/recipe_provider.dart';
import 'recipe_detail_screen.dart';

/// The "Ask AI" tab: an AI Hub with two modes — **Generate** (prompt → recipe)
/// and **Chat** (cooking assistant) — per design decision D1.
///
/// Both modes are backed by already-wired providers ([RecipeProvider.generate]
/// and [ChatProvider.sendMessage]); this screen is pure presentation. The two
/// views live in an [IndexedStack] so switching modes preserves their state
/// (a typed prompt or an in-progress conversation is never lost).
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  int _mode = 0; // 0 = Generate, 1 = Chat.

  void _select(int i) => setState(() => _mode = i);

  void _newChat() {
    context.read<ChatProvider>().newChat();
  }

  Future<void> _openHistory() async {
    final String? uid = context.read<AuthProvider>().uid;
    final ChatProvider chat = context.read<ChatProvider>();
    if (uid == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Sign in to save and view chat history'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    await chat.loadSessions(uid);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => _HistorySheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: const <Widget>[
                  _GenerateView(),
                  _ChatView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceL,
        AppDimensions.spaceL,
        AppDimensions.spaceL,
        AppDimensions.spaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(child: Text('AI Kitchen', style: AppTextStyles.title)),
              // Chat-only actions.
              if (_mode == 1) ...<Widget>[
                IconButton(
                  onPressed: _newChat,
                  tooltip: 'New chat',
                  icon: Icon(Icons.add_comment_outlined,
                      color: AppColors.primary),
                ),
                IconButton(
                  onPressed: _openHistory,
                  tooltip: 'Chat history',
                  icon: Icon(Icons.history, color: AppColors.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spaceL),
          _ModeToggle(mode: _mode, onSelect: _select),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mode toggle (Generate | Chat)
// -----------------------------------------------------------------------------

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onSelect});

  final int mode;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceXs),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          _segment('Generate', Icons.restaurant_menu, 0),
          _segment('Chat', Icons.chat_bubble_outline, 1),
        ],
      ),
    );
  }

  Widget _segment(String label, IconData icon, int index) {
    final bool selected = mode == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceM),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spaceS),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Generate mode
// -----------------------------------------------------------------------------

class _GenerateView extends StatefulWidget {
  const _GenerateView();

  @override
  State<_GenerateView> createState() => _GenerateViewState();
}

class _GenerateViewState extends State<_GenerateView> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  static const List<String> _examples = <String>[
    'Vegan pasta for two',
    'High-protein breakfast',
    'Quick 15-minute dinner',
    'Gluten-free chocolate dessert',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recipeProvider = context.read<RecipeProvider>();
    final recipe = await recipeProvider.generate(_controller.text.trim());
    if (!mounted) return;

    if (recipe != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(recipeProvider.genError ?? 'Could not generate a recipe'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.select<RecipeProvider, bool>(
      (p) => p.genStatus == LoadStatus.loading,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceL,
        AppDimensions.spaceS,
        AppDimensions.spaceL,
        // Clears the floating nav bar.
        AppDimensions.navBarClearance,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What would you like to cook?',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              'Describe a dish, ingredients you have, or a craving — the AI will '
              'create a full recipe.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppDimensions.spaceL),
            AppTextField(
              controller: _controller,
              label: 'Your recipe idea',
              icon: Icons.auto_awesome,
              textInputAction: TextInputAction.done,
              validator: Validators.aiPrompt,
            ),
            const SizedBox(height: AppDimensions.spaceL),
            Text(
              'Need inspiration?',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceS),
            Wrap(
              spacing: AppDimensions.spaceS,
              runSpacing: AppDimensions.spaceS,
              children: <Widget>[
                for (final String example in _examples)
                  _SuggestionChip(
                    label: example,
                    onTap: isLoading
                        ? null
                        : () {
                            _controller.text = example;
                          },
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXl),
            PrimaryButton(
              text: 'GENERATE RECIPE',
              isLoading: isLoading,
              onPressed: isLoading ? null : _generate,
            ),
            if (isLoading) ...<Widget>[
              const SizedBox(height: AppDimensions.spaceL),
              Center(
                child: Text(
                  'Cooking up your recipe…',
                  style: AppTextStyles.subtitle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chat mode
// -----------------------------------------------------------------------------

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const List<String> _starters = <String>[
    'What can I make with eggs and spinach?',
    'A substitute for butter in baking?',
    'How do I cook fluffy rice?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final String text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    // Guard the outbound Gemini call. The composer caps input length in the UI,
    // but a paste or a preset can still exceed it, and an unbounded prompt is
    // billable quota this project does not have.
    final String? tooLong = Validators.aiPrompt(text);
    if (tooLong != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tooLong)),
      );
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();
    final String? uid = context.read<AuthProvider>().uid;
    await context.read<ChatProvider>().sendMessage(text, uid: uid);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;
    final bool isSending = chat.isSending;

    // Keep the newest message in view as the conversation grows.
    if (messages.isNotEmpty || isSending) _scrollToBottom();

    return Column(
      children: <Widget>[
        Expanded(
          child: messages.isEmpty && !isSending
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spaceL,
                    AppDimensions.spaceS,
                    AppDimensions.spaceL,
                    AppDimensions.spaceL,
                  ),
                  itemCount: messages.length + (isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(message: messages[index]);
                  },
                ),
        ),
        _buildComposer(isSending),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: AppDimensions.spaceXl),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined,
                color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: AppDimensions.spaceL),
          Text(
            'Your cooking assistant',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          Text(
            'Ask about recipes, ingredients, substitutions, or techniques.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceXl),
          for (final String starter in _starters) ...<Widget>[
            _StarterCard(label: starter, onTap: () => _send(starter)),
            const SizedBox(height: AppDimensions.spaceM),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(bool isSending) {
    return Container(
      // The shell sets `extendBody: true`, so the white surface runs all the
      // way to the bottom of the screen and the floating nav bar sits ON it.
      // An outer margin here instead would stop the white short of the bottom
      // and leave a visible seam with a bare strip of background below it.
      //
      // The gap therefore goes UNDER the input row as bottom padding, using
      // navBarOverlap (bar height + margin) rather than the larger
      // navBarClearance — the latter is sized for scrollables that must clear
      // the bar completely, and here it pushed the field visibly too high.
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.card,
      ),
      // No SafeArea: the nav bar consumes the bottom system inset inside its
      // own SafeArea, and navBarClearance already covers its height + margins.
      // Adding one here would count the gesture inset twice.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spaceM,
          AppDimensions.spaceM,
          AppDimensions.spaceM,
          AppDimensions.navBarOverlap,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                // Same ceiling the Generate tab enforces. counterText is
                // blanked so the composer keeps its compact look; the limit
                // still stops over-long input at the source.
                maxLength: Validators.aiPromptMaxLength,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: AppColors.primary,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Ask anything about cooking…',
                  hintStyle: AppTextStyles.subtitle,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceL,
                    vertical: AppDimensions.spaceM,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceS),
            _SendButton(
              onPressed: isSending ? null : _send,
              isSending: isSending,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Private sub-widgets
// -----------------------------------------------------------------------------

/// Tappable suggestion pill used under the generate prompt.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceM,
            vertical: AppDimensions.spaceS,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single chat bubble, aligned by author.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == ChatRole.user;
    final double maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceL,
          vertical: AppDimensions.spaceM,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppDimensions.radiusLg),
            topRight: const Radius.circular(AppDimensions.radiusLg),
            bottomLeft: Radius.circular(
                isUser ? AppDimensions.radiusLg : AppDimensions.spaceXs),
            bottomRight: Radius.circular(
                isUser ? AppDimensions.spaceXs : AppDimensions.radiusLg),
          ),
          boxShadow: isUser ? null : AppShadows.card,
        ),
        // The user's own text is literal (render as typed); the AI reply may
        // contain markdown, so render it.
        child: isUser
            ? SelectableText(
                message.text,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              )
            : MarkdownText(
                data: message.text,
                baseStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              ),
      ),
    );
  }
}

/// Animated three-dot "assistant is typing" bubble.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceL,
          vertical: AppDimensions.spaceM,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimensions.radiusLg),
            topRight: Radius.circular(AppDimensions.radiusLg),
            bottomLeft: Radius.circular(AppDimensions.spaceXs),
            bottomRight: Radius.circular(AppDimensions.radiusLg),
          ),
          boxShadow: AppShadows.card,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(3, (int i) {
                // Stagger each dot's opacity across the animation cycle.
                final double t = (_controller.value - i * 0.2) % 1.0;
                final double opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Tappable conversation-starter card shown in the empty chat state.
class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceL),
          child: Row(
            children: <Widget>[
              Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.secondary, size: 20),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(child: Text(label, style: AppTextStyles.body)),
              Icon(Icons.north_east,
                  color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the user's saved conversations.
class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    // Cap the sheet height and let the list scroll within it.
    final double maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppDimensions.spaceM),
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceL),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spaceM),
                  Text('Chat history', style: AppTextStyles.title),
                ],
              ),
            ),
            Flexible(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  final List<ChatSession> sessions = chat.sessions;
                  if (sessions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spaceL,
                        0,
                        AppDimensions.spaceL,
                        AppDimensions.spaceXxl,
                      ),
                      child: Text(
                        'No saved conversations yet. Start chatting and your '
                        'chats will appear here.',
                        style: AppTextStyles.subtitle,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spaceL,
                    ),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final ChatSession session = sessions[index];
                      return ListTile(
                        leading: Icon(Icons.chat_bubble_outline,
                            color: AppColors.primary),
                        title: Text(
                          session.title.isEmpty ? 'Conversation' : session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: session.lastMessage.isEmpty
                            ? null
                            : Text(
                                session.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption,
                              ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: AppColors.textSecondary),
                          tooltip: 'Delete',
                          onPressed: () =>
                              chat.deleteSession(uid, session.id),
                        ),
                        onTap: () async {
                          await chat.openChat(uid, session.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular send button in the chat composer.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed, required this.isSending});

  final VoidCallback? onPressed;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? AppColors.secondary : AppColors.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: isSending
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
