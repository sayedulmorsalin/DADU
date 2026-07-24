import 'package:cached_network_image/cached_network_image.dart';
import 'package:dadu/controller/home_controller.dart';
import 'package:dadu/services/deep_link_service.dart';
import 'package:dadu/services/local_notification_db.dart';
import 'package:dadu/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationSheet {
  static void show(BuildContext context, HomeController controller) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Dismissible(
            key: const Key('notification_sheet'),
            direction: DismissDirection.up,
            onDismissed: (_) => Navigator.pop(context),
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.75,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                    ),
                    child: Column(
                      children: [
                        // Status bar spacer
                        SizedBox(height: MediaQuery.of(context).padding.top),
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  await LocalNotificationDb().markAllAsRead();
                                  setModalState(() {});
                                  controller.updateUnreadCount();
                                },
                                icon: const Icon(Icons.done_all, size: 18, color: AppColors.iconAccent),
                                label: const Text(
                                  'Mark all read',
                                  style: TextStyle(fontSize: 12, color: AppColors.iconAccent),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear All'),
                                      content: const Text('Delete all notifications permanently?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete All', style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await LocalNotificationDb().deleteAllNotifications();
                                    setModalState(() {});
                                    controller.updateUnreadCount();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // List
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: LocalNotificationDb().getNotifications(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final notifications = snapshot.data ?? [];

                              if (notifications.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No notifications yet',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                itemCount: notifications.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                                itemBuilder: (context, index) {
                                  final data = notifications[index];
                                  final isRead = data['isRead'] == 1;
                                  final imageUrl = data['image']?.toString();
                                  final createdAt = data['createdAt'] != null ? DateTime.tryParse(data['createdAt']) : null;
                                  final timeStr = createdAt != null ? DateFormat('MMM d, h:mm a').format(createdAt) : '';

                                  return Dismissible(
                                    key: Key('notif_${data['id']}'),
                                    background: Container(
                                      color: AppColors.error,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 25),
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    secondaryBackground: Container(
                                      color: AppColors.error,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 25),
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    onDismissed: (_) async {
                                      await LocalNotificationDb().deleteNotification(data['id']);
                                      controller.updateUnreadCount();
                                      setModalState(() {});
                                    },
                                    child: InkWell(
                                      onTap: () async {
                                        if (!isRead) {
                                          await LocalNotificationDb().markAsRead(data['id']);
                                          controller.updateUnreadCount();
                                        }
                                        
                                        final link = data['link'];
                                        if (link != null && link.toString().isNotEmpty) {
                                          Navigator.pop(context); // Close sheet before navigating
                                          DeepLinkService().handleLink(link.toString());
                                        } else {
                                          setModalState(() {});
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.05),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: isRead ? Colors.grey[100] : AppColors.primary.withOpacity(0.2),
                                                  child: Icon(
                                                    Icons.notifications_active,
                                                    color: isRead ? Colors.grey : AppColors.primary,
                                                    size: 20,
                                                  ),
                                                ),
                                                if (!isRead)
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 2),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['title'] ?? 'Notification',
                                                    style: TextStyle(
                                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                      fontSize: 15,
                                                      color: isRead ? Colors.grey[700] : Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    data['body'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isRead ? Colors.grey[600] : Colors.grey[800],
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (imageUrl != null && imageUrl.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: CachedNetworkImage(
                                                    imageUrl: imageUrl,
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // Drag Handle / Close indicator at the bottom
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, -1), end: const Offset(0, 0)).animate(anim1),
          child: child,
        );
      },
    );
  }
}
