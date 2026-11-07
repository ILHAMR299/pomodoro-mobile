import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  AuthService({DatabaseHelper? database, Random? random})
    : _database = database ?? DatabaseHelper.instance,
      _random = random ?? Random.secure();

  final DatabaseHelper _database;
  final Random _random;
  static final Pbkdf2 _hasher = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (await _database.userByEmail(normalizedEmail) != null) {
      throw const AuthException('Email ini sudah terdaftar. Silakan masuk.');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _hasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    try {
      final createdAt = DateTime.now().toUtc().toIso8601String();
      final encodedHash = base64Encode(await hash.extractBytes());
      final encodedSalt = base64Encode(salt);
      final id = await _database.insertUserAndSetSession({
        'name': name.trim(),
        'email': normalizedEmail,
        'password_hash': encodedHash,
        'password_salt': encodedSalt,
        'created_at': createdAt,
      });
      return UserModel(
        id: id,
        name: name.trim(),
        email: normalizedEmail,
        passwordHash: encodedHash,
        passwordSalt: encodedSalt,
        createdAt: createdAt,
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const AuthException('Email ini sudah terdaftar. Silakan masuk.');
      }
      throw const AuthException('Akun belum dapat dibuat. Coba lagi.');
    } on PlatformException {
      throw const AuthException('Penyimpanan lokal bermasalah. Coba lagi.');
    }
  }

  Future<UserModel> login({required String email, required String password}) async {
    final row = await _database.userByEmail(normalizeEmail(email));
    if (row == null) {
      throw const AuthException('Email atau kata sandi tidak sesuai.');
    }
    final user = UserModel.fromMap(row);
    final calculated = await _hasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(user.passwordSalt),
    );
    final matches = constantTimeBytesEquality(
      await calculated.extractBytes(),
      base64Decode(user.passwordHash),
    );
    if (!matches) {
      throw const AuthException('Email atau kata sandi tidak sesuai.');
    }
    await _database.setCurrentUser(user.id);
    return user;
  }

  Future<UserModel?> restoreSession() async {
    final id = await _database.currentUserId();
    if (id == null) return null;
    final row = await _database.userById(id);
    if (row == null) {
      await _database.setCurrentUser(null);
      return null;
    }
    return UserModel.fromMap(row);
  }

  Future<void> logout() => _database.setCurrentUser(null);
}

bool constantTimeBytesEquality(List<int> a, List<int> b) {
  var difference = a.length ^ b.length;
  for (var i = 0; i < max(a.length, b.length); i++) {
    difference |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
  }
  return difference == 0;
}
