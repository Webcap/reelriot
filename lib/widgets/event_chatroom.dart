import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:reelriot/provider/app_dependency_provider.dart';
import 'package:reelriot/utils/routes/app_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
  final String role;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.role = 'user',
  });

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) {
    DateTime date;
    try {
      final rawDate = json['created_at']?.toString();
      if (rawDate != null && rawDate.isNotEmpty) {
        date = DateTime.parse(rawDate);
      } else {
        date = DateTime.now();
      }
    } catch (_) {
      date = DateTime.now();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Anonymous',
      content: json['message']?.toString() ?? json['content']?.toString() ?? '',
      createdAt: date,
      role: json['role']?.toString().toLowerCase() ?? 'user',
    );
  }
}

class EventChatroom extends StatefulWidget {
  const EventChatroom({
    super.key,
    required this.roomId,
    required this.roomName,
    this.showHeader = true,
  });

  final String roomId;
  final String roomName;
  final bool showHeader;

  @override
  State<EventChatroom> createState() => _EventChatroomState();
}

class _EventChatroomState extends State<EventChatroom> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _pollingTimer;

  bool _loading = true;
  bool _isSending = false;
  bool _isSignedIn = false;
  int _presenceCount = 1;
  String? _currentUserRole = 'user';
  String _currentUsername = 'Anonymous';
  String? _currentUserId;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initUser();
    _fetchMessages();
    _initRealtimeChannels();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _initUser();
    });
  }

  @override
  void didUpdateWidget(covariant EventChatroom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _cleanupChannels();
      _messages.clear();
      _loading = true;
      _fetchMessages();
      _initRealtimeChannels();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cleanupChannels();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cleanupChannels() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    if (_messagesChannel != null) {
      Supabase.instance.client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  Future<void> _initUser() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    final isAuth = user != null && !user.isAnonymous;
    _isSignedIn = isAuth;

    if (isAuth) {
      _currentUserId = user.id;
      final metaName = user.userMetadata?['username']?.toString() ??
          user.email?.split('@').first;
      _currentUsername = metaName ?? 'User';

      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role, username')
            .eq('id', _currentUserId!)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            _currentUserRole = profile['role']?.toString().toLowerCase() ?? 'user';
            if (profile['username'] != null && profile['username'].toString().isNotEmpty) {
              _currentUsername = profile['username'].toString();
            }
          });
        }
      } catch (_) {}
    } else {
      _currentUserId = null;
      _currentUsername = 'Guest';
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchMessages() async {
    try {
      final dynamic res = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;

      if (res is List) {
        final List<ChatMessage> fetched = res
            .map((m) => ChatMessage.fromJson(m is Map ? Map<String, dynamic>.from(m) : {}))
            .toList()
            .reversed
            .toList();

        setState(() {
          final tempMessages = _messages.where((m) => m.id.startsWith('temp_')).toList();
          _messages.clear();
          _messages.addAll(fetched);
          for (final temp in tempMessages) {
            if (!_messages.any((m) => m.userId == temp.userId && m.content == temp.content)) {
              _messages.add(temp);
            }
          }
          _loading = false;
        });

        _scrollToBottom();
      }
    } catch (e, stack) {
      debugPrint('[Chatroom] Error fetching messages: $e\n$stack');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initRealtimeChannels() {
    try {
      final client = Supabase.instance.client;

      // 1. Presence channel
      _presenceChannel = client.channel('room:${widget.roomId}:presence');
      _presenceChannel!
          .onPresenceSync((_) {
            if (!mounted) return;
            final state = _presenceChannel!.presenceState();
            setState(() {
              _presenceCount = state.isNotEmpty ? state.length : 1;
            });
          })
          .subscribe((status, [error]) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              try {
                await _presenceChannel!.track({
                  'online_at': DateTime.now().toIso8601String(),
                  'id': _currentUserId ?? 'guest',
                  'username': _currentUsername,
                  'role': _currentUserRole ?? 'user',
                });
              } catch (_) {}
            }
          });

      // 2. Messages channel
      _messagesChannel = client.channel('room:${widget.roomId}:messages');
      _messagesChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['room_id']?.toString() != widget.roomId) return;
              final msg = ChatMessage.fromJson(newRecord);
              if (mounted) {
                setState(() {
                  // If we have an optimistic temp message matching this record, replace it
                  final tempIdx = _messages.indexWhere(
                    (m) =>
                        m.id.startsWith('temp_') &&
                        m.userId == msg.userId &&
                        m.content == msg.content,
                  );
                  if (tempIdx != -1) {
                    _messages[tempIdx] = msg;
                  } else if (!_messages.any((m) => m.id == msg.id)) {
                    _messages.add(msg);
                  }
                  // Cap local message buffer to prevent memory growth during long streams
                  if (_messages.length > 150) {
                    _messages.removeRange(0, _messages.length - 150);
                  }
                });
                _scrollToBottom();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final oldRecord = payload.oldRecord;
              final id = oldRecord['id']?.toString();
              if (id != null && mounted) {
                setState(() {
                  _messages.removeWhere((m) => m.id == id);
                });
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.channelError || error != null) {
              debugPrint('[Chatroom] Realtime error, starting polling fallback: $error');
              _startPollingFallback();
            }
          });
    } catch (e) {
      debugPrint('[Chatroom] Channel setup failed: $e');
      _startPollingFallback();
    }
  }

  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchMessages();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickContent]) async {
    if (!_isSignedIn) return;
    final text = (quickContent ?? _textCtrl.text).trim();
    if (text.isEmpty || _isSending) return;

    if (quickContent == null) {
      _textCtrl.clear();
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: tempId,
      userId: _currentUserId ?? 'user',
      username: _currentUsername,
      content: text,
      createdAt: DateTime.now(),
      role: _currentUserRole ?? 'user',
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final provider = Provider.of<AppDependencyProvider>(context, listen: false);
      final apiUrl = provider.caffeineAPIURL.replaceAll(RegExp(r'/$'), '');
      final session = Supabase.instance.client.auth.currentSession;

      bool sent = false;

      // 1. Send via Caffeine API /v1/chat/send (includes AI moderation check)
      if (session?.accessToken != null) {
        try {
          final res = await http.post(
            Uri.parse('$apiUrl/v1/chat/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session!.accessToken}',
            },
            body: jsonEncode({
              'message': text,
              'roomId': widget.roomId,
              'username': _currentUsername,
              'role': _currentUserRole ?? 'user',
            }),
          );

          if (res.statusCode == 200 || res.statusCode == 201) {
            sent = true;
            try {
              final data = jsonDecode(res.body);
              if (data is Map<String, dynamic> && data['id'] != null) {
                final serverMsg = ChatMessage.fromJson(data);
                if (mounted) {
                  setState(() {
                    final idx = _messages.indexWhere((m) => m.id == tempId);
                    if (idx != -1) {
                      _messages[idx] = serverMsg;
                    }
                  });
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('[Chatroom] Caffeine API chat send failed, falling back: $e');
        }
      }

      // 2. Fallback directly to Supabase if not sent via API
      if (!sent) {
        final inserted = await Supabase.instance.client
            .from('messages')
            .insert({
              'room_id': widget.roomId,
              'user_id': _currentUserId ?? 'anon',
              'username': _currentUsername,
              'message': text,
              'role': _currentUserRole ?? 'user',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .maybeSingle();

        if (inserted != null && mounted) {
          final serverMsg = ChatMessage.fromJson(inserted);
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              _messages[idx] = serverMsg;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[Chatroom] Failed to insert message: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF070B11),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
      ),
      child: Column(
        children: [
          if (widget.showHeader) _buildChatHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(),
          ),
          if (_isSignedIn) ...[
            _buildQuickReactions(),
            _buildInputBar(),
          ] else
            _buildSignInPrompt(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EVENT CHAT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, size: 13, color: Color(0xB8FFFFFF)),
                const SizedBox(width: 5),
                Text(
                  '$_presenceCount online',
                  style: const TextStyle(
                    color: Color(0xB8FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: Color(0x66FFFFFF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Be the first to say hello to other viewers!',
              style: TextStyle(
                color: Color(0x66FFFFFF),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg.userId == _currentUserId;
        return _buildMessageItem(msg, isMe);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(msg.username, msg.role),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        msg.username,
                        style: TextStyle(
                          color: isMe ? const Color(0xFF60A5FA) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildRoleBadge(msg.role),
                    const Spacer(),
                    Text(
                      _formatTime(msg.createdAt),
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF0F172A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                          : const Color(0x14FFFFFF),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String username, String role) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    Color bg = const Color(0xFF334155);
    if (role == 'admin' || role == 'owner') bg = const Color(0xFFDC2626);
    if (role == 'mod' || role == 'moderator') bg = const Color(0xFF059669);
    if (role == 'vip') bg = const Color(0xFF7C3AED);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    if (role == 'user' || role.isEmpty) return const SizedBox.shrink();

    Color color = const Color(0xFF64748B);
    String label = role.toUpperCase();

    if (role == 'admin' || role == 'owner') {
      color = const Color(0xFFDC2626);
      label = 'ADMIN';
    } else if (role == 'mod' || role == 'moderator') {
      color = const Color(0xFF059669);
      label = 'MOD';
    } else if (role == 'vip') {
      color = const Color(0xFF7C3AED);
      label = 'VIP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sign in to join the conversation',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Get.toNamed(Routes.login),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReactions() {
    final emojis = ['🔥', '👏', '❤️', '👀', '💯'];
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _sendMessage(emoji),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Chat with viewers...',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF), fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFFDC2626),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _isSending ? null : () => _sendMessage(),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
