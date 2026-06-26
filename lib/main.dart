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
      home: const ProductsDashboardPage(),
    );
  }
}

class AdminApi {
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String baseUrl = _configuredBaseUrl.trim().isNotEmpty
      ? _configuredBaseUrl.trim()
      : 'http://192.168.100.8:8099/api';

  final String tenantCode = 'demo';

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
    required this.name,
    required this.sku,
    required this.price,
    required this.salePrice,
    required this.quantity,
  });

  final String name;
  final String? sku;
  final double? price;
  final double? salePrice;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
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
    required this.categoryName,
    required this.mainImageUrl,
    required this.variantsCount,
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
  final String? categoryName;
  final String? mainImageUrl;
  final int variantsCount;

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final variants = json['variants'] as List<dynamic>? ?? [];

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
      hasVariants: json['has_variants'] == true,
      isFeatured: json['is_featured'] == true,
      categoryName: category?['name']?.toString(),
      mainImageUrl: json['main_image_url']?.toString(),
      variantsCount: variants.length,
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

  void _soon(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text راح نكملها بالخطوة الجاية')),
    );
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
                onEdit: (product) => _soon('تعديل المنتج رقم ${product.id}'),
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
                    onEdit: (product) => _soon('تعديل المنتج رقم ${product.id}'),
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
  const AdminSidebar({super.key, this.isDrawer = false});

  final bool isDrawer;

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
              const SidebarItem(Icons.inventory_2_outlined, 'المنتجات', true),
              const SidebarItem(Icons.receipt_long_outlined, 'الطلبات', false),
              const SidebarItem(Icons.category_outlined, 'الأقسام', false),
              const SidebarItem(Icons.storefront_outlined, 'المخازن والفروع', false),
              const SidebarItem(Icons.local_offer_outlined, 'الخصومات', false),
              const SidebarItem(Icons.settings_outlined, 'إعدادات الهوية', false),
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
  const SidebarItem(this.icon, this.label, this.selected, {super.key});

  final IconData icon;
  final String label;
  final bool selected;

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

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({
    super.key,
    required this.api,
  });

  final AdminApi api;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _VariantDraft {
  _VariantDraft();

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

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.api.fetchCategories();
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
            name: variant.name.text.trim(),
            sku: _cleanText(variant.sku.text),
            price: _parseOptionalDouble(variant.price.text),
            salePrice: _parseOptionalDouble(variant.salePrice.text),
            quantity: int.parse(variant.quantity.text.trim()),
          );
        }).toList(),
      );

      await widget.api.createProduct(request);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إضافة المنتج: $error')),
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
        insetPadding: const EdgeInsets.all(18),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: const Text(
          'إضافة منتج جديد',
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
            label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ المنتج'),
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











