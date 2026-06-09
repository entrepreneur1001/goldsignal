import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groq/groq.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/api_config.dart';
import '../../../../core/utils/currency_conversion.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../../../shared/models/metal_price.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/providers/chat_history_provider.dart';
import '../../../portfolio/presentation/screens/portfolio_screen.dart';
import 'chat_history_screen.dart';

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

  @override
  void initState() {
    super.initState();
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

  ChatMessage _welcomeMessage() {
    return ChatMessage(
      text: "Hello! I'm your gold and silver investment assistant. I can help you with:\n\n"
          "• Market insights and price analysis\n"
          "• Investment strategies (DCA, timing)\n"
          "• Jewelry pricing and fairness checks\n"
          "• Answering questions about precious metals\n"
          "• Portfolio analysis and recommendations\n"
          "• Scam detection and claim verification\n\n"
          "How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _openHistory() async {
    final before = ref.read(chatHistoryProvider).activeId;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final history = ref.read(chatHistoryProvider.notifier);

    // Persist the user message (creates a conversation on first send).
    await history.appendMessage(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
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
        text: "I apologize, but I encountered an error. Please check your internet connection and try again.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      if (mounted) setState(() => _isTyping = false);
    }
  }

  String _buildSystemPrompt(MetalPrice? gold, MetalPrice? silver, String currency) {
    String priceContext = "";
    final isLocal = currency == 'EGP';
    final local = ref.read(localMarketPricesProvider);
    final side = ref.read(priceSideProvider);

    if (isLocal && local != null) {
      priceContext += buildLocalMarketPrompt(local, side);
      priceContext += " Headline 21K gold ${side.name} price: ${local.headlineGold?.priceFor(side).toStringAsFixed(2) ?? 'N/A'} EGP/g. ";
    } else {
      if (gold != null) {
        priceContext += "Current gold price: $currency ${gold.pricePerOunce.toStringAsFixed(2)}/oz ($currency ${gold.pricePerGram.toStringAsFixed(2)}/g). ";
        priceContext += "24h change: ${gold.formattedChangePercent}. ";
      }
      if (silver != null) {
        priceContext += "Current silver price: $currency ${silver.pricePerOunce.toStringAsFixed(2)}/oz ($currency ${silver.pricePerGram.toStringAsFixed(2)}/g). ";
      }
    }

    // Build portfolio context
    final rates = ref.read(metalPriceApiProvider).getCachedPrices()?.rates;
    String portfolioContext = _buildPortfolioContext(gold, silver, currency, rates);

    return """You are a knowledgeable and helpful precious metals investment assistant specialized in gold and silver.
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

    Keep responses concise and actionable. Use bullet points when listing multiple items.""";
  }

  String _buildPortfolioContext(
    MetalPrice? gold,
    MetalPrice? silver,
    String currency,
    Map<String, double>? rates,
  ) {
    final isLocal = currency == 'EGP';
    final local = ref.read(localMarketPricesProvider);
    try {
      if (!Hive.isBoxOpen('portfolio')) return "";
      final box = Hive.box<PortfolioItem>('portfolio');
      if (box.isEmpty) return "User has no portfolio holdings yet.";

      double purchaseInDisplay(PortfolioItem item) {
        final raw = item.purchasePrice * item.weight;
        if (rates == null) return raw;
        return convertWithUsdBaseRates(
              raw,
              item.purchaseCurrency,
              currency,
              rates,
            ) ??
            raw;
      }

      final items = box.values.toList();
      double totalCurrentValue = 0;
      double totalPurchaseCost = 0;
      final holdings = <String>[];

      for (final item in items) {
        final price = item.metal == 'Gold' ? gold : silver;
        final purchaseCost = purchaseInDisplay(item);
        totalPurchaseCost += purchaseCost;

        double currentValue = 0;
        if (isLocal && local != null) {
          if (item.metal == 'Gold') {
            final perGram = localGoldPortfolioPrice(local, item.karat.round());
            if (perGram != null) currentValue = perGram * item.weight;
          } else {
            final perGram = localSilverPortfolioPrice(local, item.karat.round());
            if (perGram != null) currentValue = perGram * item.weight;
          }
          totalCurrentValue += currentValue;
        } else if (price != null) {
          final karatMultiplier = item.karat / 24;
          currentValue = price.getPricePerGram() * karatMultiplier * item.weight;
          totalCurrentValue += currentValue;
        }

        final pl = currentValue - purchaseCost;
        final plPercent = purchaseCost > 0 ? (pl / purchaseCost * 100) : 0.0;
        holdings.add(
          "${item.weight}g ${item.metal} ${item.karat}K (bought at ${item.purchasePrice.toStringAsFixed(2)}/${item.purchaseCurrency}/g, current value in $currency: ${currentValue.toStringAsFixed(2)}, P/L: ${plPercent >= 0 ? '+' : ''}${plPercent.toStringAsFixed(1)}%)",
        );
      }

      final totalPL = totalCurrentValue - totalPurchaseCost;
      final totalPLPercent = totalPurchaseCost > 0 ? (totalPL / totalPurchaseCost * 100) : 0.0;

      return """User's portfolio (${items.length} holding${items.length > 1 ? 's' : ''}):
${holdings.map((h) => "- $h").join("\n")}
Total purchase cost: $currency ${totalPurchaseCost.toStringAsFixed(2)}
Total current value: $currency ${totalCurrentValue.toStringAsFixed(2)}
Total P/L: ${totalPLPercent >= 0 ? '+' : ''}${totalPLPercent.toStringAsFixed(1)}% ($currency ${totalPL.toStringAsFixed(2)})""";
    } catch (e) {
      return "";
    }
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
    final messages =
        storedMessages.isEmpty ? [_welcomeMessage()] : storedMessages;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gold AI Assistant'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          const AlertsNavButton(),
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New chat',
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
                  _buildQuickAction("📈 Today's Analysis", "Explain today's gold price movement"),
                  _buildQuickAction("💎 Jewelry Check", "Is 50g 21K gold for \$3000 fair?"),
                  _buildQuickAction("📊 DCA Plan", "Create a \$1000/month gold buying plan"),
                  _buildQuickAction("💼 My Portfolio", "How is my portfolio doing? Any recommendations?"),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessage(messages[index]);
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
                        hintText: 'Ask about gold investments...',
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
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFFB800),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isTyping ? null : _sendMessage,
                    ),
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFFFFB800),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFFFB800)
                    : isDark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : isDark
                          ? Colors.white
                          : Colors.black87,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 16,
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
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
            backgroundColor: const Color(0xFFFFB800),
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

