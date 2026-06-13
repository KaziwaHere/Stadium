import 'package:flutter/material.dart';

class Stadium {
  const Stadium({
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.available,
    required this.icon,
    required this.days,
  });

  final String name;
  final String location;
  final double rating;
  final int price;
  final String available;
  final IconData icon;
  final List<BookingDay> days;
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
