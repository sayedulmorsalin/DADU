import 'dart:async';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/services/d1.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  final ApiService apiService = ApiService();
  final HomeController _homeController = Get.find<HomeController>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;

  Timer? _pollingTimer;
  Worker? _tabWorker;
  String? _currentUserId;

  @override
  void onInit() {
    super.onInit();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Monitor tab changes to stop polling when not on the Message tab
    _tabWorker = ever(_homeController.selectedIndex, (int index) {
      if (index == 3) {
        _startPolling();
      } else {
        _stopPolling();
      }
    });

    if (_currentUserId != null && _homeController.selectedIndex.value == 3) {
      loadMessages();
      _startPolling();
    }
  }

  Future<void> loadMessages() async {
    if (_currentUserId == null) return;
    
    // Only show loading for the very first fetch
    if (messages.isEmpty) isLoading.value = true;
    
    try {
      final fetchedMessages = await apiService.fetchMessages(_currentUserId!);
      
      // Only update and scroll if the message count has changed
      if (fetchedMessages.length != messages.length) {
        messages.assignAll(fetchedMessages);
        _scrollToBottom();
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || isSending.value) return;

    isSending.value = true;
    final success = await apiService.sendMessage(_currentUserId!, text);

    if (success) {
      messageController.clear();
      await loadMessages(); // Refresh list immediately
    } else {
      Get.snackbar(
        'Error',
        'Failed to send message. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    isSending.value = false;
  }

  void _startPolling() {
    if (_pollingTimer?.isActive ?? false) return;
    print('ChatController: Starting 10s polling');
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => loadMessages());
  }

  void _stopPolling() {
    if (_pollingTimer?.isActive ?? false) {
      print('ChatController: Stopping polling (switched to tab ${_homeController.selectedIndex.value})');
      _pollingTimer?.cancel();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void onClose() {
    print('ChatController: Disposing controller and stopping polling');
    _tabWorker?.dispose();
    _pollingTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
