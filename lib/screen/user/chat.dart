import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/controller/chat_controller.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.put(ChatController());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chat with DADU',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final isConnected = controller.isSocketConnected.value;
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ],
        ),
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "No messages yet.\nStart a conversation with us!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: controller.messages.length + (controller.isLoadingMore.value ? 1 : 0) + (controller.isTyping.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0 && controller.isLoadingMore.value) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final messageIndex = controller.isLoadingMore.value ? index - 1 : index;
                  
                  if (messageIndex == controller.messages.length && controller.isTyping.value) {
                    return _buildTypingIndicator();
                  }

                  if (messageIndex >= controller.messages.length) return const SizedBox.shrink();

                  final msg = controller.messages[messageIndex];
                  final isMe = msg['senderRole'] == 'user';
                  final timeStr = (msg['createdAt'] ?? '').toString();
                  String displayTime = '';
                  
                  try {
                    if (timeStr.isNotEmpty) {
                      String formattedTimeStr = timeStr;
                      if (!formattedTimeStr.contains('T')) {
                        formattedTimeStr = formattedTimeStr.replaceFirst(' ', 'T');
                      }
                      if (!formattedTimeStr.endsWith('Z') && !formattedTimeStr.contains('+')) {
                        formattedTimeStr += 'Z';
                      }
                      final date = DateTime.parse(formattedTimeStr);
                      displayTime = DateFormat('hh:mm a').format(date.toLocal());
                    }
                  } catch (_) {}

                  return Dismissible(
                    key: Key('msg_${msg['id'] ?? index}'),
                    direction: DismissDirection.startToEnd,
                    confirmDismiss: (direction) async {
                      controller.setReplyMessage(msg);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      color: Colors.transparent,
                      child: const Icon(Icons.reply, color: AppColors.selectedNavItem),
                    ),
                    child: _buildChatBubble(
                      context,
                      id: msg['id'] ?? '',
                      isMe: isMe,
                      message: msg['message'] ?? '',
                      imageUrl: msg['image'] ?? msg['imageUrl'] ?? msg['img_url'],
                      voiceNoteUrl: msg['voiceNoteUrl'],
                      replyToId: msg['replyToId'],
                      replyToText: msg['replyToText'],
                      replyToSenderRole: msg['replyToSenderRole'],
                      time: displayTime,
                    ),
                  );
                },
              );
            }),
          ),
          _buildMessageInput(context, controller),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "DADU is typing",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(width: 4),
            const TypingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContent(String replyText, String? senderRole, bool isMe) {
    String textDisplay = replyText;
    String? imgUrl;

    if (replyText.startsWith("[IMAGE]:")) {
      final parts = replyText.substring(8).split('|');
      imgUrl = parts[0];
      textDisplay = parts.length > 1 ? parts[1] : "Photo";
    } else if (replyText == "📷 Image") {
      textDisplay = "Photo";
    }

    final String? fullImgUrl = (imgUrl != null && imgUrl.isNotEmpty)
        ? (imgUrl.startsWith('/') ? "${dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com')}$imgUrl" : imgUrl)
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fullImgUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: fullImgUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Icon(Icons.image, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderRole == 'user' ? 'You' : 'DADU Admin',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : AppColors.selectedNavItem,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                textDisplay,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(BuildContext context, {
    required String id,
    required bool isMe,
    required String message,
    String? imageUrl,
    String? voiceNoteUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSenderRole,
    required String time,
  }) {
    final ChatController controller = Get.find<ChatController>();
    return Obx(() {
      final bool isHighlighted = controller.highlightedMessageId.value == id;
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            final String textToCopy = message.isNotEmpty 
                ? message 
                : ((imageUrl != null && imageUrl.isNotEmpty) ? "Image" : "");
            if (textToCopy.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: textToCopy));
              HapticFeedback.mediumImpact();
              Get.snackbar(
                'Copied',
                'Message copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.black87,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(12),
                borderRadius: 8,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.amber.shade300
                  : (isMe ? AppColors.selectedNavItem : AppColors.surfaceGrey),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyToText != null && replyToText.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      if (replyToId != null && replyToId.isNotEmpty) {
                        controller.scrollToAndHighlightMessage(replyToId);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe ? Colors.white : AppColors.selectedNavItem,
                            width: 3.5,
                          ),
                        ),
                      ),
                      child: _buildReplyContent(replyToText, replyToSenderRole, isMe),
                    ),
                  ),
                ],
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl.startsWith('/') 
                          ? "${dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com')}$imageUrl" 
                          : imageUrl,
                      placeholder: (context, url) => const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) ...[
                  Obx(() {
                    final isPlaying = controller.playingMessageId.value == id;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => controller.playVoiceNote(id, voiceNoteUrl),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.2) : AppColors.selectedNavItem.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.stop : Icons.play_arrow,
                              color: isMe ? Colors.white : AppColors.selectedNavItem,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPlaying ? "Playing..." : "Voice Note",
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMessageInput(BuildContext context, ChatController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Obx(() {
          if (!controller.isMessagingEnabled.value) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speaker_notes_off_rounded, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Messaging is currently turned off by Admin.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final replyMsg = controller.replyingToMessage.value;
              if (replyMsg == null) return const SizedBox.shrink();
              final senderText = replyMsg['senderRole'] == 'user' ? 'Replying to Yourself' : 'Replying to DADU Admin';
              String snippetText = controller.getReplySnippet(replyMsg);
              String? imgUrl = replyMsg['imageUrl'] ?? replyMsg['image'] ?? replyMsg['img_url'];

              if (snippetText.startsWith("[IMAGE]:")) {
                final parts = snippetText.substring(8).split('|');
                imgUrl ??= parts[0];
                snippetText = parts.length > 1 ? parts[1] : "Photo";
              }

              final String? fullImgUrl = (imgUrl != null && imgUrl.isNotEmpty)
                  ? (imgUrl.startsWith('/') ? "${dotenv.get('API_BASE_URL', fallback: 'https://api.dadubd.com')}$imgUrl" : imgUrl)
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: AppColors.selectedNavItem, width: 4)),
                ),
                child: Row(
                  children: [
                    if (fullImgUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: fullImgUrl,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(Icons.image, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderText,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.selectedNavItem),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            snippetText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.cancelReply,
                      child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }),
            Obx(() {
              if (controller.selectedImages.isEmpty && controller.selectedVoiceNote.value == null) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 80,
                child: Row(
                  children: [
                    if (controller.selectedImages.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      controller.selectedImages[index],
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => controller.removeSelectedImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (controller.selectedVoiceNote.value != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.selectedNavItem.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(() => GestureDetector(
                              onTap: controller.playPreview,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.selectedNavItem.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  controller.isPreviewPlaying.value ? Icons.stop : Icons.play_arrow,
                                  color: AppColors.selectedNavItem,
                                  size: 20,
                                ),
                              ),
                            )),
                            const SizedBox(width: 8),
                            const Text("Voice Note", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: controller.removeVoiceNote,
                              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                Obx(() => IconButton(
                  icon: const Icon(Icons.image, color: AppColors.selectedNavItem),
                  onPressed: (controller.isSending.value || controller.isRecording.value) 
                      ? null 
                      : controller.pickImages,
                )),
                Obx(() => IconButton(
                  icon: Icon(
                    controller.isRecording.value ? Icons.stop : Icons.mic,
                    color: (controller.isSending.value)
                        ? AppColors.selectedNavItem.withOpacity(0.5)
                        : (controller.isRecording.value ? Colors.red : AppColors.selectedNavItem),
                  ),
                  onPressed: controller.isSending.value ? null : () {
                    if (controller.isRecording.value) {
                      controller.stopRecording();
                    } else {
                      controller.startRecording();
                    }
                  },
                )),
                Expanded(
                  child: Obx(() {
                    if (controller.isRecording.value) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Recording ${controller.recordingTime.value}",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: controller.cancelRecording,
                              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: controller.messageController,
                        focusNode: controller.focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () {
                          controller.handleTextFieldTap();
                        },
                        onSubmitted: (_) => controller.sendMessage(),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Obx(() {
                  if (controller.isSending.value) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.selectedNavItem,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: controller.isRecording.value 
                          ? AppColors.selectedNavItem.withOpacity(0.5) 
                          : AppColors.selectedNavItem,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: controller.isRecording.value ? null : controller.sendMessage,
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      }),
    ),
  );
}
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = ((_controller.value - delay) % 1.0);
            final double opacity = (1.0 - value).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
