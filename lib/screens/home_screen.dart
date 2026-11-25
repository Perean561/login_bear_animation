import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // - Chrome (Web) o Celular físico Android con "adb reverse tcp:8081 tcp:8081": 'http://localhost:8081'
  // - Emulador Android estándar: 'http://10.0.2.2:8081'
  static const String baseUrl = 'http://localhost:8081';

  late Future<List<dynamic>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
  }

  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return jsonDecode(decodedBody) as List<dynamic>;
    } else {
      throw Exception('Error del servidor (HTTP ${response.statusCode})');
    }
  }

  Future<void> _logout() async {
    // AuthGate detecta el cierre de sesión y regresa automáticamente a LoginScreen
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar productos',
            onPressed: () {
              setState(() {
                _productsFuture = fetchProducts();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (userEmail.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.deepPurple.withValues(alpha: 0.08),
              child: Text(
                'Sesión activa: $userEmail',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 54,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudieron obtener los productos:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _productsFuture = fetchProducts();
                              });
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Text('No hay productos registrados.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index] as Map<String, dynamic>;
                    final category =
                        product['category'] as Map<String, dynamic>?;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Text(
                            '${product['productId']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        title: Text(
                          product['name']?.toString() ?? 'Sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Categoría: ${category?['category'] ?? 'General'} • Stock: ${product['stock']}',
                        ),
                        trailing: Text(
                          '\$${product['price']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}