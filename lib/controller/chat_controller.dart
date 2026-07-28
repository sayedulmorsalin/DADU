import 'dart:async';
import 'dart:io';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/services/api.dart';
import 'package:dadu/services/d1.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ChatController extends GetxController {
  final ApiService apiService = ApiService();
  final ImageService imageService = ImageService();
  final HomeController _homeController = Get.find<HomeController>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isSending = false.obs;
  final Rxn<File> selectedImage = Rxn<File>();

  String? _currentUserId;
  int _page = 1;
  bool _hasMore = true;
  final int _limit = 20;

  @override
  void onInit() {
    super.onInit();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentUserId != null) {
      loadMessages(isInitial: true);
    }

    _setupScrollListener();
    _setupFocusListener();
    _setupTextListener();
  }

  void _setupTextListener() {
    messageController.addListener(() {
      if (messageController.text.isNotEmpty) {
        // Scroll when user starts typing to keep content visible above keyboard
        _scrollToBottom();
      }
    });
  }

  void _setupFocusListener() {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        handleTextFieldTap();
      }
    });
  }

  void handleTextFieldTap() {
    // Wait for keyboard to fully animate up or layout to settle
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      // Trigger load more when user scrolls near the top
      if (scrollController.position.pixels <= 100 && 
          !isLoadingMore.value && 
          !isLoading.value && 
          _hasMore) {
        loadMessages(isInitial: false);
      }
    });
  }

  Future<void> loadMessages({bool isInitial = true}) async {
    if (_currentUserId == null || (!_hasMore && !isInitial)) return;
    
    if (isInitial) {
      isLoading.value = true;
      _page = 1;
      _hasMore = true;
    } else {
      isLoadingMore.value = true;
    }
    
    try {
      final fetchedMessages = await apiService.fetchMessages(
        _currentUserId!, 
        limit: _limit, 
        page: _page
      );
      
      if (fetchedMessages.length < _limit) {
        _hasMore = false;
      }

      if (isInitial) {
        messages.assignAll(fetchedMessages);
      } else if (fetchedMessages.isNotEmpty) {
        // Prepend older messages
        // Store current scroll position to restore it after prepending
        double oldMaxScroll = scrollController.position.maxScrollExtent;
        double oldOffset = scrollController.offset;

        messages.insertAll(0, fetchedMessages);
        _page++;

        // Restore scroll position after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            double newMaxScroll = scrollController.position.maxScrollExtent;
            scrollController.jumpTo(oldOffset + (newMaxScroll - oldMaxScroll));
          }
        });
      }
    } catch (e) {
      // Error loading messages
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
      
      // Scroll to bottom on initial load, but ONLY after isLoading is false
      if (isInitial) {
        _scrollToBottom(immediate: true);
      }
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  void removeSelectedImage() {
    selectedImage.value = null;
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if ((text.isEmpty && selectedImage.value == null) || _currentUserId == null || isSending.value) return;

    isSending.value = true;
    
    try {
      String? imageUrl;
      if (selectedImage.value != null) {
        imageUrl = await imageService.uploadChatImage(selectedImage.value!);
      }

      final String effectiveMessage = text.isEmpty && imageUrl != null ? "Image" : text;

      final success = await apiService.sendMessage(_currentUserId!, effectiveMessage, imageUrl: imageUrl);

      if (success) {
        messageController.clear();
        selectedImage.value = null;
        // After sending, we might want to just fetch the latest page or refresh everything
        // For simplicity and to see the new message, we'll refresh the initial view
        await loadMessages(isInitial: true); 
      } else {
        Get.snackbar(
          'Error',
          'Failed to send message. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSending.value = false;
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      int retryCount = 0;
      while (retryCount < 5) {
        if (scrollController.hasClients) {
          if (immediate) {
            scrollController.jumpTo(scrollController.position.maxScrollExtent);
          } else {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          // For initial loads, the extent might change as images load, 
          // so we wait a bit and check again.
          if (immediate) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (scrollController.hasClients) {
              scrollController.jumpTo(scrollController.position.maxScrollExtent);
            }
          }
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
    });
  }

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}
