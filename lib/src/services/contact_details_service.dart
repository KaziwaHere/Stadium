import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/services/booking_service.dart';

abstract class ContactDetailsRepository {
  Future<ContactDetails> getContactDetails();

  Future<ContactDetails> updateContactDetails({
    required String email,
    required String phone,
  });
}

class ContactDetailsService implements ContactDetailsRepository {
  ContactDetailsService(this._tables);

  static const databaseId = BookingService.databaseId;
  static const tableId = 'contact_details';
  static const rowId = 'admin_contact';

  final TablesDB _tables;

  @override
  Future<ContactDetails> getContactDetails() async {
    try {
      final row = await _tables.getRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
      );
      return ContactDetails.fromRow(row);
    } on AppwriteException catch (error) {
      if (error.code == 404) return ContactDetails.empty;
      rethrow;
    }
  }

  @override
  Future<ContactDetails> updateContactDetails({
    required String email,
    required String phone,
  }) async {
    final data = {
      'email': email,
      'phone': phone,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final row = await _tables.updateRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
      );
      return ContactDetails.fromRow(row);
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;

      final row = await _tables.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.label('admin')),
          Permission.delete(Role.label('admin')),
        ],
      );
      return ContactDetails.fromRow(row);
    }
  }
}

class ContactDetails {
  const ContactDetails({
    required this.email,
    required this.phone,
    required this.updatedAt,
  });

  factory ContactDetails.fromRow(models.Row row) {
    final data = row.data;
    return ContactDetails(
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }

  static const empty = ContactDetails(email: '', phone: '', updatedAt: null);

  final String email;
  final String phone;
  final DateTime? updatedAt;

  bool get hasEmail => email.trim().isNotEmpty;
  bool get hasPhone => phone.trim().isNotEmpty;
  bool get isEmpty => !hasEmail && !hasPhone;
}

final ContactDetailsRepository contactDetailsService = ContactDetailsService(
  TablesDB(client),
);
