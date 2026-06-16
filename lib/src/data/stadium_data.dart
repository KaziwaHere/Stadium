import 'package:flutter/material.dart';
import 'package:stadium/src/models/stadium.dart';

const stadiums = [
  Stadium(
    id: 'emerald_arena',
    name: 'Emerald Arena',
    location: 'Downtown District',
    rating: 4.9,
    price: 85,
    available: 'Today, 8:30 PM',
    iconKey: 'stadium',
    icon: Icons.stadium_rounded,
    days: [
      BookingDay(
        label: 'Today',
        date: 'Jun 13',
        slots: [
          BookingSlot(time: '6:00 PM', isBooked: false),
          BookingSlot(time: '7:00 PM', isBooked: true),
          BookingSlot(time: '8:30 PM', isBooked: false),
          BookingSlot(time: '10:00 PM', isBooked: false),
        ],
      ),
      BookingDay(
        label: 'Tomorrow',
        date: 'Jun 14',
        slots: [
          BookingSlot(time: '5:30 PM', isBooked: true),
          BookingSlot(time: '7:00 PM', isBooked: false),
          BookingSlot(time: '8:30 PM', isBooked: false),
          BookingSlot(time: '10:00 PM', isBooked: true),
        ],
      ),
      BookingDay(
        label: 'Mon',
        date: 'Jun 15',
        slots: [
          BookingSlot(time: '6:00 PM', isBooked: false),
          BookingSlot(time: '7:30 PM', isBooked: false),
          BookingSlot(time: '9:00 PM', isBooked: true),
          BookingSlot(time: '10:30 PM', isBooked: false),
        ],
      ),
    ],
  ),
  Stadium(
    id: 'northside_pitch',
    name: 'Northside Pitch',
    location: 'Al Mansour',
    rating: 4.7,
    price: 62,
    available: 'Tomorrow, 7:00 PM',
    iconKey: 'soccer',
    icon: Icons.sports_soccer_rounded,
    days: [
      BookingDay(
        label: 'Today',
        date: 'Jun 13',
        slots: [
          BookingSlot(time: '5:00 PM', isBooked: true),
          BookingSlot(time: '6:30 PM', isBooked: true),
          BookingSlot(time: '8:00 PM', isBooked: false),
          BookingSlot(time: '9:30 PM', isBooked: false),
        ],
      ),
      BookingDay(
        label: 'Tomorrow',
        date: 'Jun 14',
        slots: [
          BookingSlot(time: '5:30 PM', isBooked: false),
          BookingSlot(time: '7:00 PM', isBooked: false),
          BookingSlot(time: '8:30 PM', isBooked: true),
          BookingSlot(time: '10:00 PM', isBooked: false),
        ],
      ),
      BookingDay(
        label: 'Mon',
        date: 'Jun 15',
        slots: [
          BookingSlot(time: '6:00 PM', isBooked: true),
          BookingSlot(time: '7:30 PM', isBooked: false),
          BookingSlot(time: '9:00 PM', isBooked: false),
          BookingSlot(time: '10:30 PM', isBooked: false),
        ],
      ),
    ],
  ),
  Stadium(
    id: 'green_bowl',
    name: 'The Green Bowl',
    location: 'Riverside Park',
    rating: 4.8,
    price: 110,
    available: 'Fri, 9:00 PM',
    iconKey: 'grass',
    icon: Icons.grass_rounded,
    days: [
      BookingDay(
        label: 'Today',
        date: 'Jun 13',
        slots: [
          BookingSlot(time: '6:00 PM', isBooked: true),
          BookingSlot(time: '7:30 PM', isBooked: false),
          BookingSlot(time: '9:00 PM', isBooked: true),
          BookingSlot(time: '10:30 PM', isBooked: false),
        ],
      ),
      BookingDay(
        label: 'Tomorrow',
        date: 'Jun 14',
        slots: [
          BookingSlot(time: '5:00 PM', isBooked: false),
          BookingSlot(time: '6:30 PM', isBooked: false),
          BookingSlot(time: '8:00 PM', isBooked: true),
          BookingSlot(time: '9:30 PM', isBooked: false),
        ],
      ),
      BookingDay(
        label: 'Mon',
        date: 'Jun 15',
        slots: [
          BookingSlot(time: '6:00 PM', isBooked: false),
          BookingSlot(time: '7:30 PM', isBooked: true),
          BookingSlot(time: '9:00 PM', isBooked: false),
          BookingSlot(time: '10:30 PM', isBooked: false),
        ],
      ),
    ],
  ),
];
