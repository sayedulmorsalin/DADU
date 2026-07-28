import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/controller/chat_controller.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.put(ChatController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat with DADU',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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
                itemCount: controller.messages.length + (controller.isLoadingMore.value ? 1 : 0),
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
                  final msg = controller.messages[messageIndex];
                  final isMe = msg['senderRole'] == 'user';
                  final timeStr = msg['createdAt'] ?? '';
                  String displayTime = '';
                  
                  try {
                    if (timeStr.isNotEmpty) {
                      final date = DateTime.parse(timeStr);
                      displayTime = DateFormat('hh:mm a').format(date.toLocal());
                    }
                  } catch (_) {}

                  return _buildChatBubble(
                    context,
                    isMe: isMe,
                    message: msg['message'] ?? '',
                    imageUrl: msg['image'] ?? msg['imageUrl'] ?? msg['img_url'],
                    time: displayTime,
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

  Widget _buildChatBubble(BuildContext context, {required bool isMe, required String message, String? imageUrl, required String time}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.selectedNavItem : AppColors.surfaceGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
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
    );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              if (controller.selectedImage.value == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 100,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        controller.selectedImage.value!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: controller.removeSelectedImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: AppColors.selectedNavItem),
                  onPressed: controller.pickImage,
                ),
                Expanded(
                  child: Container(
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
                        // Scroll when the field is tapped, even if already focused
                        controller.handleTextFieldTap();
                      },
                      onSubmitted: (_) => controller.sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.selectedNavItem,
                    shape: BoxShape.circle,
                  ),
                  child: controller.isSending.value
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: controller.sendMessage,
                        ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
