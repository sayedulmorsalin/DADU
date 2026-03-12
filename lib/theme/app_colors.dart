import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Core Brand Colors ───
  static const Color scaffoldBackground = Colors.white;
  static const Color primary = Color(0xFFF9A825); // Colors.yellow[800]
  static const Color selectedNavItem = Colors.orange;

  // ─── Text Colors ───
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.grey;
  static const Color textOnPrimary = Colors.white;
  static const Color textLink = Colors.blue;

  // ─── Button Colors ───
  static const Color addToCartButton = Colors.orangeAccent;
  static const Color buyNowButton = Colors.blue;
  static const Color shareButton = Colors.green;
  static const Color signUpButton = Colors.green;

  // ─── Status / Feedback Colors ───
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;

  // ─── Card / Surface Colors ───
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color.fromARGB(
    255,
    255,
    255,
    255,
  ); 
  
  // Colors.grey[100]
  static Color inputFillColor = Colors.grey[300]!;

  // ─── Size Selector Colors ───
  static const Color sizeSelected = Colors.green;
  static Color sizeUnselected = Colors.grey[300]!;

  // ─── Section Colors ───
  static const Color flashSaleBackground = Color(0xFFFFF3E0);
  static const Color newArrivalBackground = Color.fromARGB(255, 245, 249, 241);

  // ─── Reward / Loyalty Colors ───
  static const Color rewardPrimary = Colors.deepPurple;
  static const Color coinGold = Colors.amber;
  static const Color coinSilver = Colors.grey;
  static Color loyaltyGradientStart = Colors.blue[800]!;
  static Color loyaltyGradientEnd = Colors.blue[600]!;
  static Color profileAccent = Colors.blue[700]!;

  // ─── Gift Box Colors ───
  static const Color giftBoxBody = Colors.redAccent;
  static const Color giftBoxLid = Colors.yellow;

  // ─── Misc ───
  static const Color updateBanner = Colors.amberAccent;
  static const Color dividerColor = Colors.grey;
  static Color badgeBackground = Colors.red;
}
