import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact_mapping_model.dart';

final contactServiceProvider = Provider<ContactService>((ref) => ContactService());

class ContactService {
  static const String _gracyCountryCode = '+254'; // Kenya country code

  Future<bool> requestContactPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<bool> hasContactPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  Future<List<ContactMapping>> syncContacts() async {
    // TODO: Fix FlutterContacts API - temporarily return empty list
    return [];
  }

  Future<void> _checkContactsOnGracy(String userId) async {
    try {
      // Get all contact mappings for this user
      final mappings = await Supabase.instance.client
          .from('contact_mappings')
          .select()
          .eq('user_id', userId);

      // Get all profiles to match phone numbers
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, phone');

      final Set<String> profilePhones = {};
      for (final profile in profiles) {
        if (profile['phone'] != null) {
          profilePhones.add(profile['phone'] as String);
        }
      }

      // Update mappings for contacts found on Gracy
      for (final mapping in mappings) {
        final contactPhone = mapping['contact_phone'] as String;
        if (profilePhones.contains(contactPhone)) {
          await Supabase.instance.client
              .from('contact_mappings')
              .update({'is_on_gracy': true})
              .eq('id', mapping['id']);
        }
      }
    } catch (e) {
      // Don't throw here, just log the error
      print('Error checking contacts on Gracy: $e');
    }
  }

  Future<List<ContactMapping>> getContactsOnGracy() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await Supabase.instance.client
          .from('contact_mappings')
          .select()
          .eq('owner_id', currentUserId)
          .eq('is_on_gracy', true);

      return response.map((data) => ContactMapping.fromMap(data)).toList();
    } catch (e) {
      throw Exception('Failed to get Gracy contacts: $e');
    }
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;

    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Remove leading zeros
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Add country code if missing
    if (!cleaned.startsWith('+')) {
      cleaned = _gracyCountryCode + cleaned;
    }

    // Validate phone number (basic validation)
    if (cleaned.length < 10) return null;

    return cleaned;
  }

  Future<void> showContactSyncDialog(BuildContext context) async {
    final hasPermission = await hasContactPermission();
    
    if (!hasPermission) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact Sync'),
          content: const Text(
            'Gracy needs access to your contacts to help you find friends who are already using the app. Your contacts are stored securely and never shared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow Access'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await requestContactPermission();
      }
    }

    if (await hasContactPermission()) {
      try {
        await syncContacts();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sync contacts: $e')),
          );
        }
      }
    }
  }
}
