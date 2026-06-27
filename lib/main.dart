import 'dart:convert';
import 'dart:typed_data';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const JokerCommerceAdminApp());
}

class JokerCommerceAdminApp extends StatelessWidget {
  const JokerCommerceAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joker Commerce Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
      ),
      home: const AuthGate(),
    );
  }
}


class AuthSession {
  static const String _tokenKey = 'joker_admin_access_token';

  static String? get token {
    final value = html.window.localStorage[_tokenKey];
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  static bool get hasToken => token != null;

  static void saveToken(String token) {
    html.window.localStorage[_tokenKey] = token;
  }

  static void clear() {
    html.window.localStorage.remove(_tokenKey);
    CurrentAdminSession.clear();
  }
}

class CurrentAdminSession {
  static Map<String, dynamic>? _user;

  static Map<String, dynamic>? get user => _user;

  static String get role => _user?['role']?.toString() ?? '';

  static bool get isSuperAdmin => role == 'super_admin';
  static bool get isTenantAdmin => role == 'tenant_admin';
  static bool get isManager => role == 'manager';
  static bool get isOrdersStaff => role == 'orders_staff';
  static bool get isInventoryStaff => role == 'inventory_staff';

  static bool get canViewProducts => isSuperAdmin || isTenantAdmin || isManager || isInventoryStaff;
  static bool get canViewOrders => isSuperAdmin || isTenantAdmin || isManager || isOrdersStaff;
  static bool get canViewAccounts => isSuperAdmin || isTenantAdmin;
  static bool get canViewBranding => isSuperAdmin || isTenantAdmin;
  static bool get canViewCommercial => isSuperAdmin;

  static void saveFromPayload(Map<String, dynamic> payload) {
    final rawUser = payload['user'];
    if (rawUser is Map<String, dynamic>) {
      _user = rawUser;
      return;
    }

    _user = payload;
  }

  static void clear() {
    _user = null;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AdminApi _api = AdminApi();
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _checkSession();
  }

  Future<bool> _checkSession() async {
    if (!AuthSession.hasToken) {
      return false;
    }

    try {
      await _api.fetchMe();
      return true;
    } catch (_) {
      AuthSession.clear();
      return false;
    }
  }

  void _onLoggedIn() {
    setState(() {
      _future = Future.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const ProductsDashboardPage();
        }

        return LoginPage(onLoggedIn: _onLoggedIn);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoggedIn,
  });

  final VoidCallback onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AdminApi _api = AdminApi();
  final TextEditingController _phoneController = TextEditingController(
    text: '07700000000',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'Admin@123456',
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _api.login(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      widget.onLoggedIn();
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 54,
                      color: Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'تسجيل دخول لوحة Joker Commerce',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ادخل بحساب Super Admin أو حساب مدير المتجر.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      onSubmitted: (_) => _isLoading ? null : _login(),
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isLoading ? 'جاري الدخول...' : 'دخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class AdminApi {
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String baseUrl = _configuredBaseUrl.trim().isNotEmpty
      ? _configuredBaseUrl.trim()
      : 'http://187.127.70.62:8088/api';

  final String tenantCode = 'demo';

  Map<String, String> get _jsonHeaders {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Tenant-Code': tenantCode,
    };

    final token = AuthSession.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Login API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    CurrentAdminSession.saveFromPayload(json);

    final token = json['access_token']?.toString() ?? '';

    if (token.isEmpty) {
      throw Exception('Login API Error: access token not found.');
    }

    AuthSession.saveToken(token);

    return json;
  }

  Future<Map<String, dynamic>> fetchMe() async {
    final uri = Uri.parse('$baseUrl/auth/me');

    final response = await http.get(
      uri,
      headers: _jsonHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Me API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    CurrentAdminSession.saveFromPayload(json);
    return json;
  }

  Future<void> logout() async {
    final uri = Uri.parse('$baseUrl/auth/logout');

    await http.post(
      uri,
      headers: _jsonHeaders,
    );

    AuthSession.clear();
  }



  Future<List<AdminProduct>> fetchProducts() async {
    final uri = Uri.parse('$baseUrl/admin/products?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];

    return list
        .map((item) => AdminProduct.fromJson(item as Map<String, dynamic>))
        .toList();
  }
  Future<List<AdminCategory>> fetchCategories() async {
    final uri = Uri.parse('$baseUrl/categories?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Categories API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];

    return list
        .map((item) => AdminCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadProductImage({
    required List<int> bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/uploads/product-image?tenant=$tenantCode');

    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final subtype = extension == 'jpg' ? 'jpeg' : extension;

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
          contentType: MediaType('image', subtype),
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Upload API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rawUrl = json['url']?.toString() ?? '';

    if (rawUrl.isEmpty) {
      return '';
    }

    final apiOrigin = Uri.parse(baseUrl).origin;

    return rawUrl
        .replaceFirst('http://localhost', apiOrigin)
        .replaceFirst('http://127.0.0.1:8099', apiOrigin)
        .replaceFirst('http://127.0.0.1', apiOrigin);
  }

  Future<List<AdminAccount>> fetchAccounts() async {
    final uri = Uri.parse('$baseUrl/admin/accounts');

    final response = await http.get(
      uri,
      headers: _jsonHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Accounts API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];

    return list
        .map((item) => AdminAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAccount({
    required String name,
    String? email,
    required String phone,
    required String password,
    required String role,
    int? tenantId,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/accounts');

    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
    };

    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }

    if (tenantId != null) {
      body['tenant_id'] = tenantId;
    }

    final response = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Create Account API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> updateAccountStatus(int accountId, bool isActive) async {
    final uri = Uri.parse('$baseUrl/admin/accounts/$accountId/status');

    final response = await http.patch(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'is_active': isActive,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Account Status API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> updateAccount({
    required int accountId,
    required String name,
    required String phone,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/accounts/$accountId');

    final response = await http.patch(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'role': role,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Account API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> updateAccountPassword(int accountId, String password) async {
    final uri = Uri.parse('$baseUrl/admin/accounts/$accountId/password');

    final response = await http.patch(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Account Password API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> createProduct(CreateProductRequest request) async {
    final uri = Uri.parse('$baseUrl/admin/products?tenant=$tenantCode');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('Create Product API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<AdminProduct> fetchProduct(int productId) async {
    final uri = Uri.parse('$baseUrl/admin/products/$productId?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Product Details API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminProduct.fromJson(json['data'] as Map<String, dynamic>);
  }
  Future<void> updateProduct(int productId, CreateProductRequest request) async {
    final uri = Uri.parse('$baseUrl/admin/products/$productId?tenant=$tenantCode');

    final response = await http.put(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Product API Error ${response.statusCode}: ${response.body}');
    }
  }
  Future<List<AdminOrder>> fetchOrders() async {
    final uri = Uri.parse('$baseUrl/admin/orders?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Orders API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>? ?? [];

    return list
        .map((item) => AdminOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminOrder> fetchOrder(String orderNumber) async {
    final uri = Uri.parse('$baseUrl/admin/orders/$orderNumber?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Order Details API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminOrder.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> updateOrderStatus(String orderNumber, String status) async {
    final uri = Uri.parse('$baseUrl/orders/$orderNumber/status?tenant=$tenantCode');

    final response = await http.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
      body: jsonEncode({
        'status': status,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Order Status API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<AdminBrandingSettings> fetchTenantBranding() async {
    final uri = Uri.parse('$baseUrl/admin/tenant-branding?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Branding API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminBrandingSettings.fromJson(
      json['branding'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<AdminBrandingSettings> updateTenantBranding(AdminBrandingSettings settings) async {
    final uri = Uri.parse('$baseUrl/admin/tenant-branding?tenant=$tenantCode');

    final response = await http.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Code': tenantCode,
      },
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Branding API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminBrandingSettings.fromJson(
      json['branding'] as Map<String, dynamic>? ?? {},
    );
  }


  Future<List<AdminPlan>> fetchPlans() async {
    final uri = Uri.parse('$baseUrl/admin/plans');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Plans API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];

    return data
        .map((item) => AdminPlan.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminFeatureFlag>> fetchFeatureFlags() async {
    final uri = Uri.parse('$baseUrl/admin/feature-flags?tenant=$tenantCode');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Feature Flags API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['features'] as List<dynamic>? ?? [];

    return data
        .map((item) => AdminFeatureFlag.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminFeatureFlag>> updateFeatureFlags(Map<String, bool> features) async {
    final uri = Uri.parse('$baseUrl/admin/feature-flags?tenant=$tenantCode');

    final response = await http.patch(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'features': features,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update Feature Flags API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['features'] as List<dynamic>? ?? [];

    return data
        .map((item) => AdminFeatureFlag.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class CreateProductVariantInput {
  const CreateProductVariantInput({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.quantity,
  });

  final int? id;
  final String name;
  final String? sku;
  final double? price;
  final double? salePrice;
  final int quantity;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'name': name,
      'sku': sku,
      'price': price,
      'sale_price': salePrice,
      'status': 'active',
      'inventory': [
        {
          'warehouse_id': 1,
          'quantity': quantity,
          'reserved_quantity': 0,
          'low_stock_alert_quantity': 1,
        }
      ],
    };

    if (id != null) {
      body['id'] = id;
    }

    return body;
  }
}

class CreateProductRequest {
  const CreateProductRequest({
    required this.categoryId,
    required this.name,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.shortDescription,
    required this.mainImageUrl,
    required this.quantity,
    required this.isFeatured,
    required this.hasVariants,
    required this.variants,
  });

  final int? categoryId;
  final String name;
  final String? sku;
  final double price;
  final double? salePrice;
  final String? shortDescription;
  final String? mainImageUrl;
  final int quantity;
  final bool isFeatured;
  final bool hasVariants;
  final List<CreateProductVariantInput> variants;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'price': price,
      'sale_price': salePrice,
      'short_description': shortDescription,
      'main_image_url': mainImageUrl,
      'is_featured': isFeatured,
      'has_variants': hasVariants,
      'requires_prescription': false,
      'status': 'active',
    };

    if (mainImageUrl != null && mainImageUrl!.trim().isNotEmpty) {
      body['images'] = [
        {
          'image_url': mainImageUrl,
          'sort_order': 1,
        }
      ];
    }

    if (hasVariants) {
      body['variants'] = variants.map((variant) => variant.toJson()).toList();
    } else {
      body['inventory'] = [
        {
          'warehouse_id': 1,
          'quantity': quantity,
          'reserved_quantity': 0,
          'low_stock_alert_quantity': 2,
        }
      ];
    }

    return body;
  }
}

class AdminProductVariant {
  const AdminProductVariant({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.quantity,
  });

  final int id;
  final String name;
  final String? sku;
  final double? price;
  final double? salePrice;
  final int quantity;
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.availableQuantity,
    required this.status,
    required this.hasVariants,
    required this.isFeatured,
    required this.categoryId,
    required this.categoryName,
    required this.mainImageUrl,
    required this.variantsCount,
    required this.variants,
  });

  final int id;
  final String name;
  final String slug;
  final String? sku;
  final double price;
  final double? salePrice;
  final int availableQuantity;
  final String status;
  final bool hasVariants;
  final bool isFeatured;
  final int? categoryId;
  final String? categoryName;
  final String? mainImageUrl;
  final int variantsCount;
  final List<AdminProductVariant> variants;

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final variantsJson = json['variants'] as List<dynamic>? ?? [];
    final inventoryJson = json['inventory'] as List<dynamic>? ?? [];

    int quantityForVariant(int variantId) {
      for (final item in inventoryJson) {
        if (item is Map<String, dynamic>) {
          final itemVariantId = int.tryParse(item['variant_id']?.toString() ?? '');
          if (itemVariantId == variantId) {
            return int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          }
        }
      }

      return 0;
    }

    final parsedVariants = variantsJson
        .whereType<Map<String, dynamic>>()
        .map((variant) {
          final id = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;

          return AdminProductVariant(
            id: id,
            name: variant['name']?.toString() ?? '',
            sku: variant['sku']?.toString(),
            price: variant['price'] == null
                ? null
                : double.tryParse(variant['price'].toString()),
            salePrice: variant['sale_price'] == null
                ? null
                : double.tryParse(variant['sale_price'].toString()),
            quantity: quantityForVariant(id),
          );
        })
        .toList();

    return AdminProduct(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      sku: json['sku']?.toString(),
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      salePrice: json['sale_price'] == null
          ? null
          : double.tryParse(json['sale_price'].toString()),
      availableQuantity: int.tryParse(json['available_quantity']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? '',
      hasVariants: json['has_variants'] == true || parsedVariants.isNotEmpty,
      isFeatured: json['is_featured'] == true,
      categoryId: int.tryParse(category?['id']?.toString() ?? ''),
      categoryName: category?['name']?.toString(),
      mainImageUrl: json['main_image_url']?.toString(),
      variantsCount: parsedVariants.length,
      variants: parsedVariants,
    );
  }

  double get effectivePrice => salePrice ?? price;

  String get priceText => '${effectivePrice.toStringAsFixed(0)} د.ع';

  bool get isActive => status == 'active';

  bool get isLowStock => availableQuantity <= 3;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return name.toLowerCase().contains(q) ||
        slug.toLowerCase().contains(q) ||
        (sku ?? '').toLowerCase().contains(q) ||
        (categoryName ?? '').toLowerCase().contains(q);
  }
}

class AdminOrderItem {
  const AdminOrderItem({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.productName,
    required this.variantName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final int id;
  final int productId;
  final int? productVariantId;
  final String productName;
  final String? variantName;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double total;

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      productVariantId: int.tryParse(json['product_variant_id']?.toString() ?? ''),
      productName: json['product_name']?.toString() ?? '',
      variantName: json['variant_name']?.toString(),
      sku: json['sku']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }

  String get unitPriceText => '${unitPrice.toStringAsFixed(0)} د.ع';

  String get totalText => '${total.toStringAsFixed(0)} د.ع';
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.deliveryCity,
    required this.deliveryArea,
    required this.deliveryAddress,
    required this.deliveryNearestPoint,
    required this.branchName,
    required this.warehouseName,
    required this.items,
    required this.customerNotes,
    required this.createdAt,
  });

  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? deliveryCity;
  final String? deliveryArea;
  final String? deliveryAddress;
  final String? deliveryNearestPoint;
  final String? branchName;
  final String? warehouseName;
  final List<AdminOrderItem> items;
  final String? customerNotes;
  final DateTime? createdAt;

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    final delivery = json['delivery'] as Map<String, dynamic>? ?? {};
    final branch = json['branch'] as Map<String, dynamic>? ?? {};
    final warehouse = json['warehouse'] as Map<String, dynamic>? ?? {};
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return AdminOrder(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      customerName: customer['name']?.toString() ?? '',
      customerPhone: customer['phone']?.toString() ?? '',
      customerEmail: customer['email']?.toString(),
      deliveryCity: delivery['city']?.toString(),
      deliveryArea: delivery['area']?.toString(),
      deliveryAddress: delivery['address']?.toString(),
      deliveryNearestPoint: delivery['nearest_point']?.toString(),
      branchName: branch['name']?.toString(),
      warehouseName: warehouse['name']?.toString(),
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(AdminOrderItem.fromJson)
          .toList(),
      customerNotes: json['customer_notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get totalText => '${total.toStringAsFixed(0)} د.ع';

  String get subtotalText => '${subtotal.toStringAsFixed(0)} د.ع';

  String get deliveryFeeText => '${deliveryFee.toStringAsFixed(0)} د.ع';

  String get discountText => '${discount.toStringAsFixed(0)} د.ع';

  int get itemsCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'جديد';
      case 'confirmed':
        return 'تم التأكيد';
      case 'preparing':
        return 'قيد التجهيز';
      case 'out_for_delivery':
        return 'خرج للتوصيل';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'paid':
        return 'مدفوع';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return paymentStatus;
    }
  }

  String get createdAtText {
    final date = createdAt;
    if (date == null) {
      return '-';
    }

    final local = date.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return orderNumber.toLowerCase().contains(q) ||
        customerName.toLowerCase().contains(q) ||
        customerPhone.toLowerCase().contains(q) ||
        (deliveryCity ?? '').toLowerCase().contains(q) ||
        (deliveryAddress ?? '').toLowerCase().contains(q);
  }

}
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.tenantId,
    this.tenantName,
  });

  final int id;
  final int? tenantId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final String? tenantName;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'];

    return AdminAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tenantId: (json['tenant_id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      tenantName: tenant is Map<String, dynamic> ? tenant['name']?.toString() : null,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'tenant_admin':
        return 'مدير متجر';
      case 'manager':
        return 'مدير';
      case 'orders_staff':
        return 'موظف طلبات';
      case 'inventory_staff':
        return 'موظف مخزون';
      default:
        return role;
    }
  }

  String get statusLabel => isActive ? 'فعال' : 'معطل';
}

class ProductsDashboardPage extends StatefulWidget {
  const ProductsDashboardPage({super.key});

  @override
  State<ProductsDashboardPage> createState() => _ProductsDashboardPageState();
}

class _ProductsDashboardPageState extends State<ProductsDashboardPage> {
  final AdminApi _api = AdminApi();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<AdminProduct>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _api.fetchProducts();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchProducts();
    });
  }


  Future<void> _openAddProductDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductDialog(api: _api),
    );

    if (created == true) {
      _reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المنتج بنجاح')),
      );
    }
  }

  Future<void> _openEditProductDialog(AdminProduct product) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductDialog(
        api: _api,
        product: product,
      ),
    );

    if (updated == true) {
      _reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث المنتج بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          if (isMobile) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                title: const Text(
                  'إدارة المنتجات',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              drawer: const Drawer(child: AdminSidebar(isDrawer: true)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _openAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              ),
              body: DashboardBody(
                future: _future,
                searchController: _searchController,
                search: _search,
                onReload: _reload,
                onAdd: _openAddProductDialog,
                onEdit: _openEditProductDialog,
                isMobile: true,
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                const AdminSidebar(),
                Expanded(
                  child: DashboardBody(
                    future: _future,
                    searchController: _searchController,
                    search: _search,
                    onReload: _reload,
                    onAdd: _openAddProductDialog,
                    onEdit: _openEditProductDialog,
                    isMobile: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.future,
    required this.searchController,
    required this.search,
    required this.onReload,
    required this.onAdd,
    required this.onEdit,
    required this.isMobile,
  });

  final Future<List<AdminProduct>> future;
  final TextEditingController searchController;
  final String search;
  final VoidCallback onReload;
  final VoidCallback onAdd;
  final ValueChanged<AdminProduct> onEdit;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final padding = isMobile ? 14.0 : 22.0;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          DashboardHeader(
            searchController: searchController,
            onReload: onReload,
            onAdd: onAdd,
            isMobile: isMobile,
          ),
          Expanded(
            child: FutureBuilder<List<AdminProduct>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: snapshot.error.toString(),
                    onRetry: onReload,
                  );
                }

                final allProducts = snapshot.data ?? [];
                final products = allProducts.where((p) => p.matches(search)).toList();

                                if (isMobile) {
                  return RefreshIndicator(
                    onRefresh: () async => onReload(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.zero,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 14),
                          child: SummaryGrid(
                            products: allProducts,
                            isMobile: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
                          child: Row(
                            children: [
                              const Text(
                                'قائمة المنتجات',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${products.length} منتج',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (products.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: EmptyProducts(),
                          )
                        else
                          ...products.map(
                            (product) => Padding(
                              padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                              child: MobileProductCard(
                                product: product,
                                onEdit: () => onEdit(product),
                              ),
                            ),
                          ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding, 14),
                      child: SummaryGrid(
                        products: allProducts,
                        isMobile: isMobile,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
                      child: Row(
                        children: [
                          const Text(
                            'قائمة المنتجات',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${products.length} منتج',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: products.isEmpty
                          ? const EmptyProducts()
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                              itemCount: products.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final product = products[index];

                                if (isMobile) {
                                  return MobileProductCard(
                                    product: product,
                                    onEdit: () => onEdit(product),
                                  );
                                }

                                return DesktopProductRow(
                                  product: product,
                                  onEdit: () => onEdit(product),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.searchController,
    required this.onReload,
    required this.onAdd,
    required this.isMobile,
  });

  final TextEditingController searchController;
  final VoidCallback onReload;
  final VoidCallback onAdd;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 14 : 22),
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeaderText(),
                const SizedBox(height: 16),
                HeaderSearch(controller: searchController),
              ],
            )
          : Row(
              children: [
                const Expanded(child: HeaderText()),
                SizedBox(
                  width: 360,
                  child: HeaderSearch(controller: searchController),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onReload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                ),
              ],
            ),
    );
  }
}

class HeaderText extends StatelessWidget {
  const HeaderText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إدارة المنتجات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'تابع المنتجات، الأسعار، الخيارات، والمخزون من مكان واحد.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class HeaderSearch extends StatelessWidget {
  const HeaderSearch({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'بحث عن منتج أو SKU أو قسم...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid({
    super.key,
    required this.products,
    required this.isMobile,
  });

  final List<AdminProduct> products;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final active = products.where((p) => p.isActive).length;
    final withVariants = products.where((p) => p.hasVariants).length;
    final lowStock = products.where((p) => p.isLowStock).length;
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.availableQuantity);

    final cards = [
      SummaryData('عدد المنتجات', products.length.toString(), Icons.inventory_2_outlined),
      SummaryData('منتجات فعالة', active.toString(), Icons.check_circle_outline),
      SummaryData('بخيارات', withVariants.toString(), Icons.tune),
      SummaryData('تنبيه مخزون', lowStock.toString(), Icons.warning_amber_rounded),
      SummaryData('المخزون المتاح', totalStock.toString(), Icons.warehouse_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile ? 2 : 5;
        final gap = isMobile ? 10.0 : 12.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: SummaryCard(data: card, compact: isMobile),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class SummaryData {
  const SummaryData(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.data,
    required this.compact,
  });

  final SummaryData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 112 : 116,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: const Color(0xFF0F172A)),
              const Spacer(),
              Text(
                data.value,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: compact ? 23 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopProductRow extends StatelessWidget {
  const DesktopProductRow({
    super.key,
    required this.product,
    required this.onEdit,
  });

  final AdminProduct product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          ProductImage(product: product, size: 64),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: ProductInfo(product: product, maxLines: 1),
          ),
          Expanded(child: InfoBlock(title: 'السعر', value: product.priceText)),
          Expanded(
            child: InfoBlock(
              title: 'المخزون',
              value: product.availableQuantity.toString(),
              color: product.isLowStock ? const Color(0xFFDC2626) : null,
            ),
          ),
          Expanded(
            child: InfoBlock(
              title: 'الخيارات',
              value: product.variantsCount == 0 ? '-' : product.variantsCount.toString(),
            ),
          ),
          StatusChip(status: product.status),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('تعديل'),
          ),
        ],
      ),
    );
  }
}

class MobileProductCard extends StatelessWidget {
  const MobileProductCard({
    super.key,
    required this.product,
    required this.onEdit,
  });

  final AdminProduct product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              ProductImage(product: product, size: 58),
              const SizedBox(width: 12),
              Expanded(child: ProductInfo(product: product, maxLines: 2)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: MetricBox(title: 'السعر', value: product.priceText)),
              const SizedBox(width: 8),
              Expanded(
                child: MetricBox(
                  title: 'المخزون',
                  value: product.availableQuantity.toString(),
                  color: product.isLowStock ? const Color(0xFFDC2626) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricBox(
                  title: 'الخيارات',
                  value: product.variantsCount == 0 ? '-' : product.variantsCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusChip(status: product.status),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('تعديل'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    required this.size,
  });

  final AdminProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.mainImageUrl;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A))
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A));
              },
            ),
    );
  }
}

class ProductInfo extends StatelessWidget {
  const ProductInfo({
    super.key,
    required this.product,
    required this.maxLines,
  });

  final AdminProduct product;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            MiniTag(product.categoryName ?? 'بدون قسم'),
            MiniTag(product.hasVariants ? 'خيارات' : 'منتج مفرد'),
            if (product.isFeatured) const MiniTag('مميز'),
            if (product.sku != null && product.sku!.isNotEmpty) MiniTag(product.sku!),
          ],
        ),
      ],
    );
  }
}

class InfoBlock extends StatelessWidget {
  const InfoBlock({
    super.key,
    required this.title,
    required this.value,
    this.color,
  });

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color ?? const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class MetricBox extends StatelessWidget {
  const MetricBox({
    super.key,
    required this.title,
    required this.value,
    this.color,
  });

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'فعال' : status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MiniTag extends StatelessWidget {
  const MiniTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    this.isDrawer = false,
    this.selectedSection = 'products',
  });

  final bool isDrawer;
  final String selectedSection;

  void _openProducts(BuildContext context) {
    if (selectedSection == 'products') {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProductsDashboardPage(),
      ),
    );
  }

  void _openOrders(BuildContext context) {
    if (selectedSection == 'orders') {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OrdersDashboardPage(),
      ),
    );
  }



  void _openAccounts(BuildContext context) {
    if (selectedSection == 'accounts') {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AccountsDashboardPage(),
      ),
    );
  }

  void _openCommercialSettings(BuildContext context) {
    if (selectedSection == 'commercial') {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const CommercialSettingsPage(),
      ),
    );
  }

  void _openBranding(BuildContext context) {
    if (selectedSection == 'branding') {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const BrandingSettingsPage(),
      ),
    );
  }


  Future<void> _logout(BuildContext context) async {
    if (isDrawer) {
      Navigator.of(context).pop();
    }

    try {
      await AdminApi().logout();
    } catch (_) {
      AuthSession.clear();
    }

    html.window.location.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isDrawer ? double.infinity : 250,
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Joker Commerce',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'لوحة تحكم المتجر',
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              if (CurrentAdminSession.canViewProducts)
              SidebarItem(
                Icons.inventory_2_outlined,
                'المنتجات',
                selectedSection == 'products',
                onTap: () => _openProducts(context),
              ),
              if (CurrentAdminSession.canViewOrders)
              SidebarItem(
                Icons.receipt_long_outlined,
                'الطلبات',
                selectedSection == 'orders',
                onTap: () => _openOrders(context),
              ),
              if (CurrentAdminSession.canViewAccounts)
              SidebarItem(
                Icons.manage_accounts_outlined,
                'الحسابات',
                selectedSection == 'accounts',
                onTap: () => _openAccounts(context),
              ),
              if (CurrentAdminSession.canViewProducts) const SidebarItem(Icons.category_outlined, 'الأقسام', false),
              if (CurrentAdminSession.canViewProducts) const SidebarItem(Icons.storefront_outlined, 'المخازن والفروع', false),
              if (CurrentAdminSession.canViewProducts || CurrentAdminSession.canViewOrders) const SidebarItem(Icons.local_offer_outlined, 'الخصومات', false),
              if (CurrentAdminSession.canViewCommercial)
              SidebarItem(
                Icons.workspace_premium_outlined,
                'الباقات والميزات',
                selectedSection == 'commercial',
                onTap: () => _openCommercialSettings(context),
              ),
              if (CurrentAdminSession.canViewBranding)
              SidebarItem(
                Icons.settings_outlined,
                'إعدادات الهوية',
                selectedSection == 'branding',
                onTap: () => _openBranding(context),
              ),
              SidebarItem(
                Icons.logout_outlined,
                'تسجيل الخروج',
                false,
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 12),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenant: demo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'White-Label Store',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  const SidebarItem(
    this.icon,
    this.label,
    this.selected, {
    super.key,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: Colors.white.withValues(alpha: 0.14)) : null,
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          icon,
          color: selected ? Colors.white : const Color(0xFF94A3B8),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFCBD5E1),
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class AccountsDashboardPage extends StatefulWidget {
  const AccountsDashboardPage({super.key});

  @override
  State<AccountsDashboardPage> createState() => _AccountsDashboardPageState();
}

class _AccountsDashboardPageState extends State<AccountsDashboardPage> {
  final AdminApi _api = AdminApi();
  late Future<List<AdminAccount>> _future;

  Future<void> _toggleAccountStatus(AdminAccount account) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _api.updateAccountStatus(account.id, !account.isActive);
      messenger.showSnackBar(SnackBar(content: Text(account.isActive ? 'تم تعطيل الحساب' : 'تم تفعيل الحساب')));
      await _reload();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openEditAccountDialog(AdminAccount account) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account.name);
    final phoneController = TextEditingController(text: account.phone);
    var role = account.role == 'super_admin' ? 'manager' : account.role;
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('تعديل الحساب'),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم'), validator: (value) => value == null || value.trim().isEmpty ? 'مطلوب' : null),
                        const SizedBox(height: 12),
                        TextFormField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (value) => value == null || value.trim().isEmpty ? 'مطلوب' : null),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(labelText: 'الدور'),
                          items: const [
                            DropdownMenuItem(value: 'tenant_admin', child: Text('مدير متجر')),
                            DropdownMenuItem(value: 'manager', child: Text('مدير')),
                            DropdownMenuItem(value: 'orders_staff', child: Text('موظف طلبات')),
                            DropdownMenuItem(value: 'inventory_staff', child: Text('موظف مخزون')),
                          ],
                          onChanged: saving ? null : (value) => setDialogState(() => role = value ?? 'manager'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
                  FilledButton.icon(
                    onPressed: saving ? null : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => saving = true);
                      try {
                        await _api.updateAccount(accountId: account.id, name: nameController.text.trim(), phone: phoneController.text.trim(), role: role);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(const SnackBar(content: Text('تم تعديل الحساب بنجاح')));
                        await _reload();
                      } catch (error) {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                      }
                    },
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'جاري الحفظ' : 'حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _openChangeAccountPasswordDialog(AdminAccount account) async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('تغيير كلمة مرور '),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: TextFormField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'), validator: (value) => value == null || value.trim().length < 8 ? '8 أحرف على الأقل' : null),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
                  FilledButton.icon(
                    onPressed: saving ? null : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => saving = true);
                      try {
                        await _api.updateAccountPassword(account.id, passwordController.text);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
                      } catch (error) {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                      }
                    },
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_reset_outlined),
                    label: Text(saving ? 'جاري الحفظ' : 'حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      passwordController.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _api.fetchAccounts();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchAccounts();
    });
    await _future;
  }

  Future<void> _openCreateAccountDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'manager';
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('إضافة حساب'),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم'), validator: (value) => value == null || value.trim().isEmpty ? 'مطلوب' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (value) => value == null || value.trim().isEmpty ? 'مطلوب' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور'), validator: (value) => value == null || value.trim().length < 8 ? '8 أحرف على الأقل' : null),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: role,
                            decoration: const InputDecoration(labelText: 'الدور'),
                            items: const [
                              DropdownMenuItem(value: 'tenant_admin', child: Text('مدير متجر')),
                              DropdownMenuItem(value: 'manager', child: Text('مدير')),
                              DropdownMenuItem(value: 'orders_staff', child: Text('موظف طلبات')),
                              DropdownMenuItem(value: 'inventory_staff', child: Text('موظف مخزون')),
                            ],
                            onChanged: saving ? null : (value) => setDialogState(() => role = value ?? 'manager'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
                  FilledButton.icon(
                    onPressed: saving ? null : () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }

                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);

                      setDialogState(() => saving = true);

                      try {
                        await _api.createAccount(name: nameController.text.trim(), phone: phoneController.text.trim(), password: passwordController.text, role: role, tenantId: 1);
                        if (!mounted) {
                          return;
                        }
                        navigator.pop();
                        messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح')));
                        await _reload();
                      } catch (error) {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                      }
                    },
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                    label: Text(saving ? 'جاري الحفظ' : 'حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      passwordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return Scaffold(
            drawer: isMobile ? const Drawer(child: AdminSidebar(isDrawer: true, selectedSection: 'accounts')) : null,
            appBar: isMobile
                ? AppBar(
                    title: const Text('إدارة الحسابات'),
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
                  )
                : null,
            floatingActionButton: FloatingActionButton.extended(onPressed: _openCreateAccountDialog, icon: const Icon(Icons.add), label: const Text('إضافة حساب')),
            body: Row(
              children: [
                if (!isMobile) const AdminSidebar(selectedSection: 'accounts'),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: RefreshIndicator(
                      onRefresh: _reload,
                      child: FutureBuilder<List<AdminAccount>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return ListView(
                              padding: EdgeInsets.all(isMobile ? 14 : 24),
                              children: [
                                _AccountsHeader(isMobile: isMobile, onReload: _reload),
                                const SizedBox(height: 18),
                                ErrorPanel(message: snapshot.error.toString(), onRetry: _reload),
                              ],
                            );
                          }

                          final accounts = snapshot.data ?? [];

                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(isMobile ? 14 : 24),
                            children: [
                              _AccountsHeader(isMobile: isMobile, onReload: _reload),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _AccountStatCard(title: 'كل الحسابات', value: accounts.length.toString(), icon: Icons.manage_accounts_outlined),
                                  _AccountStatCard(title: 'فعالة', value: accounts.where((a) => a.isActive).length.toString(), icon: Icons.check_circle_outline),
                                  _AccountStatCard(title: 'معطلة', value: accounts.where((a) => !a.isActive).length.toString(), icon: Icons.block_outlined),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Text('قائمة الحسابات', style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w900)),
                                  const Spacer(),
                                  Text('${accounts.length} حساب', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (accounts.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: cardDecoration(),
                                  child: const Text('لا توجد حسابات إدارية بعد.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                )
                              else
                                ...accounts.map((account) => Padding(padding: const EdgeInsets.only(bottom: 12), child: AccountCard(account: account, isMobile: isMobile, onToggleStatus: () => _toggleAccountStatus(account), onEdit: () => _openEditAccountDialog(account), onChangePassword: () => _openChangeAccountPasswordDialog(account)))),
                              const SizedBox(height: 36),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({required this.isMobile, required this.onReload});

  final bool isMobile;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          const Icon(Icons.manage_accounts_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة الحسابات', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('عرض حسابات المنصة ومدراء المتاجر والموظفين.', style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (!isMobile) OutlinedButton.icon(onPressed: onReload, style: OutlinedButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.refresh), label: const Text('تحديث')),
        ],
      ),
    );
  }
}

class _AccountStatCard extends StatelessWidget {
  const _AccountStatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 230,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, required this.isMobile, required this.onToggleStatus, required this.onEdit, required this.onChangePassword});

  final AdminAccount account;
  final bool isMobile;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final statusColor = account.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(account.isActive ? Icons.verified_user_outlined : Icons.block_outlined, color: statusColor),
                const SizedBox(width: 10),
                Expanded(child: Text(account.name.isEmpty ? '-' : account.name, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 12),
            InfoBlock(title: 'البريد', value: account.email.isEmpty ? '-' : account.email),
            const SizedBox(height: 10),
            InfoBlock(title: 'الهاتف', value: account.phone.isEmpty ? '-' : account.phone),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: InfoBlock(title: 'الدور', value: account.roleLabel)), const SizedBox(width: 10), Expanded(child: InfoBlock(title: 'الحالة', value: account.statusLabel))]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')), OutlinedButton.icon(onPressed: onChangePassword, icon: const Icon(Icons.lock_reset_outlined), label: const Text('كلمة المرور')), OutlinedButton.icon(onPressed: onToggleStatus, icon: Icon(account.isActive ? Icons.block_outlined : Icons.check_circle_outline), label: Text(account.isActive ? 'تعطيل' : 'تفعيل'))]),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Icon(account.isActive ? Icons.verified_user_outlined : Icons.block_outlined, color: statusColor),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: InfoBlock(title: 'الاسم', value: account.name.isEmpty ? '-' : account.name)),
          Expanded(child: InfoBlock(title: 'البريد', value: account.email.isEmpty ? '-' : account.email)),
          Expanded(child: InfoBlock(title: 'الهاتف', value: account.phone.isEmpty ? '-' : account.phone)),
          Expanded(child: InfoBlock(title: 'الدور', value: account.roleLabel)),
          Expanded(child: InfoBlock(title: 'الحالة', value: account.statusLabel)),
          const SizedBox(width: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')), OutlinedButton.icon(onPressed: onChangePassword, icon: const Icon(Icons.lock_reset_outlined), label: const Text('كلمة المرور')), OutlinedButton.icon(onPressed: onToggleStatus, icon: Icon(account.isActive ? Icons.block_outlined : Icons.check_circle_outline), label: Text(account.isActive ? 'تعطيل' : 'تفعيل'))]),
        ],
      ),
    );
  }
}


class OrdersDashboardPage extends StatefulWidget {
  const OrdersDashboardPage({super.key});

  @override
  State<OrdersDashboardPage> createState() => _OrdersDashboardPageState();
}

class _OrdersDashboardPageState extends State<OrdersDashboardPage> {
  final AdminApi _api = AdminApi();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<AdminOrder>> _future;
  String _search = '';
  String _statusFilter = 'all';

  static const List<String> _statuses = [
    'all',
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _future = _api.fetchOrders();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchOrders();
    });
  }

  Future<void> _openOrderDetails(AdminOrder order) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OrderDetailsDialog(
        api: _api,
        order: order,
      ),
    );

    if (changed == true) {
      _reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    }
  }

  List<AdminOrder> _filterOrders(List<AdminOrder> orders) {
    return orders.where((order) {
      final matchesSearch = order.matches(_search);
      final matchesStatus = _statusFilter == 'all' || order.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'الكل';
      case 'pending':
        return 'جديد';
      case 'confirmed':
        return 'تم التأكيد';
      case 'preparing':
        return 'قيد التجهيز';
      case 'out_for_delivery':
        return 'خرج للتوصيل';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          if (isMobile) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                title: const Text(
                  'إدارة الطلبات',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              drawer: const Drawer(child: AdminSidebar(isDrawer: true, selectedSection: 'orders')),
              body: OrdersDashboardBody(
                future: _future,
                searchController: _searchController,
                search: _search,
                statusFilter: _statusFilter,
                statuses: _statuses,
                statusLabel: _statusLabel,
                onStatusFilterChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
                onReload: _reload,
                onOpenDetails: _openOrderDetails,
                filterOrders: _filterOrders,
                isMobile: true,
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                const AdminSidebar(selectedSection: 'orders'),
                Expanded(
                  child: OrdersDashboardBody(
                    future: _future,
                    searchController: _searchController,
                    search: _search,
                    statusFilter: _statusFilter,
                    statuses: _statuses,
                    statusLabel: _statusLabel,
                    onStatusFilterChanged: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                    onReload: _reload,
                    onOpenDetails: _openOrderDetails,
                    filterOrders: _filterOrders,
                    isMobile: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrdersDashboardBody extends StatelessWidget {
  const OrdersDashboardBody({
    super.key,
    required this.future,
    required this.searchController,
    required this.search,
    required this.statusFilter,
    required this.statuses,
    required this.statusLabel,
    required this.onStatusFilterChanged,
    required this.onReload,
    required this.onOpenDetails,
    required this.filterOrders,
    required this.isMobile,
  });

  final Future<List<AdminOrder>> future;
  final TextEditingController searchController;
  final String search;
  final String statusFilter;
  final List<String> statuses;
  final String Function(String status) statusLabel;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onReload;
  final ValueChanged<AdminOrder> onOpenDetails;
  final List<AdminOrder> Function(List<AdminOrder> orders) filterOrders;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final padding = isMobile ? 14.0 : 22.0;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          OrdersHeader(
            searchController: searchController,
            statusFilter: statusFilter,
            statuses: statuses,
            statusLabel: statusLabel,
            onStatusFilterChanged: onStatusFilterChanged,
            onReload: onReload,
            isMobile: isMobile,
          ),
          Expanded(
            child: FutureBuilder<List<AdminOrder>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: snapshot.error.toString(),
                    onRetry: onReload,
                  );
                }

                final allOrders = snapshot.data ?? [];
                final orders = filterOrders(allOrders);

                                if (isMobile) {
                  return RefreshIndicator(
                    onRefresh: () async => onReload(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.zero,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 14),
                          child: OrdersSummaryGrid(
                            orders: allOrders,
                            isMobile: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
                          child: Row(
                            children: [
                              const Text(
                                'قائمة الطلبات',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${orders.length} طلب',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (orders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: EmptyOrders(),
                          )
                        else
                          ...orders.map(
                            (order) => Padding(
                              padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                              child: MobileOrderCard(
                                order: order,
                                onOpenDetails: () => onOpenDetails(order),
                              ),
                            ),
                          ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding, 14),
                      child: OrdersSummaryGrid(
                        orders: allOrders,
                        isMobile: isMobile,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
                      child: Row(
                        children: [
                          const Text(
                            'قائمة الطلبات',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${orders.length} طلب',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: orders.isEmpty
                          ? const EmptyOrders()
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = orders[index];

                                if (isMobile) {
                                  return MobileOrderCard(
                                    order: order,
                                    onOpenDetails: () => onOpenDetails(order),
                                  );
                                }

                                return DesktopOrderRow(
                                  order: order,
                                  onOpenDetails: () => onOpenDetails(order),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersHeader extends StatelessWidget {
  const OrdersHeader({
    super.key,
    required this.searchController,
    required this.statusFilter,
    required this.statuses,
    required this.statusLabel,
    required this.onStatusFilterChanged,
    required this.onReload,
    required this.isMobile,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final List<String> statuses;
  final String Function(String status) statusLabel;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onReload;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'بحث برقم الطلب أو اسم الزبون أو الهاتف...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final filter = DropdownButtonFormField<String>(
      value: statusFilter,
      items: statuses
          .map(
            (status) => DropdownMenuItem<String>(
              value: status,
              child: Text(statusLabel(status)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onStatusFilterChanged(value);
        }
      },
      decoration: InputDecoration(
        labelText: 'الحالة',
        prefixIcon: const Icon(Icons.filter_alt_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Container(
      margin: EdgeInsets.all(isMobile ? 14 : 22),
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _OrdersHeaderText(),
                const SizedBox(height: 16),
                search,
                const SizedBox(height: 12),
                filter,
              ],
            )
          : Row(
              children: [
                const Expanded(child: _OrdersHeaderText()),
                SizedBox(width: 360, child: search),
                const SizedBox(width: 12),
                SizedBox(width: 190, child: filter),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onReload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                ),
              ],
            ),
    );
  }
}

class _OrdersHeaderText extends StatelessWidget {
  const _OrdersHeaderText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إدارة الطلبات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'تابع طلبات الزبائن، تفاصيل العنوان، المنتجات، وتغيير حالة الطلب.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class OrdersSummaryGrid extends StatelessWidget {
  const OrdersSummaryGrid({
    super.key,
    required this.orders,
    required this.isMobile,
  });

  final List<AdminOrder> orders;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((o) => o.status == 'pending').length;
    final processing = orders.where((o) => o.status == 'confirmed').length;
    final shipped = orders.where((o) => o.status == 'preparing').length;
    final delivered = orders.where((o) => o.status == 'delivered').length;
    final totalSales = orders
        .where((o) => o.status != 'cancelled')
        .fold<double>(0, (sum, order) => sum + order.total);

    final cards = [
      SummaryData('كل الطلبات', orders.length.toString(), Icons.receipt_long_outlined),
      SummaryData('جديد', pending.toString(), Icons.fiber_new_outlined),
      SummaryData('قيد التجهيز', processing.toString(), Icons.inventory_outlined),
      SummaryData('تم الشحن', shipped.toString(), Icons.local_shipping_outlined),
      SummaryData('تم التسليم', delivered.toString(), Icons.check_circle_outline),
      SummaryData('إجمالي غير ملغي', '${totalSales.toStringAsFixed(0)} د.ع', Icons.payments_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile ? 2 : 6;
        final gap = isMobile ? 10.0 : 12.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: SummaryCard(data: card, compact: isMobile),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DesktopOrderRow extends StatelessWidget {
  const DesktopOrderRow({
    super.key,
    required this.order,
    required this.onOpenDetails,
  });

  final AdminOrder order;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OrderMainInfo(order: order),
          ),
          Expanded(
            flex: 2,
            child: InfoBlock(title: 'الزبون', value: order.customerName.isEmpty ? '-' : order.customerName),
          ),
          Expanded(child: InfoBlock(title: 'الهاتف', value: order.customerPhone.isEmpty ? '-' : order.customerPhone)),
          Expanded(child: InfoBlock(title: 'المجموع', value: order.totalText)),
          Expanded(child: InfoBlock(title: 'المنتجات', value: order.itemsCount.toString())),
          OrderStatusChip(status: order.status, label: order.statusLabel),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onOpenDetails,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('تفاصيل'),
          ),
        ],
      ),
    );
  }
}

class MobileOrderCard extends StatelessWidget {
  const MobileOrderCard({
    super.key,
    required this.order,
    required this.onOpenDetails,
  });

  final AdminOrder order;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderMainInfo(order: order),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: MetricBox(title: 'المجموع', value: order.totalText)),
              const SizedBox(width: 8),
              Expanded(child: MetricBox(title: 'المنتجات', value: order.itemsCount.toString())),
              const SizedBox(width: 8),
              Expanded(child: MetricBox(title: 'الدفع', value: order.paymentStatusLabel)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OrderStatusChip(status: order.status, label: order.statusLabel),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('تفاصيل'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OrderMainInfo extends StatelessWidget {
  const OrderMainInfo({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.orderNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            MiniTag(order.createdAtText),
            if (order.deliveryCity != null && order.deliveryCity!.isNotEmpty) MiniTag(order.deliveryCity!),
            if (order.paymentStatus.isNotEmpty) MiniTag(order.paymentStatusLabel),
          ],
        ),
      ],
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status) {
      case 'pending':
        color = const Color(0xFF2563EB);
        break;
      case 'confirmed':
        color = const Color(0xFF9333EA);
        break;
      case 'preparing':
        color = const Color(0xFFF59E0B);
        break;
      case 'out_for_delivery':
        color = const Color(0xFF0EA5E9);
        break;
      case 'delivered':
        color = const Color(0xFF16A34A);
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        break;
      default:
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class OrderDetailsDialog extends StatefulWidget {
  const OrderDetailsDialog({
    super.key,
    required this.api,
    required this.order,
  });

  final AdminApi api;
  final AdminOrder order;

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  late String _status;
  bool _isSaving = false;

  static const List<String> _statuses = [
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'جديد';
      case 'confirmed':
        return 'تم التأكيد';
      case 'preparing':
        return 'قيد التجهيز';
      case 'out_for_delivery':
        return 'خرج للتوصيل';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Future<void> _saveStatus() async {
    if (_status == widget.order.status) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.api.updateOrderStatus(widget.order.orderNumber, _status);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة الطلب: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 8 : 18),
        titlePadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 14 : 24, 20, MediaQuery.sizeOf(context).width < 640 ? 14 : 24, 0),
        contentPadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 16, MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 10),
        actionsPadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 0, MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 18),
        title: Text(
          'تفاصيل الطلب ${order.orderNumber}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width < 640 ? MediaQuery.sizeOf(context).width - 36 : 860,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DialogSection(
                  title: 'معلومات الزبون والتوصيل',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 250, child: InfoBlock(title: 'اسم الزبون', value: order.customerName.isEmpty ? '-' : order.customerName)),
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 250, child: InfoBlock(title: 'الهاتف', value: order.customerPhone.isEmpty ? '-' : order.customerPhone)),
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 250, child: InfoBlock(title: 'المدينة/المحافظة', value: order.deliveryCity ?? '-')),
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 250, child: InfoBlock(title: 'المنطقة', value: order.deliveryArea ?? '-')),
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 520, child: InfoBlock(title: 'العنوان', value: order.deliveryAddress ?? '-')),
                      SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 250, child: InfoBlock(title: 'أقرب نقطة', value: order.deliveryNearestPoint ?? '-')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogSection(
                  title: 'المنتجات',
                  child: Column(
                    children: [
                      for (final item in order.items) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            children: [
                              SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 360, child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: [
                                        if (item.variantName != null && item.variantName!.isNotEmpty) MiniTag(item.variantName!),
                                        if (item.sku != null && item.sku!.isNotEmpty) MiniTag(item.sku!),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 90, child: InfoBlock(title: 'الكمية', value: item.quantity.toString())),
                              SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 130, child: InfoBlock(title: 'السعر', value: item.unitPriceText)),
                              SizedBox(width: MediaQuery.sizeOf(context).width < 640 ? double.infinity : 130, child: InfoBlock(title: 'المجموع', value: item.totalText)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogSection(
                  title: 'الدفع والحالة',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: 180, child: InfoBlock(title: 'المجموع الفرعي', value: order.subtotalText)),
                      SizedBox(width: 180, child: InfoBlock(title: 'التوصيل', value: order.deliveryFeeText)),
                      SizedBox(width: 180, child: InfoBlock(title: 'الخصم', value: order.discountText)),
                      SizedBox(width: 180, child: InfoBlock(title: 'الإجمالي', value: order.totalText)),
                      SizedBox(width: 220, child: InfoBlock(title: 'حالة الدفع', value: order.paymentStatusLabel)),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          items: _statuses
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(_statusLabel(status)),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _status = value;
                                    });
                                  }
                                },
                          decoration: const InputDecoration(
                            labelText: 'حالة الطلب',
                            prefixIcon: Icon(Icons.track_changes_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.customerNotes != null && order.customerNotes!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DialogSection(
                    title: 'ملاحظات الزبون',
                    child: Text(
                      order.customerNotes!,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveStatus,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الحالة'),
          ),
        ],
      ),
    );
  }
}

class EmptyOrders extends StatelessWidget {
  const EmptyOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا توجد طلبات مطابقة',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({
    super.key,
    required this.api,
    this.product,
  });

  final AdminApi api;
  final AdminProduct? product;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _VariantDraft {
  _VariantDraft({
    this.id,
  });

  final int? id;
  final TextEditingController name = TextEditingController();
  final TextEditingController sku = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController salePrice = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '0');

  void dispose() {
    name.dispose();
    sku.dispose();
    price.dispose();
    salePrice.dispose();
    quantity.dispose();
  }
}

class _AddProductDialogState extends State<AddProductDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _shortDescriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '0');

  late Future<List<AdminCategory>> _categoriesFuture;

  final List<_VariantDraft> _variants = [];

  int? _categoryId;
  bool _isFeatured = false;
  bool _hasVariants = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _selectedImageName;
  String? _localPreviewUrl;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.api.fetchCategories();

    final product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku ?? '';
      _priceController.text = product.price.toStringAsFixed(0);
      _salePriceController.text = product.salePrice?.toStringAsFixed(0) ?? '';
      _quantityController.text = product.availableQuantity.toString();
      _imageUrlController.text = product.mainImageUrl ?? '';
      _isFeatured = product.isFeatured;
      _hasVariants = product.hasVariants;

      if (product.variants.isNotEmpty) {
        _variants.clear();

        for (final productVariant in product.variants) {
          final variant = _VariantDraft(id: productVariant.id);
          variant.name.text = productVariant.name;
          variant.sku.text = productVariant.sku ?? '';
          variant.price.text = productVariant.price?.toStringAsFixed(0) ?? '';
          variant.salePrice.text = productVariant.salePrice?.toStringAsFixed(0) ?? '';
          variant.quantity.text = productVariant.quantity.toString();
          _variants.add(variant);
        }
      }    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _shortDescriptionController.dispose();
    _imageUrlController.dispose();
    _quantityController.dispose();

    if (_localPreviewUrl != null) {
      html.Url.revokeObjectUrl(_localPreviewUrl!);
    }

    for (final variant in _variants) {
      variant.dispose();
    }

    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp'
      ..multiple = false;

    input.click();

    await input.onChange.first;

    if (input.files == null || input.files!.isEmpty) {
      return;
    }

    final file = input.files!.first;
    final previewUrl = html.Url.createObjectUrl(file);

    if (_localPreviewUrl != null) {
      html.Url.revokeObjectUrl(_localPreviewUrl!);
    }

    setState(() {
      _localPreviewUrl = previewUrl;
      _selectedImageName = file.name;
    });

    final reader = html.FileReader();

    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;
    late final List<int> bytes;

    if (result is ByteBuffer) {
      bytes = result.asUint8List();
    } else if (result is Uint8List) {
      bytes = result;
    } else if (result is List<int>) {
      bytes = result;
    } else {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة الصورة')),
      );
      return;
    }

    setState(() {
      _isUploadingImage = true;
      _selectedImageName = file.name;
    });

    try {
      final url = await widget.api.uploadProductImage(
        bytes: bytes,
        fileName: file.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _imageUrlController.text = url;
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع صورة المنتج بنجاح')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: $error')),
      );
    }
  }

  void _addVariant() {
    setState(() {
      final variant = _VariantDraft();
      variant.price.text = _priceController.text.trim();
      variant.salePrice.text = _salePriceController.text.trim();
      _variants.add(variant);
    });
  }

  void _removeVariant(int index) {
    setState(() {
      final removed = _variants.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_hasVariants && _variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف خيار واحد على الأقل للمنتج')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = CreateProductRequest(
        categoryId: _categoryId,
        name: _nameController.text.trim(),
        sku: _cleanText(_skuController.text),
        price: double.parse(_priceController.text.trim()),
        salePrice: _parseOptionalDouble(_salePriceController.text),
        shortDescription: _cleanText(_shortDescriptionController.text),
        mainImageUrl: _cleanText(_imageUrlController.text),
        quantity: int.parse(_quantityController.text.trim()),
        isFeatured: _isFeatured,
        hasVariants: _hasVariants,
        variants: _variants.map((variant) {
          return CreateProductVariantInput(
            id: variant.id,
            name: variant.name.text.trim(),
            sku: _cleanText(variant.sku.text),
            price: _parseOptionalDouble(variant.price.text),
            salePrice: _parseOptionalDouble(variant.salePrice.text),
            quantity: int.parse(variant.quantity.text.trim()),
          );
        }).toList(),
      );

      if (_isEditMode) {
        await widget.api.updateProduct(widget.product!.id, request);
      } else {
        await widget.api.createProduct(request);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'تعذر تحديث المنتج: $error' : 'تعذر إضافة المنتج: $error')), 
      );

      setState(() {
        _isSaving = false;
      });
    }
  }

  String? _cleanText(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  double? _parseOptionalDouble(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return double.parse(clean);
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    return null;
  }

  String? _requiredNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    final parsed = double.tryParse(value.trim());

    if (parsed == null || parsed < 0) {
      return 'أدخل رقم صحيح';
    }

    return null;
  }

  String? _optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = double.tryParse(value.trim());

    if (parsed == null || parsed < 0) {
      return 'أدخل رقم صحيح';
    }

    return null;
  }

  String? _requiredInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    final parsed = int.tryParse(value.trim());

    if (parsed == null || parsed < 0) {
      return 'أدخل كمية صحيحة';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 8 : 18),
        titlePadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 14 : 24, 20, MediaQuery.sizeOf(context).width < 640 ? 14 : 24, 0),
        contentPadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 16, MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 10),
        actionsPadding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 0, MediaQuery.sizeOf(context).width < 640 ? 10 : 24, 18),
        title: Text(
          _isEditMode ? 'تعديل المنتج' : 'إضافة منتج جديد',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SizedBox(
          width: 840,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DialogSection(
                        title: 'معلومات المنتج',
                        child: _ResponsiveFields(
                          isNarrow: isNarrow,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              validator: _requiredText,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم المنتج',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                            FutureBuilder<List<AdminCategory>>(
                              future: _categoriesFuture,
                              builder: (context, snapshot) {
                                final categories = snapshot.data ?? <AdminCategory>[];

                                return DropdownButtonFormField<int?>(
                                  value: _categoryId,
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('بدون قسم'),
                                    ),
                                    ...categories.map(
                                      (category) => DropdownMenuItem<int?>(
                                        value: category.id,
                                        child: Text(category.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: _isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _categoryId = value;
                                          });
                                        },
                                  decoration: const InputDecoration(
                                    labelText: 'القسم',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                );
                              },
                            ),
                            TextFormField(
                              controller: _skuController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'SKU / كود المنتج',
                                prefixIcon: Icon(Icons.qr_code_2),
                              ),
                            ),
                            TextFormField(
                              controller: _shortDescriptionController,
                              textInputAction: TextInputAction.next,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'وصف مختصر',
                                prefixIcon: Icon(Icons.short_text),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogSection(
                        title: 'السعر والمخزون',
                        child: _ResponsiveFields(
                          isNarrow: isNarrow,
                          children: [
                            TextFormField(
                              controller: _priceController,
                              validator: _requiredNumber,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'السعر الأساسي',
                                prefixIcon: Icon(Icons.payments_outlined),
                                suffixText: 'د.ع',
                              ),
                            ),
                            TextFormField(
                              controller: _salePriceController,
                              validator: _optionalNumber,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'سعر التخفيض',
                                prefixIcon: Icon(Icons.local_offer_outlined),
                                suffixText: 'د.ع',
                              ),
                            ),
                            if (!_hasVariants)
                              TextFormField(
                                controller: _quantityController,
                                validator: _requiredInteger,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية بالمخزن الرئيسي',
                                  prefixIcon: Icon(Icons.warehouse_outlined),
                                ),
                              ),
                            SwitchListTile(
                              value: _isFeatured,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _isFeatured = value;
                                      });
                                    },
                              title: const Text(
                                'منتج مميز',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text('يظهر بأولوية في واجهة الزبون'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogSection(
                        title: 'خيارات المنتج',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isEditMode && _hasVariants) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Text(
                                  'هذا المنتج يحتوي خيارات. تعديل تفاصيل الخيارات والكميات لكل خيار نكمله بالمرحلة التالية.',
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            SwitchListTile(
                              value: _hasVariants,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _hasVariants = value;
                                        if (_hasVariants && _variants.isEmpty) {
                                          _variants.add(_VariantDraft());
                                        }
                                      });
                                    },
                              title: const Text(
                                'هذا المنتج يحتوي خيارات',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              subtitle: const Text('مثل 42 / 43 أو M / L أو Black / 128GB'),
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (_hasVariants) ...[
                              const SizedBox(height: 10),
                              for (int index = 0; index < _variants.length; index++) ...[
                                _VariantEditor(
                                  index: index,
                                  variant: _variants[index],
                                  onRemove: _variants.length == 1 ? null : () => _removeVariant(index),
                                  requiredText: _requiredText,
                                  optionalNumber: _optionalNumber,
                                  requiredInteger: _requiredInteger,
                                ),
                                const SizedBox(height: 10),
                              ],
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _addVariant,
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة خيار'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogSection(
                        title: 'صورة المنتج',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_localPreviewUrl != null || _imageUrlController.text.trim().isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  height: 180,
                                  color: const Color(0xFFF1F5F9),
                                  child: Image.network(
                                    _localPreviewUrl ?? _imageUrlController.text.trim(),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      return const Center(
                                        child: Text('تعذر عرض الصورة'),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            OutlinedButton.icon(
                              onPressed: _isSaving || _isUploadingImage ? null : _pickAndUploadImage,
                              icon: _isUploadingImage
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file_outlined),
                              label: Text(
                                _isUploadingImage
                                    ? 'جاري رفع الصورة...'
                                    : (_selectedImageName == null ? 'اختيار صورة من الجهاز' : 'تغيير الصورة'),
                              ),
                            ),
                            if (_selectedImageName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _selectedImageName!,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _imageUrlController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'رابط الصورة بعد الرفع',
                                prefixIcon: Icon(Icons.link),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'جاري الحفظ...' : (_isEditMode ? 'حفظ التعديل' : 'حفظ المنتج')),
          ),
        ],
      ),
    );
  }
}

class _VariantEditor extends StatelessWidget {
  const _VariantEditor({
    required this.index,
    required this.variant,
    required this.onRemove,
    required this.requiredText,
    required this.optionalNumber,
    required this.requiredInteger,
  });

  final int index;
  final _VariantDraft variant;
  final VoidCallback? onRemove;
  final String? Function(String?) requiredText;
  final String? Function(String?) optionalNumber;
  final String? Function(String?) requiredInteger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'الخيار ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFDC2626),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: variant.name,
                  validator: requiredText,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخيار',
                    hintText: '42 أو M أو Black',
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: TextFormField(
                  controller: variant.sku,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: variant.price,
                  validator: optionalNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    suffixText: 'د.ع',
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: variant.salePrice,
                  validator: optionalNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر التخفيض',
                    suffixText: 'د.ع',
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: variant.quantity,
                  validator: requiredInteger,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({
    required this.isNarrow,
    required this.children,
  });

  final bool isNarrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return Column(
        children: [
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width: 360,
              child: child,
            ),
          )
          .toList(),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        width: 620,
        decoration: cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 44),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل المنتجات',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyProducts extends StatelessWidget {
  const EmptyProducts({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا توجد منتجات مطابقة',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}


class AdminBrandingSettings {
  const AdminBrandingSettings({
    required this.appName,
    required this.businessName,
    required this.logoUrl,
    required this.darkLogoUrl,
    required this.appIconUrl,
    required this.splashImageUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonColor,
    required this.fontFamily,
    required this.defaultLocale,
    required this.supportedLocales,
    required this.textDirection,
    required this.currencyCode,
    required this.currencySymbol,
    required this.deliveryEnabled,
    required this.deliveryFeeType,
    required this.deliveryFixedFee,
    required this.freeDeliveryMinOrder,
    required this.supportPhone,
    required this.whatsappNumber,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
    required this.websiteUrl,
    required this.privacyPolicyUrl,
    required this.termsUrl,
  });

  final String appName;
  final String businessName;
  final String? logoUrl;
  final String? darkLogoUrl;
  final String? appIconUrl;
  final String? splashImageUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final String? backgroundColor;
  final String? textColor;
  final String? buttonColor;
  final String? fontFamily;
  final String? defaultLocale;
  final List<String> supportedLocales;
  final String? textDirection;
  final String? currencyCode;
  final String? currencySymbol;
  final bool deliveryEnabled;
  final String? deliveryFeeType;
  final double? deliveryFixedFee;
  final double? freeDeliveryMinOrder;
  final String? supportPhone;
  final String? whatsappNumber;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? websiteUrl;
  final String? privacyPolicyUrl;
  final String? termsUrl;

  factory AdminBrandingSettings.fromJson(Map<String, dynamic> json) {
    final localesJson = json['supported_locales'] as List<dynamic>? ?? const ['ar', 'en'];

    return AdminBrandingSettings(
      appName: json['app_name']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      darkLogoUrl: json['dark_logo_url']?.toString(),
      appIconUrl: json['app_icon_url']?.toString(),
      splashImageUrl: json['splash_image_url']?.toString(),
      primaryColor: json['primary_color']?.toString(),
      secondaryColor: json['secondary_color']?.toString(),
      accentColor: json['accent_color']?.toString(),
      backgroundColor: json['background_color']?.toString(),
      textColor: json['text_color']?.toString(),
      buttonColor: json['button_color']?.toString(),
      fontFamily: json['font_family']?.toString(),
      defaultLocale: json['default_locale']?.toString(),
      supportedLocales: localesJson.map((item) => item.toString()).toList(),
      textDirection: json['text_direction']?.toString(),
      currencyCode: json['currency_code']?.toString(),
      currencySymbol: json['currency_symbol']?.toString(),
      deliveryEnabled: json['delivery_enabled'] == true,
      deliveryFeeType: json['delivery_fee_type']?.toString(),
      deliveryFixedFee: json['delivery_fixed_fee'] == null
          ? null
          : double.tryParse(json['delivery_fixed_fee'].toString()),
      freeDeliveryMinOrder: json['free_delivery_min_order'] == null
          ? null
          : double.tryParse(json['free_delivery_min_order'].toString()),
      supportPhone: json['support_phone']?.toString(),
      whatsappNumber: json['whatsapp_number']?.toString(),
      facebookUrl: json['facebook_url']?.toString(),
      instagramUrl: json['instagram_url']?.toString(),
      tiktokUrl: json['tiktok_url']?.toString(),
      websiteUrl: json['website_url']?.toString(),
      privacyPolicyUrl: json['privacy_policy_url']?.toString(),
      termsUrl: json['terms_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'business_name': businessName,
      'logo_url': logoUrl,
      'dark_logo_url': darkLogoUrl,
      'app_icon_url': appIconUrl,
      'splash_image_url': splashImageUrl,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'accent_color': accentColor,
      'background_color': backgroundColor,
      'text_color': textColor,
      'button_color': buttonColor,
      'font_family': fontFamily,
      'default_locale': defaultLocale,
      'supported_locales': supportedLocales,
      'text_direction': textDirection,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'delivery_enabled': deliveryEnabled,
      'delivery_fee_type': deliveryFeeType,
      'delivery_fixed_fee': deliveryFixedFee,
      'free_delivery_min_order': freeDeliveryMinOrder,
      'support_phone': supportPhone,
      'whatsapp_number': whatsappNumber,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'tiktok_url': tiktokUrl,
      'website_url': websiteUrl,
      'privacy_policy_url': privacyPolicyUrl,
      'terms_url': termsUrl,
    };
  }
}

class BrandingSettingsPage extends StatefulWidget {
  const BrandingSettingsPage({super.key});

  @override
  State<BrandingSettingsPage> createState() => _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends State<BrandingSettingsPage> {
  final AdminApi _api = AdminApi();

  late Future<AdminBrandingSettings> _future;

  final _appNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _darkLogoUrlController = TextEditingController();
  final _appIconUrlController = TextEditingController();
  final _splashImageUrlController = TextEditingController();

  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _accentColorController = TextEditingController();
  final _backgroundColorController = TextEditingController();
  final _textColorController = TextEditingController();
  final _buttonColorController = TextEditingController();
  final _fontFamilyController = TextEditingController();

  final _supportPhoneController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _facebookUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  final _tiktokUrlController = TextEditingController();
  final _websiteUrlController = TextEditingController();

  final _privacyPolicyUrlController = TextEditingController();
  final _termsUrlController = TextEditingController();

  final _currencyCodeController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  final _deliveryFixedFeeController = TextEditingController();
  final _freeDeliveryMinOrderController = TextEditingController();

  bool _deliveryEnabled = true;
  String _deliveryFeeType = 'fixed';
  String _textDirection = 'rtl';
  bool _loadedIntoForm = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchTenantBranding();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _businessNameController.dispose();
    _logoUrlController.dispose();
    _darkLogoUrlController.dispose();
    _appIconUrlController.dispose();
    _splashImageUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    _backgroundColorController.dispose();
    _textColorController.dispose();
    _buttonColorController.dispose();
    _fontFamilyController.dispose();
    _supportPhoneController.dispose();
    _whatsappNumberController.dispose();
    _facebookUrlController.dispose();
    _instagramUrlController.dispose();
    _tiktokUrlController.dispose();
    _websiteUrlController.dispose();
    _privacyPolicyUrlController.dispose();
    _termsUrlController.dispose();
    _currencyCodeController.dispose();
    _currencySymbolController.dispose();
    _deliveryFixedFeeController.dispose();
    _freeDeliveryMinOrderController.dispose();
    super.dispose();
  }

  void _loadIntoForm(AdminBrandingSettings settings) {
    if (_loadedIntoForm) {
      return;
    }

    _appNameController.text = settings.appName;
    _businessNameController.text = settings.businessName;
    _logoUrlController.text = settings.logoUrl ?? '';
    _darkLogoUrlController.text = settings.darkLogoUrl ?? '';
    _appIconUrlController.text = settings.appIconUrl ?? '';
    _splashImageUrlController.text = settings.splashImageUrl ?? '';

    _primaryColorController.text = settings.primaryColor ?? '#0B6E4F';
    _secondaryColorController.text = settings.secondaryColor ?? '#50C878';
    _accentColorController.text = settings.accentColor ?? '#D1F2EB';
    _backgroundColorController.text = settings.backgroundColor ?? '#FFFFFF';
    _textColorController.text = settings.textColor ?? '#013220';
    _buttonColorController.text = settings.buttonColor ?? '#0B6E4F';
    _fontFamilyController.text = settings.fontFamily ?? '';

    _supportPhoneController.text = settings.supportPhone ?? '';
    _whatsappNumberController.text = settings.whatsappNumber ?? '';
    _facebookUrlController.text = settings.facebookUrl ?? '';
    _instagramUrlController.text = settings.instagramUrl ?? '';
    _tiktokUrlController.text = settings.tiktokUrl ?? '';
    _websiteUrlController.text = settings.websiteUrl ?? '';

    _privacyPolicyUrlController.text = settings.privacyPolicyUrl ?? '';
    _termsUrlController.text = settings.termsUrl ?? '';

    _currencyCodeController.text = settings.currencyCode ?? 'IQD';
    _currencySymbolController.text = settings.currencySymbol ?? 'د.ع';
    _deliveryFixedFeeController.text = settings.deliveryFixedFee?.toStringAsFixed(0) ?? '0';
    _freeDeliveryMinOrderController.text = settings.freeDeliveryMinOrder?.toStringAsFixed(0) ?? '';

    _deliveryEnabled = settings.deliveryEnabled;
    _deliveryFeeType = settings.deliveryFeeType ?? 'fixed';
    _textDirection = settings.textDirection ?? 'rtl';

    _loadedIntoForm = true;
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _nullableDouble(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value);
  }

  Future<void> _save() async {
    if (_appNameController.text.trim().isEmpty || _businessNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم التطبيق واسم النشاط مطلوبان')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _api.updateTenantBranding(
        AdminBrandingSettings(
          appName: _appNameController.text.trim(),
          businessName: _businessNameController.text.trim(),
          logoUrl: _nullableText(_logoUrlController),
          darkLogoUrl: _nullableText(_darkLogoUrlController),
          appIconUrl: _nullableText(_appIconUrlController),
          splashImageUrl: _nullableText(_splashImageUrlController),
          primaryColor: _nullableText(_primaryColorController),
          secondaryColor: _nullableText(_secondaryColorController),
          accentColor: _nullableText(_accentColorController),
          backgroundColor: _nullableText(_backgroundColorController),
          textColor: _nullableText(_textColorController),
          buttonColor: _nullableText(_buttonColorController),
          fontFamily: _nullableText(_fontFamilyController),
          defaultLocale: 'ar',
          supportedLocales: const ['ar', 'en'],
          textDirection: _textDirection,
          currencyCode: _nullableText(_currencyCodeController) ?? 'IQD',
          currencySymbol: _nullableText(_currencySymbolController) ?? 'د.ع',
          deliveryEnabled: _deliveryEnabled,
          deliveryFeeType: _deliveryFeeType,
          deliveryFixedFee: _nullableDouble(_deliveryFixedFeeController) ?? 0,
          freeDeliveryMinOrder: _nullableDouble(_freeDeliveryMinOrderController),
          supportPhone: _nullableText(_supportPhoneController),
          whatsappNumber: _nullableText(_whatsappNumberController),
          facebookUrl: _nullableText(_facebookUrlController),
          instagramUrl: _nullableText(_instagramUrlController),
          tiktokUrl: _nullableText(_tiktokUrlController),
          websiteUrl: _nullableText(_websiteUrlController),
          privacyPolicyUrl: _nullableText(_privacyPolicyUrlController),
          termsUrl: _nullableText(_termsUrlController),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadedIntoForm = false;
        _future = Future.value(saved);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الهوية بنجاح')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ الإعدادات: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _reload() {
    setState(() {
      _loadedIntoForm = false;
      _future = _api.fetchTenantBranding();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          if (isMobile) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                title: const Text(
                  'إعدادات الهوية',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              drawer: const Drawer(
                child: AdminSidebar(
                  isDrawer: true,
                  selectedSection: 'branding',
                ),
              ),
              body: _BrandingSettingsBody(
                future: _future,
                isMobile: true,
                loadIntoForm: _loadIntoForm,
                onReload: _reload,
                onSave: _save,
                isSaving: _isSaving,
                appNameController: _appNameController,
                businessNameController: _businessNameController,
                logoUrlController: _logoUrlController,
                darkLogoUrlController: _darkLogoUrlController,
                appIconUrlController: _appIconUrlController,
                splashImageUrlController: _splashImageUrlController,
                primaryColorController: _primaryColorController,
                secondaryColorController: _secondaryColorController,
                accentColorController: _accentColorController,
                backgroundColorController: _backgroundColorController,
                textColorController: _textColorController,
                buttonColorController: _buttonColorController,
                fontFamilyController: _fontFamilyController,
                supportPhoneController: _supportPhoneController,
                whatsappNumberController: _whatsappNumberController,
                facebookUrlController: _facebookUrlController,
                instagramUrlController: _instagramUrlController,
                tiktokUrlController: _tiktokUrlController,
                websiteUrlController: _websiteUrlController,
                privacyPolicyUrlController: _privacyPolicyUrlController,
                termsUrlController: _termsUrlController,
                currencyCodeController: _currencyCodeController,
                currencySymbolController: _currencySymbolController,
                deliveryFixedFeeController: _deliveryFixedFeeController,
                freeDeliveryMinOrderController: _freeDeliveryMinOrderController,
                deliveryEnabled: _deliveryEnabled,
                deliveryFeeType: _deliveryFeeType,
                textDirectionValue: _textDirection,
                onDeliveryEnabledChanged: (value) {
                  setState(() => _deliveryEnabled = value);
                },
                onDeliveryFeeTypeChanged: (value) {
                  if (value != null) {
                    setState(() => _deliveryFeeType = value);
                  }
                },
                onTextDirectionChanged: (value) {
                  if (value != null) {
                    setState(() => _textDirection = value);
                  }
                },
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                const AdminSidebar(selectedSection: 'branding'),
                Expanded(
                  child: _BrandingSettingsBody(
                    future: _future,
                    isMobile: false,
                    loadIntoForm: _loadIntoForm,
                    onReload: _reload,
                    onSave: _save,
                    isSaving: _isSaving,
                    appNameController: _appNameController,
                    businessNameController: _businessNameController,
                    logoUrlController: _logoUrlController,
                    darkLogoUrlController: _darkLogoUrlController,
                    appIconUrlController: _appIconUrlController,
                    splashImageUrlController: _splashImageUrlController,
                    primaryColorController: _primaryColorController,
                    secondaryColorController: _secondaryColorController,
                    accentColorController: _accentColorController,
                    backgroundColorController: _backgroundColorController,
                    textColorController: _textColorController,
                    buttonColorController: _buttonColorController,
                    fontFamilyController: _fontFamilyController,
                    supportPhoneController: _supportPhoneController,
                    whatsappNumberController: _whatsappNumberController,
                    facebookUrlController: _facebookUrlController,
                    instagramUrlController: _instagramUrlController,
                    tiktokUrlController: _tiktokUrlController,
                    websiteUrlController: _websiteUrlController,
                    privacyPolicyUrlController: _privacyPolicyUrlController,
                    termsUrlController: _termsUrlController,
                    currencyCodeController: _currencyCodeController,
                    currencySymbolController: _currencySymbolController,
                    deliveryFixedFeeController: _deliveryFixedFeeController,
                    freeDeliveryMinOrderController: _freeDeliveryMinOrderController,
                    deliveryEnabled: _deliveryEnabled,
                    deliveryFeeType: _deliveryFeeType,
                    textDirectionValue: _textDirection,
                    onDeliveryEnabledChanged: (value) {
                      setState(() => _deliveryEnabled = value);
                    },
                    onDeliveryFeeTypeChanged: (value) {
                      if (value != null) {
                        setState(() => _deliveryFeeType = value);
                      }
                    },
                    onTextDirectionChanged: (value) {
                      if (value != null) {
                        setState(() => _textDirection = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrandingSettingsBody extends StatelessWidget {
  const _BrandingSettingsBody({
    required this.future,
    required this.isMobile,
    required this.loadIntoForm,
    required this.onReload,
    required this.onSave,
    required this.isSaving,
    required this.appNameController,
    required this.businessNameController,
    required this.logoUrlController,
    required this.darkLogoUrlController,
    required this.appIconUrlController,
    required this.splashImageUrlController,
    required this.primaryColorController,
    required this.secondaryColorController,
    required this.accentColorController,
    required this.backgroundColorController,
    required this.textColorController,
    required this.buttonColorController,
    required this.fontFamilyController,
    required this.supportPhoneController,
    required this.whatsappNumberController,
    required this.facebookUrlController,
    required this.instagramUrlController,
    required this.tiktokUrlController,
    required this.websiteUrlController,
    required this.privacyPolicyUrlController,
    required this.termsUrlController,
    required this.currencyCodeController,
    required this.currencySymbolController,
    required this.deliveryFixedFeeController,
    required this.freeDeliveryMinOrderController,
    required this.deliveryEnabled,
    required this.deliveryFeeType,
    required this.textDirectionValue,
    required this.onDeliveryEnabledChanged,
    required this.onDeliveryFeeTypeChanged,
    required this.onTextDirectionChanged,
  });

  final Future<AdminBrandingSettings> future;
  final bool isMobile;
  final ValueChanged<AdminBrandingSettings> loadIntoForm;
  final VoidCallback onReload;
  final VoidCallback onSave;
  final bool isSaving;

  final TextEditingController appNameController;
  final TextEditingController businessNameController;
  final TextEditingController logoUrlController;
  final TextEditingController darkLogoUrlController;
  final TextEditingController appIconUrlController;
  final TextEditingController splashImageUrlController;
  final TextEditingController primaryColorController;
  final TextEditingController secondaryColorController;
  final TextEditingController accentColorController;
  final TextEditingController backgroundColorController;
  final TextEditingController textColorController;
  final TextEditingController buttonColorController;
  final TextEditingController fontFamilyController;
  final TextEditingController supportPhoneController;
  final TextEditingController whatsappNumberController;
  final TextEditingController facebookUrlController;
  final TextEditingController instagramUrlController;
  final TextEditingController tiktokUrlController;
  final TextEditingController websiteUrlController;
  final TextEditingController privacyPolicyUrlController;
  final TextEditingController termsUrlController;
  final TextEditingController currencyCodeController;
  final TextEditingController currencySymbolController;
  final TextEditingController deliveryFixedFeeController;
  final TextEditingController freeDeliveryMinOrderController;

  final bool deliveryEnabled;
  final String deliveryFeeType;
  final String textDirectionValue;
  final ValueChanged<bool> onDeliveryEnabledChanged;
  final ValueChanged<String?> onDeliveryFeeTypeChanged;
  final ValueChanged<String?> onTextDirectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: FutureBuilder<AdminBrandingSettings>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'فشل تحميل إعدادات الهوية: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            );
          }

          final settings = snapshot.data;
          if (settings != null) {
            loadIntoForm(settings);
          }

          return ListView(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            children: [
              _BrandingHeader(
                isMobile: isMobile,
                onReload: onReload,
                onSave: onSave,
                isSaving: isSaving,
              ),
              const SizedBox(height: 18),
              _SettingsSection(
                title: 'معلومات المتجر',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(
                        controller: appNameController,
                        label: 'اسم التطبيق',
                        icon: Icons.apps_outlined,
                      ),
                      _SettingTextField(
                        controller: businessNameController,
                        label: 'اسم النشاط',
                        icon: Icons.storefront_outlined,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'الشعارات والصور',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(controller: logoUrlController, label: 'رابط الشعار', icon: Icons.image_outlined),
                      _SettingTextField(controller: darkLogoUrlController, label: 'رابط الشعار الداكن', icon: Icons.dark_mode_outlined),
                      _SettingTextField(controller: appIconUrlController, label: 'رابط أيقونة التطبيق', icon: Icons.apps),
                      _SettingTextField(controller: splashImageUrlController, label: 'رابط صورة البداية', icon: Icons.wallpaper_outlined),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'الألوان والخط',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(controller: primaryColorController, label: 'اللون الرئيسي', icon: Icons.palette_outlined),
                      _SettingTextField(controller: secondaryColorController, label: 'اللون الثانوي', icon: Icons.palette),
                      _SettingTextField(controller: accentColorController, label: 'لون مساعد', icon: Icons.color_lens_outlined),
                      _SettingTextField(controller: backgroundColorController, label: 'لون الخلفية', icon: Icons.format_color_fill_outlined),
                      _SettingTextField(controller: textColorController, label: 'لون النص', icon: Icons.text_fields),
                      _SettingTextField(controller: buttonColorController, label: 'لون الأزرار', icon: Icons.smart_button_outlined),
                      _SettingTextField(controller: fontFamilyController, label: 'اسم الخط', icon: Icons.font_download_outlined),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'اللغة والعملة',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(controller: currencyCodeController, label: 'رمز العملة', icon: Icons.payments_outlined),
                      _SettingTextField(controller: currencySymbolController, label: 'علامة العملة', icon: Icons.attach_money),
                      DropdownButtonFormField<String>(
                        value: textDirectionValue,
                        items: const [
                          DropdownMenuItem(value: 'rtl', child: Text('RTL - عربي')),
                          DropdownMenuItem(value: 'ltr', child: Text('LTR - إنكليزي')),
                        ],
                        onChanged: onTextDirectionChanged,
                        decoration: _inputDecoration('اتجاه النص', Icons.format_textdirection_r_to_l),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'التواصل والسوشيال',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(controller: supportPhoneController, label: 'رقم الدعم', icon: Icons.phone_outlined),
                      _SettingTextField(controller: whatsappNumberController, label: 'رقم واتساب', icon: Icons.chat_outlined),
                      _SettingTextField(controller: facebookUrlController, label: 'Facebook URL', icon: Icons.facebook_outlined),
                      _SettingTextField(controller: instagramUrlController, label: 'Instagram URL', icon: Icons.camera_alt_outlined),
                      _SettingTextField(controller: tiktokUrlController, label: 'TikTok URL', icon: Icons.video_library_outlined),
                      _SettingTextField(controller: websiteUrlController, label: 'Website URL', icon: Icons.language_outlined),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'التوصيل',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: deliveryEnabled,
                    onChanged: onDeliveryEnabledChanged,
                    title: const Text(
                      'تفعيل التوصيل',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      DropdownButtonFormField<String>(
                        value: deliveryFeeType,
                        items: const [
                          DropdownMenuItem(value: 'fixed', child: Text('أجور ثابتة')),
                          DropdownMenuItem(value: 'free', child: Text('توصيل مجاني')),
                        ],
                        onChanged: onDeliveryFeeTypeChanged,
                        decoration: _inputDecoration('نوع أجور التوصيل', Icons.local_shipping_outlined),
                      ),
                      _SettingTextField(
                        controller: deliveryFixedFeeController,
                        label: 'أجور التوصيل الثابتة',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      _SettingTextField(
                        controller: freeDeliveryMinOrderController,
                        label: 'الحد الأدنى للتوصيل المجاني',
                        icon: Icons.price_check_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'الروابط القانونية',
                children: [
                  _ResponsiveFields(
                    isNarrow: isMobile,
                    children: [
                      _SettingTextField(controller: privacyPolicyUrlController, label: 'Privacy Policy URL', icon: Icons.privacy_tip_outlined),
                      _SettingTextField(controller: termsUrlController, label: 'Terms URL', icon: Icons.gavel_outlined),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandingHeader extends StatelessWidget {
  const _BrandingHeader({
    required this.isMobile,
    required this.onReload,
    required this.onSave,
    required this.isSaving,
  });

  final bool isMobile;
  final VoidCallback onReload;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final actions = [
      OutlinedButton.icon(
        onPressed: onReload,
        icon: const Icon(Icons.refresh),
        label: const Text('تحديث'),
      ),
      FilledButton.icon(
        onPressed: isSaving ? null : onSave,
        icon: const Icon(Icons.save_outlined),
        label: const Text('حفظ'),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandingHeaderText(),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            )
          : Row(
              children: [
                const Expanded(child: _BrandingHeaderText()),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ),
    );
  }
}

class _BrandingHeaderText extends StatelessWidget {
  const _BrandingHeaderText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إعدادات الهوية',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'تحكم باسم المتجر، الألوان، الشعارات، التواصل، والتوصيل لكل Tenant بدون تثبيت أي قيمة داخل الكود.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SettingTextField extends StatelessWidget {
  const _SettingTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon),
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
  );
}

class AdminPlan {
  const AdminPlan({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.monthlyPrice,
    required this.setupPrice,
    required this.maxBranches,
    required this.maxWarehouses,
    required this.maxUsers,
    required this.maxProducts,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final String? description;
  final double monthlyPrice;
  final double setupPrice;
  final int? maxBranches;
  final int? maxWarehouses;
  final int? maxUsers;
  final int? maxProducts;
  final bool isActive;

  factory AdminPlan.fromJson(Map<String, dynamic> json) {
    return AdminPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
      setupPrice: (json['setup_price'] as num?)?.toDouble() ?? 0,
      maxBranches: (json['max_branches'] as num?)?.toInt(),
      maxWarehouses: (json['max_warehouses'] as num?)?.toInt(),
      maxUsers: (json['max_users'] as num?)?.toInt(),
      maxProducts: (json['max_products'] as num?)?.toInt(),
      isActive: json['is_active'] == true,
    );
  }
}

class AdminFeatureFlag {
  const AdminFeatureFlag({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
    required this.isEnabled,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final bool isEnabled;

  factory AdminFeatureFlag.fromJson(Map<String, dynamic> json) {
    return AdminFeatureFlag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == true,
      isEnabled: json['is_enabled'] == true,
    );
  }

  AdminFeatureFlag copyWith({
    bool? isEnabled,
  }) {
    return AdminFeatureFlag(
      id: id,
      code: code,
      name: name,
      description: description,
      isActive: isActive,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class CommercialSettingsPage extends StatefulWidget {
  const CommercialSettingsPage({super.key});

  @override
  State<CommercialSettingsPage> createState() => _CommercialSettingsPageState();
}

class _CommercialSettingsPageState extends State<CommercialSettingsPage> {
  final AdminApi _api = AdminApi();

  late Future<_CommercialSettingsData> _future;
  List<AdminFeatureFlag> _features = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CommercialSettingsData> _load() async {
    final plans = await _api.fetchPlans();
    final features = await _api.fetchFeatureFlags();
    _features = features;

    return _CommercialSettingsData(
      plans: plans,
      features: features,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      final payload = {
        for (final feature in _features) feature.code: feature.isEnabled,
      };

      final updated = await _api.updateFeatureFlags(payload);

      if (!mounted) {
        return;
      }

      setState(() {
        _features = updated;
        _future = Future.value(
          _CommercialSettingsData(
            plans: [],
            features: updated,
          ),
        );
      });

      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الميزات بنجاح')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _toggleFeature(AdminFeatureFlag feature, bool value) {
    setState(() {
      _features = _features
          .map(
            (item) => item.code == feature.code
                ? item.copyWith(isEnabled: value)
                : item,
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    final content = Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: isMobile
          ? const Drawer(
              child: AdminSidebar(
                isDrawer: true,
                selectedSection: 'commercial',
              ),
            )
          : null,
      appBar: isMobile
          ? AppBar(
              title: const Text('الباقات والميزات'),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            const AdminSidebar(
              selectedSection: 'commercial',
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<_CommercialSettingsData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _features.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _CommercialHeader(isMobile: isMobile),
                        const SizedBox(height: 20),
                        _CommercialErrorCard(
                          error: snapshot.error.toString(),
                          onRetry: _refresh,
                        ),
                      ],
                    );
                  }

                  final data = snapshot.data;
                  final plans = data?.plans ?? [];

                  return ListView(
                    padding: EdgeInsets.all(isMobile ? 16 : 28),
                    children: [
                      _CommercialHeader(isMobile: isMobile),
                      const SizedBox(height: 22),
                      _PlansSection(plans: plans),
                      const SizedBox(height: 22),
                      _FeatureFlagsSection(
                        features: _features,
                        saving: _saving,
                        onChanged: _toggleFeature,
                        onSave: _save,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );
  }
}

class _CommercialSettingsData {
  const _CommercialSettingsData({
    required this.plans,
    required this.features,
  });

  final List<AdminPlan> plans;
  final List<AdminFeatureFlag> features;
}

class _CommercialHeader extends StatelessWidget {
  const _CommercialHeader({
    required this.isMobile,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الباقات والميزات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'إعدادات داخلية لصاحب المنصة فقط: تحديد الباقات وتفعيل الميزات لكل Tenant.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.plans,
  });

  final List<AdminPlan> plans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الباقات المتوفرة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            const Text(
              'لا توجد باقات حالياً.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: plans.map((plan) => _PlanCard(plan: plan)).toList(),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
  });

  final AdminPlan plan;

  String _limitText(int? value) {
    return value == null ? 'غير محدود' : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Chip(
                label: Text(plan.isActive ? 'فعالة' : 'مطفية'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description ?? 'بدون وصف',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${plan.monthlyPrice.toStringAsFixed(0)} د.ع / شهرياً',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إعداد: ${plan.setupPrice.toStringAsFixed(0)} د.ع',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(height: 24),
          _PlanLimitRow(label: 'الفروع', value: _limitText(plan.maxBranches)),
          _PlanLimitRow(label: 'المخازن', value: _limitText(plan.maxWarehouses)),
          _PlanLimitRow(label: 'المستخدمين', value: _limitText(plan.maxUsers)),
          _PlanLimitRow(label: 'المنتجات', value: _limitText(plan.maxProducts)),
        ],
      ),
    );
  }
}

class _PlanLimitRow extends StatelessWidget {
  const _PlanLimitRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureFlagsSection extends StatelessWidget {
  const _FeatureFlagsSection({
    required this.features,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final List<AdminFeatureFlag> features;
  final bool saving;
  final void Function(AdminFeatureFlag feature, bool value) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ميزات الـ Tenant الحالي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'جاري الحفظ...' : 'حفظ الميزات'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (features.isEmpty)
            const Text(
              'لا توجد ميزات حالياً.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: features
                  .map(
                    (feature) => _FeatureFlagTile(
                      feature: feature,
                      onChanged: (value) => onChanged(feature, value),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _FeatureFlagTile extends StatelessWidget {
  const _FeatureFlagTile({
    required this.feature,
    required this.onChanged,
  });

  final AdminFeatureFlag feature;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: feature.isEnabled ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: feature.isEnabled ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            feature.isEnabled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: feature.isEnabled ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description ?? feature.code,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: feature.isEnabled,
            onChanged: feature.isActive ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _CommercialErrorCard extends StatelessWidget {
  const _CommercialErrorCard({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حدث خطأ أثناء تحميل إعدادات الباقات والميزات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

















