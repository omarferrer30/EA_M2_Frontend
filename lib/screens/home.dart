import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:proyecto_flutter/api/models/product_model.dart';
import 'package:proyecto_flutter/api/services/product_service.dart';
import 'package:proyecto_flutter/api/services/token_service.dart';
import 'package:proyecto_flutter/screens/product_detail.dart';
import 'package:proyecto_flutter/utils/constants.dart';
import 'package:proyecto_flutter/widget/nav_bar.dart';
import 'package:latlong2/latlong.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Product> productList = [];
  late List<Product> productListbyDistance = [];
  late List<Product> filteredList = [];
  late List<Product> filteredByDistanceList = [];
  late ScrollController _scrollController;
  bool _loading = false;
  TextEditingController _searchController = TextEditingController();
  TextEditingController _searchDistanceController = TextEditingController();
  LatLng _currentLocation = LatLng(41.2731, 1.9865);

  @override
  void initState() {
    super.initState();
    checkAuthAndNavigate();
    _scrollController = ScrollController()..addListener(_scrollListener);
    fetchProducts();
    _getCurrentUserLocation();
  }

  Future<void> checkAuthAndNavigate() async {
    await TokenService.loggedIn();
  }

  Future<void> fetchProducts() async {
    int page = 1;
    List<Product> products = await ProductService.getProducts(page);
    setState(() {
      productList = products;
      filteredList =
          products; 
      filteredByDistanceList =
        products;// Inicializa la lista filtrada con todos los productos
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (!_loading) {
      setState(() {
        _loading = true;
      });

      int nextPage = (filteredByDistanceList.length / 50).ceil() + 1;
      List<Product> nextPageProducts =
          await ProductService.getProducts(nextPage);

      setState(() {
        productList.addAll(nextPageProducts);
        filteredByDistanceList = productList
            .where((product) =>
                product.name
                    ?.toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ??
                false)
            .toList();
        _loading = false;
      });
    }
  }

  void _filterProducts(String searchTerm) {
    setState(() {
      filteredList = productList
          .where((product) =>
              product.name?.toLowerCase().contains(searchTerm.toLowerCase()) ??
              false)
          .toList();
    });
  }
  double calculateDistance(double lat1, double lon1, double? lat2, double? lon2) {
      const R = 6371.0; // Radio de la Tierra en kilómetros
      final dLat = _toRadians(lat2! - lat1);
      final dLon = _toRadians(lon2! - lon1);

      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(_toRadians(lat1)) * cos(_toRadians(lat2!)) * sin(dLon / 2) * sin(dLon / 2);

      final c = 2 * asin(sqrt(a));

      return R * c;
  }

  double _toRadians(double degree) {
  return degree * (pi / 180);
}
   double _calculateDistance(Product product) {
      final productLatitude = product.location?.latitude ?? 0.0;
      final productLongitude = product.location?.longitude ?? 0.0;
      
      return calculateDistance(
        _currentLocation.latitude,
        _currentLocation.longitude,
        productLatitude,
        productLongitude,
      );
  }

  void _filterProductsbyDistance(double maxDistance){
    setState(() {
      filteredByDistanceList = productList
      .where((product) =>
              _calculateDistance(product) <= maxDistance)
          .toList();
    });
  }

  void _handleSearch(String value) {
  // Intenta convertir el String a Double
  final double? distance = double.tryParse(value);

  // Llama a _filterProductsbyDistance con el valor convertido
  if (distance != null) {
    _filterProductsbyDistance(distance);
  }
}

  Future<void> _getCurrentUserLocation() async {
    LatLng location = await _getUserLocation();
    setState(() {
      _currentLocation = location;
    });
  }
    Future<LatLng> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      return LatLng(0.0, 0.0);
    }

    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 0),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(height: 30),
              Container(
                child: SearchBar2(
                  onSearch: _handleSearch,
                  searchDistanceController: _searchDistanceController,
                ),
              ),
            ]),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(height: 20),
              Container(child: TopText()),
              SizedBox(height: 10),
            ]),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                  child: ProductsHorizontal(
                productList: productList,
                userLocation: _currentLocation,
              )),
              SizedBox(height: 10),
            ]),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(child: MidText()),
              SizedBox(height: 5),
            ]),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.9,
              // Adjust the margin values as needed
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < filteredByDistanceList.length) {
                  return ProductsVerticalItem(
                product: filteredByDistanceList[index],
                userLocation: _currentLocation,
              );
                } else {
                  return _loading ? CircularProgressIndicator() : Container();
                }
              },
              childCount: filteredByDistanceList.length + 1,
            ),
          )
        ],
      ),
    );
  }
}
class SearchBar2 extends StatelessWidget {
  final Function(String) onSearch;
  final TextEditingController searchDistanceController;

  const SearchBar2(
      {Key? key, required this.onSearch, required this.searchDistanceController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.only(),
        child: TextField(
          controller: searchDistanceController,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.primary,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            filled: true,
            fillColor: Theme.of(context).colorScheme.onPrimary,
            prefixIcon: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.primary,
            ),
            hintText: "Introduce una distancia en Km, te mostraremos productos en ese radio de proximidad.",
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          onChanged: onSearch,
        ),
      ),
    );
  }
}


class SearchBar extends StatelessWidget {
  final Function(String) onSearch;
  final TextEditingController searchController;

  const SearchBar(
      {Key? key, required this.onSearch, required this.searchController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.only(),
        child: TextField(
          controller: searchController,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.primary,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            filled: true,
            fillColor: Theme.of(context).colorScheme.onPrimary,
            prefixIcon: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.primary,
            ),
            hintText: "Busca en Km0 Market",
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          onChanged: onSearch,
        ),
      ),
    );
  }
}

class ProductsVerticalItem extends StatelessWidget {
  final Product product;
  final LatLng userLocation;

  const ProductsVerticalItem({Key? key, required this.product, required this.userLocation})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(
          ProductDetailScreen(productId: product.id ?? ''),
        );
      },
      child: Container(
        margin: EdgeInsets.only(left: 5, top: 5, right: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                image: DecorationImage(
                  image: product.productImage != null &&
                          product.productImage!.isNotEmpty
                      ? NetworkImage(product.productImage!.first)
                      : AssetImage('assets/images/profile.png')
                          as ImageProvider, // Use the image URL
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  product.name ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18.0,
                  ),
                ),
              ),
            ),
           Positioned(
              bottom: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${product.price} €/Kg',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 18.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 5), // Espacio entre el precio y la distancia
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              left: 20,
              child:Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Distancia: ${_calculateDistance().toStringAsFixed(2)} km',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
            )

          ],
        ),
      ),
    );
  }
  double calculateDistance(double lat1, double lon1, double? lat2, double? lon2) {
  const R = 6371.0; // Radio de la Tierra en kilómetros
  final dLat = _toRadians(lat2! - lat1);
  final dLon = _toRadians(lon2! - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2!)) * sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * asin(sqrt(a));

  return R * c;
}

double _toRadians(double degree) {
  return degree * (pi / 180);
}

   double _calculateDistance() {
    final productlatitude = product.location?.latitude;
    final productlongitude = product.location?.longitude;
    return calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      productlatitude,
      productlongitude
     
    );
  }
}

class MidText extends StatelessWidget {
  const MidText({
    Key? key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
          margin: EdgeInsets.only(top: 10, left: 20),
          width: gWidth,
          height: gHeight / 25,
          child: SizedBox(
            child: Text("Todos los productos",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                  color: Theme.of(context).primaryColor,
                )),
          )),
    );
  }
}

class ProductsHorizontal extends StatelessWidget {
  final List<Product> productList;
  final LatLng userLocation;

  const ProductsHorizontal({
    super.key,
    required this.productList,
    required this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.only(left: 0.25),
            width: 1,
            height: gHeight / 4.5,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: productList.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                 double distance = calculateDistance(
                  userLocation.latitude,
                  userLocation.longitude,
                  productList[index].location?.latitude ?? 0.0,
                  productList[index].location?.longitude ?? 0.0,
                );
                return GestureDetector(
                  onTap: () {
                    Get.to(ProductDetailScreen(
                        productId: productList[index].id ?? ''));
                  },
                  child: Container(
                    margin: EdgeInsets.all(gHeight * 0.01),
                    width: gWidth / 1.5,
                    child: Stack(
                      children: [
                        Container(
                          width: gWidth / 1,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            image: DecorationImage(
                              image: productList[index].productImage != null &&
                                      productList[index]
                                          .productImage!
                                          .isNotEmpty
                                  ? NetworkImage(
                                      productList[index].productImage!.first)
                                  : AssetImage('assets/images/profile.png')
                                      as ImageProvider, // Use the image URL
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 20,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onPrimary,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              productList[index].name ?? '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 18.0,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onPrimary,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${productList[index].price} €/Kg', // Agrega el precio del producto
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 18.0,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                           bottom: 10,
                           left: 20,
                           child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onPrimary,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '${distance.toStringAsFixed(2)} km', // Muestra la distancia
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 14.0,  // Ajusta el tamaño según tus necesidades
                              ),
                            ),
                          ),
                        )
                        
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

    double calculateDistance(double lat1, double lon1, double? lat2, double? lon2) {
  const R = 6371.0; // Radio de la Tierra en kilómetros
  final dLat = _toRadians(lat2! - lat1);
  final dLon = _toRadians(lon2! - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2!)) * sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * asin(sqrt(a));

  return R * c;
}

double _toRadians(double degree) {
  return degree * (pi / 180);
}
}

class TopText extends StatelessWidget {
  const TopText({
    Key? key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
          margin: EdgeInsets.only(top: 10, left: 20),
          width: gWidth,
          height: gHeight / 25,
          child: SizedBox(
            child: Text("Productos en oferta",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                  color: Theme.of(context).primaryColor,
                )),
          )),
    );
  }
}
