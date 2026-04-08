import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_openai/dart_openai.dart';
import '../../../../core/utils/api_config.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/models/metal_price.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Initialize OpenAI
    OpenAI.apiKey = ApiConfig.openAiApiKey;
    
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hello! I'm your gold and silver investment assistant. I can help you with:\n\n"
          "• Market insights and price analysis\n"
          "• Investment strategies (DCA, timing)\n"
          "• Jewelry pricing and fairness checks\n"
          "• Answering questions about precious metals\n"
          "• Scam detection and claim verification\n\n"
          "How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isTyping = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Get current gold price for context
      final goldPrice = ref.read(metalPriceProvider);
      final silverPrice = ref.read(silverPriceProvider);
      
      // Create context-aware system message
      String systemPrompt = _buildSystemPrompt(goldPrice, silverPrice);

      // Send to OpenAI
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
            ],
          ),
          ..._messages.map((msg) => OpenAIChatCompletionChoiceMessageModel(
            role: msg.isUser ? OpenAIChatMessageRole.user : OpenAIChatMessageRole.assistant,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(msg.text),
            ],
          )),
        ],
        maxTokens: 1000,
        temperature: 0.7,
      );

      // Add AI response
      setState(() {
        _messages.add(ChatMessage(
          text: completion.choices.first.message.content?.first.text ?? "I apologize, but I couldn't generate a response. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "I apologize, but I encountered an error. Please check your internet connection and try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }
  }

  String _buildSystemPrompt(MetalPrice? gold, MetalPrice? silver) {
    String priceContext = "";
    if (gold != null) {
      priceContext += "Current gold price: \$${gold.pricePerOunce.toStringAsFixed(2)}/oz (\$${gold.pricePerGram.toStringAsFixed(2)}/g). ";
      priceContext += "24h change: ${gold.formattedChangePercent}. ";
    }
    if (silver != null) {
      priceContext += "Current silver price: \$${silver.pricePerOunce.toStringAsFixed(2)}/oz. ";
    }
    
    return """You are a knowledgeable and helpful precious metals investment assistant specialized in gold and silver. 
    You provide accurate, practical advice about gold/silver investments, market analysis, and jewelry pricing.
    
    $priceContext
    
    Guidelines:
    1. Provide educational information, not financial advice
    2. Be accurate with current prices and calculations
    3. Consider cultural context (support for Arab markets, Zakat calculations, etc.)
    4. Help detect scams and verify claims with evidence
    5. Explain complex concepts simply
    6. For jewelry: Consider making charges, VAT, and fair pricing
    7. Always include disclaimers when discussing investments
    
    Keep responses concise and actionable. Use bullet points when listing multiple items.""";
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gold AI Assistant'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text: "Chat cleared. How can I help you today?",
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  _buildQuickAction("🔍 Verify Claim", "Gold will crash next week - true?"),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessage(_messages[index]);
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

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}