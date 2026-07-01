import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groq/groq.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/ai/portfolio_context_builder.dart';
import '../../../../core/utils/api_config.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/portfolio_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../../../shared/widgets/ad_list_builder.dart';
import '../../../../shared/widgets/native_ad_widget.dart';
import '../../../../shared/models/metal_price.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/providers/chat_history_provider.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import 'chat_history_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late Groq _groq;

  /// Whether the input has sendable (non-whitespace) content.
  bool get _canSend => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Rebuild so the send button reflects whether there's text to send.
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
    _groq = Groq(
      apiKey: ApiConfig.groqApiKey,
      configuration: Configuration(
        model: 'llama-3.3-70b-versatile',
        maxCompletionTokens: 1000,
        temperature: 0.7,
      ),
    );
    _groq.startChat();
  }

  ChatMessage _welcomeMessage(BuildContext context) {
    return ChatMessage(
      text: context.tr('chatbot.welcome'),
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _openHistory() async {
    final before = ref.read(chatHistoryProvider).activeId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ChatHistory'),
        builder: (_) => const ChatHistoryScreen(),
      ),
    );
    if (!mounted) return;
    final after = ref.read(chatHistoryProvider).activeId;
    if (before != after) {
      // Switched to a different (or new) conversation: reset the model's
      // in-memory context. The displayed history is preserved via the store.
      _groq.clearChat();
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // TODO(i18n): dev-facing setup/config message (only shown when the build has
  // no Groq key) — intentionally not localized.
  static const _groqSetupMessage =
      'AI chat is not configured. To enable it:\n\n'
      '1. Copy secrets.json.example to secrets.json\n'
      '2. Add your Groq API key (gsk_...) from console.groq.com/keys\n'
      '3. Run or build with:\n'
      '   flutter run --dart-define-from-file=secrets.json\n\n'
      'Rebuild after changing the key.';

  String _groqErrorMessage(GroqException e) {
    final lower = e.message.toLowerCase();
    if (e is AuthenticationError ||
        (lower.contains('invalid') && lower.contains('api key')) ||
        lower.contains('unauthorized') ||
        lower.contains('authentication')) {
      return 'Groq API key is missing or invalid.\n\n'
          '• Check your key at console.groq.com/keys\n'
          '• Update GROQ_API_KEY in secrets.json\n'
          '• Rebuild with: flutter run --dart-define-from-file=secrets.json\n\n'
          'Details: ${e.message}';
    }
    return 'I apologize, but I encountered an error: ${e.message}';
  }

  /// Free messages a guest (anonymous user) may send before the sign-in wall.
  static const _guestFreeMessages = 3;

  /// Returns true if the message may be sent. Registered users are unlimited;
  /// anonymous guests get [_guestFreeMessages] then must create an account.
  Future<bool> _ensureCanChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return true;

    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt('ai_guest_used') ?? 0;
    if (used < _guestFreeMessages) {
      await prefs.setInt('ai_guest_used', used + 1);
      return true;
    }
    if (!mounted) return false;
    return requireAccount(context, 'ai_chat');
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Resolve localized fallback now, before any async gap uses context.
    final genericError = context.tr('chatbot.error_generic');

    // Guests get a short free trial, then must create an account to continue.
    if (!await _ensureCanChat()) return;

    final history = ref.read(chatHistoryProvider.notifier);

    // Persist the user message (creates a conversation on first send).
    await history.appendMessage(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    AnalyticsService.instance.logEvent('chat_message_sent');
    _messageController.clear();
    if (mounted) setState(() => _isTyping = true);

    // Scroll to bottom
    _scrollToBottom();

    if (ApiConfig.groqApiKey.isEmpty) {
      await history.appendMessage(ChatMessage(
        text: _groqSetupMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
      return;
    }

    try {
      // Get current prices and portfolio for context
      final goldPrice = ref.read(metalPriceProvider);
      final silverPrice = ref.read(silverPriceProvider);
      final currency = ref.read(selectedCurrencyProvider);

      // Update system prompt with latest context
      final systemPrompt = _buildSystemPrompt(goldPrice, silverPrice, currency);
      _groq.setCustomInstructionsWith(systemPrompt);

      // Send to Groq
      final response = await _groq.sendMessage(message);

      // Persist the AI response
      await history.appendMessage(ChatMessage(
        text: response.choices.first.message.content,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (mounted) setState(() => _isTyping = false);

      _scrollToBottom();
    } on GroqException catch (e) {
      await history.appendMessage(ChatMessage(
        text: _groqErrorMessage(e),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (mounted) setState(() => _isTyping = false);
    } catch (e) {
      await history.appendMessage(ChatMessage(
        text: genericError,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (mounted) setState(() => _isTyping = false);
    }
  }

  String _buildSystemPrompt(MetalPrice? gold, MetalPrice? silver, String currency) {
    String priceContext = '';
    final isLocal = currency == 'EGP';
    final local = ref.read(localMarketPricesProvider);
    final side = ref.read(priceSideProvider);

    if (isLocal && local != null) {
      priceContext += buildLocalMarketPrompt(local, side);
      priceContext += " Headline 21K gold ${side.name} price: ${local.headlineGold?.priceFor(side).toStringAsFixed(2) ?? 'N/A'} EGP/g. ";
    } else {
      if (gold != null) {
        priceContext += 'Current gold price: $currency ${gold.pricePerOunce.toStringAsFixed(2)}/oz ($currency ${gold.pricePerGram.toStringAsFixed(2)}/g). ';
        priceContext += '24h change: ${gold.formattedChangePercent}. ';
      }
      if (silver != null) {
        priceContext += 'Current silver price: $currency ${silver.pricePerOunce.toStringAsFixed(2)}/oz ($currency ${silver.pricePerGram.toStringAsFixed(2)}/g). ';
      }
    }

    // Build portfolio context
    final rates = ref.read(metalPriceApiProvider).getCachedPrices()?.rates;
    String portfolioContext = _buildPortfolioContext(gold, silver, currency, rates);

    return '''You are a knowledgeable and helpful precious metals investment assistant specialized in gold and silver.
    You provide accurate, practical advice about gold/silver investments, market analysis, and jewelry pricing.

    $priceContext
    $portfolioContext

    Guidelines:
    1. Provide educational information, not financial advice
    2. Be accurate with current prices and calculations
    3. Consider cultural context (support for Arab markets, Zakat calculations, etc.)
    4. Help detect scams and verify claims with evidence
    5. Explain complex concepts simply
    6. For jewelry: Consider making charges, VAT, and fair pricing
    7. Always include disclaimers when discussing investments
    8. When the user asks about their portfolio, reference the portfolio data above
    9. Respond in the same language the user writes in (Arabic, English, etc.)

    Keep responses concise and actionable. Use bullet points when listing multiple items.''';
  }

  String _buildPortfolioContext(
    MetalPrice? gold,
    MetalPrice? silver,
    String currency,
    Map<String, double>? rates,
  ) {
    final items = ref.read(portfolioProvider).asData?.value ?? const [];
    return buildPortfolioContext(
      items: items,
      gold: gold,
      silver: silver,
      currency: currency,
      rates: rates,
      local: ref.read(localMarketPricesProvider),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final storedMessages = ref.watch(chatHistoryProvider).activeMessages;
    final showWelcome = storedMessages.isEmpty;
    final adContentCount = showWelcome ? 0 : storedMessages.length;
    final listItemCount =
        (showWelcome ? 1 : adListItemCount(adContentCount)) +
        (_isTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr('chatbot.assistant_title')),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          const AlertsNavButton(),
          IconButton(
            tooltip: context.tr('chatbot.chat_history'),
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: context.tr('chatbot.new_chat'),
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              ref.read(chatHistoryProvider.notifier).startNewChat();
              _groq.clearChat();
              _scrollToBottom();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (ApiConfig.groqApiKey.isEmpty)
              Material(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    // TODO(i18n): dev-facing config banner, not localized
                    'Groq API key not set. Run with --dart-define-from-file=secrets.json',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            // Quick Actions
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildQuickAction(context.tr('chatbot.qa_analysis_label'),
                      context.tr('chatbot.qa_analysis_prompt')),
                  _buildQuickAction(context.tr('chatbot.qa_jewelry_label'),
                      context.tr('chatbot.qa_jewelry_prompt')),
                  _buildQuickAction(context.tr('chatbot.qa_dca_label'),
                      context.tr('chatbot.qa_dca_prompt')),
                  _buildQuickAction(context.tr('chatbot.qa_portfolio_label'),
                      context.tr('chatbot.qa_portfolio_prompt')),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: listItemCount,
                itemBuilder: (context, index) {
                  if (_isTyping && index == listItemCount - 1) {
                    return _buildTypingIndicator();
                  }
                  if (showWelcome) {
                    return _buildMessage(_welcomeMessage(context));
                  }
                  if (adListIndexIsAd(index, adContentCount)) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: NativeAdWidget.list(),
                    );
                  }
                  return _buildMessage(
                    storedMessages[adListContentIndex(index, adContentCount)],
                  );
                },
              ),
            ),

            // Input Field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: context.tr('chatbot.input_hint'),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) =>
                          (_canSend && !_isTyping) ? _sendMessage() : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(builder: (context) {
                    final enabled = _canSend && !_isTyping;
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: enabled ? VaultColors.goldGradient : null,
                        color: enabled
                            ? null
                            : (isDark ? Colors.grey[800] : Colors.grey[300]),
                        shape: BoxShape.circle,
                      ),
                      child: _isTyping
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1410),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                color: enabled
                                    ? const Color(0xFF1A1410)
                                    : (isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[500]),
                              ),
                              onPressed: enabled ? _sendMessage : null,
                            ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          _messageController.text = prompt;
          _sendMessage();
        },
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: VaultColors.gold,
              radius: 16,
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser ? VaultColors.goldGradient : null,
                color: isUser ? null : c.bgSurface,
                border: isUser ? null : Border.all(color: c.hairline),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  height: 1.4,
                  color: isUser ? const Color(0xFF1A1410) : c.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: c.bgElevated,
              radius: 16,
              child: Icon(
                Icons.person,
                size: 16,
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: VaultColors.gold,
            radius: 16,
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }
}

