import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
                onPressed: () => _soon('إضافة منتج'),
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              ),
              body: DashboardBody(
                future: _future,
                searchController: _searchController,
                search: _search,
                onReload: _reload,
                onAdd: () => _soon('إضافة منتج'),
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
                    onAdd: () => _soon('إضافة منتج'),
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
