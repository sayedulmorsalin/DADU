import 'dart:async';
import 'dart:io';
import 'package:dadu/services/api.dart';
import 'package:dadu/services/d1.dart';
import 'package:dadu/services/chat_socket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatController extends GetxController {
  final ApiService apiService = ApiService();
  final ImageService imageService = ImageService();
  final ChatSocketService _socketService = Get.put(ChatSocketService());
  
  RxBool get isTyping => _socketService.isTyping;
  RxBool get isSocketConnected => _socketService.isConnected;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isSending = false.obs;
  final RxList<File> selectedImages = <File>[].obs;
  final Rxn<File> selectedVoiceNote = Rxn<File>();
  final Rxn<Map<String, dynamic>> replyingToMessage = Rxn<Map<String, dynamic>>();
  final RxString currentText = "".obs;

  final RxnString highlightedMessageId = RxnString();

  void setReplyMessage(Map<String, dynamic> msg) {
    replyingToMessage.value = msg;
    focusNode.requestFocus();
  }

  void cancelReply() {
    replyingToMessage.value = null;
  }

  String getReplySnippet(Map<String, dynamic> msg) {
    final String text = (msg['message'] ?? '').toString().trim();
    final String? imgUrl = msg['imageUrl'] ?? msg['image'] ?? msg['img_url'];

    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (text.isNotEmpty && text != "Image") {
        return "[IMAGE]:$imgUrl|$text";
      }
      return "[IMAGE]:$imgUrl";
    }

    if (text.isNotEmpty && text != "Image" && text != "Voice Note") {
      return text;
    }
    if (msg['voiceNoteUrl'] != null || text == "Voice Note") {
      return "🎤 Voice Note";
    }
    return text.isNotEmpty ? text : "Message";
  }

  void scrollToAndHighlightMessage(String targetId) {
    if (targetId.isEmpty) return;
    final index = messages.indexWhere((msg) => msg['id'] == targetId);
    if (index != -1 && scrollController.hasClients) {
      final double maxScroll = scrollController.position.maxScrollExtent;
      final double targetOffset = (index / messages.length) * maxScroll;
      scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      highlightedMessageId.value = targetId;
      Timer(const Duration(milliseconds: 1800), () {
        if (highlightedMessageId.value == targetId) {
          highlightedMessageId.value = null;
        }
      });
    }
  }

  // Recording variables
  final AudioRecorder _recorder = AudioRecorder();
  final RxBool isRecording = false.obs;
  final RxString recordingTime = "0:00".obs;
  Timer? _recordingTimer;
  int _recordDuration = 0;
  String? _currentUserId;
  int _page = 1;
  bool _hasMore = true;
  final int _limit = 20;

  final RxBool isMessagingEnabled = true.obs;
  Timer? _statusCheckTimer;

  @override
  void onInit() {
    super.onInit();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    checkMessagingStatus();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkMessagingStatus();
    });

    if (_currentUserId != null) {
      loadMessages(isInitial: true);
      _socketService.connect(_currentUserId!);
      _listenToSocket();
    }

    _setupScrollListener();
    _setupFocusListener();
    _setupTextListener();
  }

  Future<void> checkMessagingStatus() async {
    final enabled = await apiService.fetchMessagingStatus();
    isMessagingEnabled.value = enabled;
  }

  void _listenToSocket() {
    _socketService.messageStream.listen((event) {
      if (event['type'] == 'new_message') {
        // Add new message to the list if it's not already there (by ID)
        final String messageId = event['id'] ?? '';
        final bool alreadyExists = messages.any((msg) => msg['id'] == messageId);
        
        if (!alreadyExists) {
          messages.add(event);
          messages.sort((a, b) {
            final String tA = (a['createdAt'] ?? '').toString();
            final String tB = (b['createdAt'] ?? '').toString();
            return tA.compareTo(tB);
          });
          _scrollToBottom();
        }
      }
    });
  }

  Timer? _typingTimer;
  void _setupTextListener() {
    messageController.addListener(() {
      currentText.value = messageController.text;
      if (messageController.text.isNotEmpty) {
        // Scroll when user starts typing to keep content visible above keyboard
        _scrollToBottom();

        // Handle typing indicator
        _socketService.sendTyping();
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 2), () {
          _socketService.sendStopTyping();
        });
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

  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
      );
      if (pickedFiles.isNotEmpty) {
        selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick images: $e');
    }
  }

  void removeSelectedImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);
    }
  }

  void removeVoiceNote() {
    selectedVoiceNote.value = null;
  }

  // --- Voice Recording Logic ---

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(); // Default config: AAC_LC, 44100Hz, 128kbps

        await _recorder.start(config, path: path);
        isRecording.value = true;
        _recordDuration = 0;
        recordingTime.value = "0:00";
        
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordDuration++;
          final minutes = (_recordDuration ~/ 60).toString().padLeft(1, '0');
          final seconds = (_recordDuration % 60).toString().padLeft(2, '0');
          recordingTime.value = "$minutes:$seconds";
        });
      } else {
        Get.snackbar('Permission Denied', 'Microphone permission is required to record voice notes.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording.value) return;
    
    try {
      _recordingTimer?.cancel();
      final path = await _recorder.stop();
      isRecording.value = false;
      
      if (path != null) {
        selectedVoiceNote.value = File(path);
        // Removed auto-send to allow preview
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to stop recording: $e');
    }
  }

  // --- Playback Logic ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxString playingMessageId = "".obs;
  final RxBool isPreviewPlaying = false.obs;

  Future<void> playVoiceNote(String messageId, String url) async {
    try {
      if (playingMessageId.value == messageId) {
        await _audioPlayer.stop();
        playingMessageId.value = "";
        return;
      }
      
      // Stop preview if it's playing
      if (isPreviewPlaying.value) {
        await _audioPlayer.stop();
        isPreviewPlaying.value = false;
      }

      playingMessageId.value = messageId;
      
      // Resolve relative backend URLs
      final String fullUrl = url.startsWith('/') 
          ? "${apiService.apiBaseUrl}$url" 
          : url;

      await _audioPlayer.play(UrlSource(fullUrl));
      
      _audioPlayer.onPlayerComplete.listen((_) {
        playingMessageId.value = "";
      });
    } catch (e) {
      Get.snackbar('Playback Error', 'Failed to play voice note: $e');
      playingMessageId.value = "";
    }
  }

  Future<void> playPreview() async {
    if (selectedVoiceNote.value == null) return;

    try {
      if (isPreviewPlaying.value) {
        await _audioPlayer.stop();
        isPreviewPlaying.value = false;
        return;
      }

      // Stop any other message playing
      playingMessageId.value = "";

      isPreviewPlaying.value = true;
      await _audioPlayer.play(DeviceFileSource(selectedVoiceNote.value!.path));

      _audioPlayer.onPlayerComplete.listen((_) {
        isPreviewPlaying.value = false;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to play preview: $e');
      isPreviewPlaying.value = false;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _recorder.stop();
      isRecording.value = false;
      selectedVoiceNote.value = null;
    } catch (e) {
      // Handle recording cancellation exception silently
    }
  }

  Future<void> sendMessage() async {
    if (!isMessagingEnabled.value) {
      Get.snackbar(
        'Messaging Disabled',
        'Messaging is currently disabled by Admin.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final text = messageController.text.trim();
    if ((text.isEmpty && selectedImages.isEmpty && selectedVoiceNote.value == null) || 
        _currentUserId == null || isSending.value) return;

    isSending.value = true;
    _socketService.sendStopTyping(); // Stop typing indicator when sending

    final String? replyToId = replyingToMessage.value?['id'];
    final String? replyToText = replyingToMessage.value != null ? getReplySnippet(replyingToMessage.value!) : null;
    final String? replyToSenderRole = replyingToMessage.value?['senderRole'];
    
    try {
      // 1. Handle Voice Note
      if (selectedVoiceNote.value != null) {
        final voiceNoteUrl = await imageService.uploadVoiceNote(selectedVoiceNote.value!);
        if (_socketService.isConnected.value) {
          _socketService.sendMessage("", voiceNoteUrl: voiceNoteUrl, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
        } else {
          await apiService.sendMessage(_currentUserId!, "", voiceNoteUrl: voiceNoteUrl, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
        }
        selectedVoiceNote.value = null;
      }

      // 2. Handle Images (Multiple)
      if (selectedImages.isNotEmpty) {
        // Upload all images to the new backend endpoint
        final List<String> imageUrls = await imageService.uploadMultipleFiles(selectedImages.toList());
        
        for (final imageUrl in imageUrls) {
          if (_socketService.isConnected.value) {
            _socketService.sendMessage("Image", imageUrl: imageUrl, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
          } else {
            await apiService.sendMessage(_currentUserId!, "Image", imageUrl: imageUrl, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
          }
          // Small delay to ensure order and not overwhelm the socket
          await Future.delayed(const Duration(milliseconds: 100));
        }
        selectedImages.clear();
      }

      // 3. Handle Text Message
      if (text.isNotEmpty) {
        if (_socketService.isConnected.value) {
          _socketService.sendMessage(text, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
          messageController.clear();
        } else {
          final success = await apiService.sendMessage(_currentUserId!, text, replyToId: replyToId, replyToText: replyToText, replyToSenderRole: replyToSenderRole);
          if (success) {
            messageController.clear();
          } else {
            throw Exception("Failed to send text message");
          }
        }
      }

      // Clear reply state after sending
      cancelReply();

      // Refresh if using HTTP fallback
      if (!_socketService.isConnected.value) {
        await loadMessages(isInitial: true);
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
    _statusCheckTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}
