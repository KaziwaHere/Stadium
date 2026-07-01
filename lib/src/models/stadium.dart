import 'package:flutter/material.dart';

class Stadium {
  const Stadium({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.available,
    required this.iconKey,
    required this.icon,
    required this.days,
    this.imageFileId,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String location;
  final double rating;
  final int price;
  final String available;
  final String iconKey;
  final IconData icon;
  final List<BookingDay> days;
  final String? imageFileId;
  final bool isFeatured;
}

IconData stadiumIconFromKey(String iconKey) {
  return switch (iconKey) {
    'soccer' => Icons.sports_soccer_rounded,
    'grass' => Icons.grass_rounded,
    _ => Icons.stadium_rounded,
  };
}

class BookingDay {
  const BookingDay({
    required this.label,
    required this.date,
    required this.slots,
  });

  final String label;
  final String date;
  final List<BookingSlot> slots;
}

class BookingSlot {
  const BookingSlot({required this.time, required this.isBooked});

  final String time;
  final bool isBooked;
}
